from datetime import date, datetime, time
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import text
from sqlalchemy.orm import Session

from db.database import get_db
from api.image_caching import process_and_cache_image
# from vector.embedding_utils import generate_mobileclip_embedding



# ================= DO NOT MODIFY =================
# DO NOT MODIFY: Tailscale / Cloudflared funnel routing depends on this path
router = APIRouter(prefix="/api")
# ==================================================


# =========================
# Set an Upload Directory & Storage Setup
# =========================
ROOT_DIR = Path(__file__).resolve().parents[1]
UPLOAD_DIR = ROOT_DIR / "uploaded_images"       # DO NOT MODIFY
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)   # DO NOT MODIFY

ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"}



# =========================
# Functions
# (Parsers & Image Handlers)
# =========================
def parse_date(date_str: str) -> date | None:
    if not date_str:
        return None
    
    try:
        return datetime.strptime(date_str, "%m/%d/%Y").date()
    except ValueError as exc:
        raise HTTPException(status_code=400, 
                            detail="Date must be MM/DD/YYYY"
                            ) from exc


def parse_time(time_str: str) -> time | None:
    if not time_str:
        return None
    
    try:
        return time.fromisoformat(time_str)
    except ValueError as exc:
        raise HTTPException(
            status_code=400, 
            detail="Time must be in ISO format"
        ) from exc



# =========================
# Main Endpoints
# =========================
@router.post("/process")
async def process_form(
    status: str = Form(...),
    location: str = Form(...),
    date: str = Form(...),
    estimated_start: str = Form(""),
    estimated_end: str = Form(""),
    category: str = Form(...),
    color: str = Form(""),
    material: str = Form(""),
    text_description: str = Form("", alias="text"),
    image: UploadFile | None = File(None),
    db: Session = Depends(get_db),
):
    
    # 1. Parse & Validate Inputs
    report_date = parse_date(date)
    start_time = parse_time(estimated_start)
    end_time = parse_time(estimated_end)


    # 2. Process Image Upload & Embedding Initialization
    image_path = None
    image_hash = None
    disk_path = None
    embedding_json = None


    # 3. Caching Check & Image Processing
    if image and image.filename:
        image_path, image_hash, disk_path = await process_and_cache_image(image, db)

        # [Will add this later] Create MobileCLIP vector from Python backend
        # try:
        #     embedding_vector = extract_web_image_embedding(disk_path)
        #     embedding_json = json.dumps(embedding_vector)
        # except Exception as exc:
        #     print(f"[WARNING] Failed to extract embedding: {exc}")
        #     embedding_json = None


    # 4. Database Insertion
    query = text("""
        INSERT INTO reports (
            status, 
            location, 
            estimated_date, 
            estimated_start, estimated_end,
            category, 
            color, 
            material, 
            description_raw, 
            image_path,
            image_hash,
            mobileclip_embedding
        ) 
        VALUES (
            :status, 
            :location, 
            :estimated_date, 
            :estimated_start, :estimated_end,
            :category, 
            :color, 
            :material, 
            :description_raw, 
            :image_path,
            :image_hash,
            CAST(:mobileclip_embedding AS jsonb)
        )
        RETURNING
            id, 
            status, 
            location, 
            estimated_date, 
            estimated_start, estimated_end,
            category, 
            color, 
            material, 
            description_raw, 
            image_path,
            image_hash,
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
                "image_hash": image_hash,
                "mobileclip_embedding": embedding_json
            }
        )
        saved = result.mappings().one()
        db.commit()

    except Exception:
        db.rollback()
        # Clean up stored image on DB failure
        if disk_path and disk_path.exists():
            disk_path.unlink()
        raise

    return {
        "status": "success",
        "parsed_data": dict(saved)
    }



# =========================
# Show all reports
# =========================
@router.get("/reports")
def get_reports(db: Session = Depends(get_db)):
    query = text("""
        SELECT
            id, 
            status, 
            location, 
            estimated_date, 
            estimated_start, estimated_end,
            category, 
            color, 
            material, 
            description_raw, 
            image_path, 
            created_at
        FROM reports
        ORDER BY created_at DESC
    """)

    rows = db.execute(query).mappings().all()
    return [dict(row) for row in rows]