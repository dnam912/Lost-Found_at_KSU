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


# Login & Security API Routes
from api.auth import router as auth_router
try:
    from security.bot_blocker import bot_blocker_middleware
except ImportError:
    bot_blocker_middleware = None

try:
    from security.log_viewer import router as log_viewer_router
except ImportError:
    log_viewer_router = None


# External API Routes
from api.mobile_matching import router as mobile_matching_router
from api.web_matching import router as web_matching_router
from api.reports_view import router as view_reports_router
from api.admin_gallery import router as admin_gallery_router


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

# External API routes
app.include_router(process_router)

# Login
app.include_router(auth_router)

# Mobile API routes for MobileClip
app.include_router(mobile_matching_router)

# Web API routes for MobileClip
app.include_router(web_matching_router)

# Reports view routes
app.include_router(view_reports_router)

# Admin Gallery routes
app.include_router(admin_gallery_router)


# FOR SECURITY
# API routes for bot_blokcer, when the optional security module is installed.
if bot_blocker_middleware is not None:
    app.middleware("http")(bot_blocker_middleware)
    print("[SECURITY] Bot blocker middleware enabled.")
else:
    print("[SECURITY] Bot blocker middleware NOT loaded.")

# API routes for log_viewer, when the optional security module is installed.
if log_viewer_router is not None:
    app.include_router(log_viewer_router)



# The public homepage URL
@app.get("/")
async def root():
    return FileResponse(STATIC_DIR / "index.html")

@app.get("/db-test")
def db_test(db: Session = Depends(get_db)):

    result = db.execute(text("SELECT version()"))
    version = result.scalar()

    return {
        "status": "connected",
        "postgres": version
    }

