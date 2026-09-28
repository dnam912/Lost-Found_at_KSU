from datetime import datetime, time
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session
from db.database import get_db


router = APIRouter(prefix="/api")


ROOT_DIR = Path(__file__).resolve().parents[1]
UPLOAD_DIR = ROOT_DIR / "uploaded_images"

UPLOAD_DIR.mkdir(exist_ok=True)


@router.post("/process")
async def process_form(
    status: str = Form(...),
    location: str = Form(...),

    date: str = Form(""),
    estimated_start: str = Form(""),
    estimated_end: str = Form(""),

    category: str = Form(""),
    color: str = Form(""),
    material: str = Form(""),

    text_description: str = Form("", alias="text"),

    image: UploadFile | None = File(None),

    db: Session = Depends(get_db),
):
    # =========================
    # Date conversion
    # MM/DD/YYYY -> PostgreSQL DATE
    # =========================

    report_date = None

    if date:
        try:
            report_date = datetime.strptime(
                date,
                "%m/%d/%Y"
            ).date()
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail="Date must be MM/DD/YYYY"
            )


    # =========================
    # Time conversion
    # =========================

    start_time = None
    end_time = None

    if estimated_start:
        start_time = time.fromisoformat(estimated_start)

    if estimated_end:
        end_time = time.fromisoformat(estimated_end)


    # =========================
    # Save image
    # =========================

    image_path = None

    if image and image.filename:

        suffix = Path(image.filename).suffix.lower()

        if suffix not in [".jpg", ".jpeg", ".png"]:
            raise HTTPException(
                status_code=400,
                detail="Only JPG and PNG images are allowed"
            )

        new_filename = f"{uuid4()}{suffix}"

        disk_path = UPLOAD_DIR / new_filename

        contents = await image.read()

        with open(disk_path, "wb") as f:
            f.write(contents)

        # URL stored in PostgreSQL
        image_path = f"/uploaded_images/{new_filename}"


    # =========================
    # Insert PostgreSQL
    # =========================

    query = text("""
        INSERT INTO reports (
            status,
            location,
            estimated_date,
            estimated_start,
            estimated_end,
            category,
            color,
            material,
            description_raw,
            image_path
        )
        VALUES (
            :status,
            :location,
            :estimated_date,
            :estimated_start,
            :estimated_end,
            :category,
            :color,
            :material,
            :description_raw,
            :image_path
        )
        RETURNING
            id,
            status,
            location,
            estimated_date,
            estimated_start,
            estimated_end,
            category,
            color,
            material,
            description_raw,
            image_path,
            created_at
    """)

    try:
        result = db.execute(
            query,
            {
                "status": status,
                "location": location,

                "estimated_date": report_date,
                "estimated_start": start_time,
                "estimated_end": end_time,

                "category": category or None,
                "color": color or None,
                "material": material or None,

                "description_raw": text_description or None,

                "image_path": image_path,
            }
        )

        saved = result.mappings().one()

        db.commit()

    except Exception:
        db.rollback()
        raise


    return {
        "status": "success",
        "parsed_data": dict(saved)
    }


# =============================
# Show all reports
# =============================

@router.get("/reports")
def get_reports(
    db: Session = Depends(get_db)
):

    result = db.execute(
        text("""
            SELECT
                id,
                status,
                location,
                estimated_date,
                estimated_start,
                estimated_end,
                category,
                color,
                material,
                description_raw,
                image_path,
                created_at
            FROM reports
            ORDER BY created_at DESC
        """)
    )

    return list(
        result.mappings().all()
    )



@router.get("/reports")
def get_reports(db: Session = Depends(get_db)):

    result = db.execute(
        text("""
            SELECT
                id,
                status,
                location,
                estimated_date,
                estimated_start,
                estimated_end,
                category,
                color,
                material,
                description_raw,
                image_path,
                created_at
            FROM reports
            ORDER BY created_at DESC
        """)
    )

    rows = result.mappings().all()

    return [dict(row) for row in rows]