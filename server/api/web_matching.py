"""Read-only, rules-based matching against reports with the opposite status."""

import calendar
import re
from datetime import date, datetime

from fastapi import APIRouter, Depends, Form, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from db.database import get_db

router = APIRouter(prefix="/api/web")

MATCH_THRESHOLD = 45
MAX_CANDIDATES = 1000
MAX_RESULTS = 12

STOP_WORDS = {
    "the", "a", "an", "and", "or", "it", "is", "was", "my", "i",
    "in", "on", "at", "to", "of", "with", "near", "some", "this",
    "that", "for", "from", "item", "lost", "found",
}

REPORT_QUERY = """
    SELECT id, status, location, estimated_date, category, color, material,
           description_raw, image_path
    FROM public.reports
    WHERE lower(status) = lower(:opposite)
    ORDER BY created_at DESC
    LIMIT :limit
"""


def tokens(value):
    words = re.findall(r"[a-z0-9]+", str(value or "").lower())
    return {word for word in words if len(word) > 1 and word not in STOP_WORDS}


def overlap(query_value, report_value):
    query_words = tokens(query_value)
    report_words = tokens(report_value)
    return len(query_words & report_words) / len(query_words) if query_words and report_words else 0.0


def score_match(query, report):
    category = max(
        overlap(query["category"], report["category"]),
        0.6 * overlap(query["category"], report["description_raw"]),
    )
    description = overlap(query["description_raw"], report["description_raw"])

    # Location, color, and material cannot independently establish a match.
    if not (category or description):
        return 0

    return round(
        45 * category
        + 25 * description
        + 10 * overlap(query["color"], report["color"])
        + 10 * overlap(query["material"], report["material"])
        + 10 * overlap(query["location"], report["location"])
    )


def date_bounds(value):
    """Expand YYYY, YYYY-MM, or YYYY-MM-DD into an inclusive date interval."""
    value = (value or "").strip()
    match = re.fullmatch(r"(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?", value)
    if not match:
        raise HTTPException(400, "Date must be YYYY, YYYY-MM, or YYYY-MM-DD")

    year = int(match.group(1))
    month = int(match.group(2)) if match.group(2) else None
    day = int(match.group(3)) if match.group(3) else None

    try:
        if day is not None:
            single_day = date(year, month, day)
            return single_day, single_day
        if month is not None:
            return date(year, month, 1), date(year, month, calendar.monthrange(year, month)[1])
        return date(year, 1, 1), date(year, 12, 31)
    except ValueError as exc:
        raise HTTPException(400, "Invalid date") from exc


def search_date_range(date_value, estimated_start, estimated_end):
    """Use explicit start/end limits if provided; otherwise use the date field."""
    if estimated_start or estimated_end:
        start = date_bounds(estimated_start)[0] if estimated_start else None
        end = date_bounds(estimated_end)[1] if estimated_end else None
    elif date_value:
        start, end = date_bounds(date_value)
    else:
        return None, None

    if start and end and start > end:
        raise HTTPException(400, "Start date must not be after end date")
    return start, end


def matches_date(report_date, start, end):
    if start is None and end is None:
        return True
    if report_date is None:
        return False

    if isinstance(report_date, datetime):
        report_date = report_date.date()
    elif isinstance(report_date, str):
        try:
            report_date = date.fromisoformat(report_date)
        except ValueError:
            return False

    return (start is None or report_date >= start) and (end is None or report_date <= end)


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
):
    status = status.strip().capitalize()
    if status not in {"Lost", "Found"}:
        raise HTTPException(400, "Status must be Lost or Found")
    if not category.strip() or not location.strip():
        raise HTTPException(400, "Category and location required")

    start, end = search_date_range(date_value, estimated_start, estimated_end)
    opposite = "Found" if status == "Lost" else "Lost"
    query = {
        "location": location,
        "category": category,
        "color": color,
        "material": material,
        "description_raw": text_description,
    }

    candidates = db.execute(
        text(REPORT_QUERY), {"opposite": opposite, "limit": MAX_CANDIDATES}
    ).mappings().all()

    matches = []
    for report in candidates:
        if not matches_date(report["estimated_date"], start, end):
            continue
        score = score_match(query, report)
        if score < MATCH_THRESHOLD:
            continue
        match = dict(report)
        match["score"] = score
        matches.append(match)

    matches.sort(key=lambda item: (-item["score"], -item["id"]))
    return {
        "matches": matches[:MAX_RESULTS],
        "count": len(matches),
        "threshold": MATCH_THRESHOLD,
        "matching_status": opposite,
    }
