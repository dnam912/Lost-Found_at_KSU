import hashlib
from pathlib import Path
from uuid import uuid4
from fastapi import UploadFile, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

# =========================
# Set an Upload Directory & Storage Setup
# =========================
ROOT_DIR = Path(__file__).resolve().parents[1]
UPLOAD_DIR = ROOT_DIR / "uploaded_images"   # DO NOT MODIFY
UPLOAD_DIR.mkdir(exist_ok=True)             # DO NOT MODIFY

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"}



# =========================
# Functions
# =========================
def calculate_image_hash(contents: bytes) -> str:
    """
    Calculate SHA-256 hash from file bytes
    """
    return hashlib.sha256(contents).hexdigest()


async def process_and_cache_image(
    image: UploadFile,
    db: Session
) -> tuple[str, str]:
    """
    Validates, hashes, checks DB duplicates, and saves image to disk
    Returns: (saved_image_path, file_hash)
    """
    if not image.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image file."
        )


    # 1. Check image extensions
    suffix = Path(image.filename).suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file format. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"
        )


    # 2. Read File Bytes and Calculate SHA-256 Hash
    contents = await image.read()
    file_hash = calculate_image_hash(contents)


    # 3. Check duplicated image_hash in DB
    existing_record = db.execute(
        text("SELECT id, image_path FROM reports WHERE image_hash = :hash"),
        {"hash": file_hash}
    ).fetchone()


    # Return a 409 Conflict when the image already exists.
    if existing_record:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DUPLICATE_IMAGE",
                "message": "This image has already been uploaded",
                "existing_report_id": existing_record.id,
                "existing_image_path": existing_record.image_path
            }
        )


    # 4. Save a new image to disk.
    new_filename = f"{uuid4()}{suffix}"
    disk_path = UPLOAD_DIR / new_filename

    with open(disk_path, "wb") as f:
        f.write(contents)

    # ================= DO NOT MODIFY =================
    # DO NOT MODIFY THIS without matching main.py's image URL mount
    saved_url = f"/uploaded_images/{new_filename}"
    return saved_url, file_hash, disk_path
    # ==================================================
