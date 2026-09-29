import os
from pathlib import Path

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from api.process import router as process_router

from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse

from sqlalchemy import text
from sqlalchemy.orm import Session
from db.database import get_db


# ================= DO NOT MODIFY =================
# DO NOT MODIFY: Tailscale / Cloudflared funnel routing depends on this path
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# ==================================================



# =========================
# Static Files
# =========================
BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
UPLOADED_IMAGES_DIR = BASE_DIR / "uploaded_images"

# Ensure the upload directory exists
os.makedirs(UPLOADED_IMAGES_DIR, exist_ok=True)


# ================= DO NOT MODIFY =================
app.mount(
    "/uploaded_images",
    StaticFiles(
        directory = UPLOADED_IMAGES_DIR
    ),
    name="uploaded_images"
)

# Frontend static URLs
app.mount(
    "/static",
    StaticFiles(directory = STATIC_DIR),
    name="static"
)
# ==================================================



# =========================
# Router Registration
# =========================

# ================= DO NOT MODIFY =================
# DO NOT MODIFY: Tailscale / Cloudflared funnel routing depends on this path

# External API routes.
app.include_router(process_router)

# The public homepage URL
@app.get("/")
async def root():
    return FileResponse(STATIC_DIR / "index.html")
# ==================================================


@app.get("/db-test")
def db_test(db: Session = Depends(get_db)):

    result = db.execute(text("SELECT version()"))
    version = result.scalar()

    return {
        "status": "connected",
        "postgres": version
    }



# =========================
# Check Uploaded_images
# =========================

# 1. HTML Admin Gallery Page Route
@app.get("/admin/gallery")
async def admin_gallery_page():

    # Serves the admin gallery HTML page
    return FileResponse(STATIC_DIR / "admin_gallery.html")


# 2. JSON Gallery Data API Route
@app.get("/api/admin/gallery-data")
def get_gallery_data(db: Session = Depends(get_db)):

    """
    Returns JSON data containing image file details
    (saved name, original name)
    """
    filename_map = {}

    try:
        records = db.execute(
            text("SELECT image_path, original_filename FROM reports WHERE image_path IS NOT NULL")
        ).fetchall()
        
        for row in records:
            if row.image_path:
                saved_name = os.path.basename(row.image_path)
                filename_map[saved_name] = row.original_filename or "Unknown"
    except Exception as e:
        print(f"[Warning] Failed to fetch original filenames: {e}")


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
            "original_name": filename_map.get(file, "N/A"),
            "url": f"/uploaded_images/{file}"
        })

    return {"images": images_list}


# 3. Image Deletion API Route
@app.delete("/admin/gallery/{filename}")
def delete_image(
    filename: str,
    db: Session = Depends(get_db)
    ):

    """
    Delete an image file from the uploaded_images directory
    """
    file_path = UPLOADED_IMAGES_DIR / filename

    if not file_path.is_file() or file_path.parent != UPLOADED_IMAGES_DIR:
        raise HTTPException(
            status_code=404, 
            detail="File not found"
        )

    try:
        # 1. Check if the image is referenced in the database
        # (image path: /uploaded_images/filename)
        target_path_pattern = f"%{filename}"

        reports_with_image = db.execute(
            text("SELECT id FROM reports WHERE image_path LIKE :path"),
            {"path": target_path_pattern}
        ).fetchall()

        # 2. Unlink image from reports if referenced
        # (set image_path to NULL)
        if reports_with_image:
            db.execute(
                text("UPDATE reports SET image_path = NULL WHERE image_path LIKE :path"),
                {"path": target_path_pattern}
            )
            db.commit()
            db_msg = f" (Updated {len(reports_with_image)} DB record(s) to NULL)"
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
