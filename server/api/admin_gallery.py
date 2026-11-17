import os
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy import text
from sqlalchemy.orm import Session
from db.database import get_db

router = APIRouter(prefix="/api/admin", tags=["admin-gallery"])

BASE_DIR = Path(__file__).resolve().parents[1]
STATIC_DIR = BASE_DIR / "static"
UPLOADED_IMAGES_DIR = BASE_DIR / "uploaded_images"



# =========================
# Check Uploaded_images
# =========================

# 1. HTML Admin Gallery Page Route
@router.get("/gallery")
async def admin_gallery_page():

    # Serves the admin gallery HTML page w/o browser caching
    response = FileResponse(STATIC_DIR / "admin_gallery.html")
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    return response


# 2. JSON Gallery Data API Route
@router.get("/gallery-data")
def get_gallery_data(db: Session = Depends(get_db)):

    """
    Returns JSON data containing image file details from the images table
    """
    filename_map = {}

    try:
        # Fetch image paths from the normalized images table instead of reports
        records = db.execute(
            text("""
            SELECT images.image_path
            FROM images
            WHERE images.image_path IS NOT NULL""")
        ).fetchall()

        for row in records:
            if row.image_path:
                saved_name = os.path.basename(row.image_path)
                filename_map[saved_name] = saved_name
    except Exception as e:
        print(f"[Error] Failed to process gallery image records: {e}")


    allowed_extensions = ('.png', '.jpg', '.jpeg', '.webp', '.heic', '.heif')

    files = []
    for filename in os.listdir(UPLOADED_IMAGES_DIR):
        # Convert filename to lowercase
        lower_filename = filename.lower()
        
        if lower_filename.endswith(allowed_extensions):
            files.append(filename)

    
    """
    Return a structured list of image metadata
    """
    images_list = []
    for file in files:
        images_list.append({
            "saved_name": file,
            "url": f"/uploaded_images/{file}"
        })

    return {"images": images_list}


# 3. Image Deletion API Route
@router.delete("/gallery/{filename}")
def delete_image(
    filename: str,
    db: Session = Depends(get_db)
    ):

    """
    Delete an image file from the uploaded_images directory and update references
    """
    file_path = UPLOADED_IMAGES_DIR / filename

    if not file_path.is_file() or file_path.parent != UPLOADED_IMAGES_DIR:
        raise HTTPException(
            status_code=404,
            detail="File not found"
        )

    try:
        # 1. Check if the image is referenced in the images table
        target_path_pattern = f"%{filename}"

        images_with_file = db.execute(
            text("""
            SELECT images.image_id
            FROM images
            WHERE images.image_path
            LIKE :path"""),
            {"path": target_path_pattern}
        ).fetchall()

        # 2. Unlink image path from the images table if referenced
        if images_with_file:
            db.execute(
                text("""
                UPDATE images
                SET image_path = NULL
                WHERE images.image_path
                LIKE :path"""),
                {"path": target_path_pattern}
            )
            db.commit()
            db_msg = f" (Updated {len(images_with_file)} DB record(s) to NULL)"
        else:
            db_msg = " (Unlinked temp file / test image)"

        
        # Delete the image file from directory
        os.remove(file_path)
        return {
            "status": "success",
            "message": f"{filename} deleted successfully"
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete file: {str(e)}"
        )