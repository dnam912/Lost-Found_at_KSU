import json
import math
from datetime import date
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import text
from sqlalchemy.orm import Session

from api.auth import AuthenticatedUser, get_current_user
from api.image_caching import process_and_cache_image

from db.database import get_db
from db.queries import get_reports_table_query

router = APIRouter(prefix="/api")

# ==================================================
# Mobile Matching Configuration
# ==================================================
SIMILARITY_THRESHOLD = 0.75
MAX_MATCHES = 5
MAX_CANDIDATES = 1000
# ==================================================


class MatchQuery(BaseModel):
    embedding: list[float] = Field(min_length=1, max_length=4096)

    @field_validator("embedding")
    @classmethod
    def validate_embedding(cls, values: list[float]) -> list[float]:
        if not all(math.isfinite(value) for value in values):
            raise ValueError("Embedding values must be finite numbers")
        if not any(value != 0 for value in values):
            raise ValueError("Embedding must not be all zeroes")
        return values


def cosine_similarity(first: list[float], second: list[float]) -> float | None:
    if len(first) != len(second) or not first:
        return None

    dot = sum(a * b for a, b in zip(first, second))
    first_norm = math.sqrt(sum(value * value for value in first))
    second_norm = math.sqrt(sum(value * value for value in second))
    if first_norm == 0 or second_norm == 0:
        return None

    return max(-1.0, min(1.0, dot / (first_norm * second_norm)))


@router.post("/found")
async def create_found_report(
    title: str = Form(..., min_length=1, max_length=200),
    location: str = Form(..., min_length=1, max_length=500),
    description: str = Form("", max_length=5000),
    embedding: str = Form(...),
    image: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    try:
        parsed_embedding = MatchQuery.model_validate({"embedding": json.loads(embedding)}).embedding
    except (json.JSONDecodeError, ValueError) as exc:
        raise HTTPException(status_code=400, detail="Invalid MobileCLIP embedding") from exc

    image_path, image_hash, disk_path = await process_and_cache_image(image, db)
    try:
        # 1. Insert item record and retrieve its UUID primary key.
        item_id = db.execute(
            text("""
                INSERT INTO items (category, description_raw)
                VALUES (:category, :description)
                RETURNING item_id
            """),
            {
                "category": title.strip(),
                "description": description.strip() or None,
            },
        ).scalar_one()

        # 2. Insert report record referencing item_id and user_id.
        report = db.execute(
            text("""
                INSERT INTO reports (
                    status,
                    location,
                    estimated_date,
                    user_id,
                    item_id
                )
                VALUES (
                    'Found',
                    :location,
                    :estimated_date,
                    :user_id,
                    :item_id
                )
                RETURNING id, status, location, created_at
            """),
            {
                "location": location.strip(),
                "estimated_date": date.today().isoformat(),
                "user_id": user.id,
                "item_id": item_id,
            },
        ).mappings().one()

        # 3. Insert image record referencing both report_id (reports.id) and item_id.
        db.execute(
            text("""
                INSERT INTO images (
                    report_id,
                    item_id,
                    image_path,
                    image_hash,
                    mobileclip_embedding
                )
                VALUES (
                    :report_id,
                    :item_id,
                    :image_path,
                    :image_hash,
                    CAST(:embedding AS jsonb)
                )
            """),
            {
                "report_id": report["id"],
                "item_id": item_id,
                "image_path": image_path,
                "image_hash": image_hash,
                "embedding": json.dumps(parsed_embedding),
            },
        )

        db.commit()
    except Exception:
        db.rollback()
        if disk_path.exists():
            disk_path.unlink()
        raise

    return {
        "id": report["id"],
        "status": report["status"],
        "location": report["location"],
        "category": title.strip(),
        "description_raw": description.strip() or None,
        "image_path": image_path,
        "created_at": report["created_at"],
    }


@router.post("/match")
def match_found_reports(
    query: MatchQuery,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    
    # Use centralized standard query with explicit table names and 'Found' status filter
    match_query_sql = f"""
        {get_reports_table_query()}
        WHERE reports.status = 'Found'
          AND images.image_path IS NOT NULL
          AND images.mobileclip_embedding IS NOT NULL
        ORDER BY reports.created_at DESC
        LIMIT :limit
    """
    
    rows = db.execute(
        text(match_query_sql),
        {"limit": MAX_CANDIDATES},
    ).mappings().all()


    matches: list[dict[str, Any]] = []
    for row in rows:
        stored_embedding = row["mobileclip_embedding"]
        if isinstance(stored_embedding, str):
            try:
                stored_embedding = json.loads(stored_embedding)
            except json.JSONDecodeError:
                continue
        if not isinstance(stored_embedding, list):
            continue

        try:
            candidate = [float(value) for value in stored_embedding]
        except (TypeError, ValueError):
            continue
        if not all(math.isfinite(value) for value in candidate):
            continue

        similarity = cosine_similarity(query.embedding, candidate)
        if similarity is None or similarity < SIMILARITY_THRESHOLD:
            continue

        matches.append({
            "id": row["id"],
            "status": row["status"],
            "location": row["location"],
            "category": row["category"],
            "description_raw": row["description_raw"],
            "image_path": row["image_path"],
            "created_at": row["created_at"],
            "similarity": similarity,
        })

    matches.sort(key=lambda match: match["similarity"], reverse=True)
    return {
        "threshold": SIMILARITY_THRESHOLD,
        "matches": matches[:MAX_MATCHES],
    }