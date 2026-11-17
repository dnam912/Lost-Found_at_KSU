"""Read-only, rules-based matching against reports with the opposite status."""

import calendar
import re
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any

from fastapi import APIRouter, Depends, Form, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from db.database import get_db
from db.queries import get_reports_table_query

router = APIRouter(prefix="/api/web")


# ==================================================
# 1. Matching & Weight Configuration
# ==================================================
@dataclass(frozen=True)
class MatchWeights:
    category: float = 45.0
    category_in_description_ratio: float = 0.6  # Weight multiplier when category matches description text
    description: float = 25.0
    color: float = 10.0
    material: float = 10.0
    location: float = 10.0


WEIGHTS = MatchWeights()
MATCH_THRESHOLD = 45       # Minimum score required to return a match (out of 100)
MAX_CANDIDATES = 1000      # Maximum candidate reports fetched from the database
MAX_RESULTS = 12           # Maximum matched reports returned in the API response

STOP_WORDS = {
    "the", "a", "an", "and", "or", "it", "is", "was", "my", "i",
    "in", "on", "at", "to", "of", "with", "near", "some", "this",
    "that", "for", "from", "item", "lost", "found",
}

REPORT_QUERY = f"""
    {get_reports_table_query()}
    WHERE reports.status = :opposite
    ORDER BY reports.created_at DESC
    LIMIT :limit
"""


# ==================================================
# 2. Text Preprocessing & Scoring Utilities
# ==================================================
def tokenize(value: Any) -> set[str]:
    """Extract lowercase alphanumeric words, filtering out stop words and short tokens."""
    words = re.findall(r"[a-z0-9]+", str(value or "").lower())
    return {word for word in words if len(word) > 1 and word not in STOP_WORDS}


def calculate_overlap(query_value: Any, report_value: Any) -> float:
    """Calculate token overlap ratio between query and report values."""
    query_tokens = tokenize(query_value)
    report_tokens = tokenize(report_value)
    if not query_tokens or not report_tokens:
        return 0.0
    return len(query_tokens & report_tokens) / len(query_tokens)


def calculate_match_score(query: dict[str, Any], report: dict[str, Any]) -> int:
    """Compute weighted score (0-100) based on category, description, color, material, and location."""
    category_score = max(
        calculate_overlap(query["category"], report["category"]),
        WEIGHTS.category_in_description_ratio * calculate_overlap(query["category"], report["description_raw"]),
    )
    description_score = calculate_overlap(query["description_raw"], report["description_raw"])

    # Location, color, and material cannot independently establish a match without core attributes.
    if not (category_score or description_score):
        return 0

    total_score = (
        WEIGHTS.category * category_score
        + WEIGHTS.description * description_score
        + WEIGHTS.color * calculate_overlap(query["color"], report["color"])
        + WEIGHTS.material * calculate_overlap(query["material"], report["material"])
        + WEIGHTS.location * calculate_overlap(query["location"], report["location"])
    )
    return round(total_score)


# ==================================================
# 3. Date Parsing & Range Filtering Utilities
# ==================================================
def parse_date_bounds(value: str) -> tuple[date, date]:
    """Expand YYYY, YYYY-MM, or YYYY-MM-DD string into an inclusive date interval."""
    cleaned = (value or "").strip()
    match = re.fullmatch(r"(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?", cleaned)
    if not match:
        raise HTTPException(status_code=400, detail="Date must be YYYY, YYYY-MM, or YYYY-MM-DD")

    year = int(match.group(1))
    month = int(match.group(2)) if match.group(2) else None
    day = int(match.group(3)) if match.group(3) else None

    try:
        if day is not None:
            single_day = date(year, month, day)
            return single_day, single_day
        if month is not None:
            last_day = calendar.monthrange(year, month)[1]
            return date(year, month, 1), date(year, month, last_day)
        return date(year, 1, 1), date(year, 12, 31)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid date") from exc


def resolve_date_range(
    date_value: str, estimated_start: str, estimated_end: str
) -> tuple[date | None, date | None]:
    """Determine start and end bounds from explicit range fields or fallback to date field."""
    if estimated_start or estimated_end:
        start = parse_date_bounds(estimated_start)[0] if estimated_start else None
        end = parse_date_bounds(estimated_end)[1] if estimated_end else None
    elif date_value:
        start, end = parse_date_bounds(date_value)
    else:
        return None, None

    if start and end and start > end:
        raise HTTPException(status_code=400, detail="Start date must not be after end date")
    return start, end


def is_within_date_range(report_date: Any, start: date | None, end: date | None) -> bool:
    """Check if the report date falls within the search date boundaries."""
    if start is None and end is None:
        return True
    if report_date is None:
        return False

    if isinstance(report_date, datetime):
        parsed_date = report_date.date()
    elif isinstance(report_date, date):
        parsed_date = report_date
    elif isinstance(report_date, str):
        try:
            parsed_date = date.fromisoformat(report_date[:10])
        except ValueError:
            return False
    else:
        return False

    return (start is None or parsed_date >= start) and (end is None or parsed_date <= end)


# ==================================================
# 4. API Endpoints
# ==================================================
@router.post("/match")
def match_reports(
    status: str = Form(...),
    location: str = Form(...),
    category: str = Form(...),
    color: str = Form(""),
    material: str = Form(""),
    text_description: str = Form("", alias="text"),
    date_value: str = Form("", alias="date"),
    estimated_start: str = Form(""),
    estimated_end: str = Form(""),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    # 1. Validate request parameters
    normalized_status = status.strip().capitalize()
    if normalized_status not in {"Lost", "Found"}:
        raise HTTPException(status_code=400, detail="Status must be Lost or Found")
    if not category.strip() or not location.strip():
        raise HTTPException(status_code=400, detail="Category and location required")

    # 2. Resolve parameters and determine opposite search status
    start, end = resolve_date_range(date_value, estimated_start, estimated_end)
    opposite_status = "Found" if normalized_status == "Lost" else "Lost"

    query_payload = {
        "location": location,
        "category": category,
        "color": color,
        "material": material,
        "description_raw": text_description,
    }

    # 3. Fetch candidate reports using centralized queries
    candidates = db.execute(
        text(REPORT_QUERY), {"opposite": opposite_status, "limit": MAX_CANDIDATES}
    ).mappings().all()

    # 4. Filter and score candidates
    matched_reports: list[dict[str, Any]] = []
    for report in candidates:
        if not is_within_date_range(report["estimated_date"], start, end):
            continue

        score = calculate_match_score(query_payload, report)
        if score < MATCH_THRESHOLD:
            continue

        item = dict(report)
        item["score"] = score
        matched_reports.append(item)

    # 5. Sort by score (descending) and ID (descending), then return results
    matched_reports.sort(key=lambda item: (-item["score"], -item["id"]))

    return {
        "matches": matched_reports[:MAX_RESULTS],
        "count": len(matched_reports),
        "threshold": MATCH_THRESHOLD,
        "matching_status": opposite_status,
    }