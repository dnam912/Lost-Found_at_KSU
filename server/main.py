from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from api.process import router as process_router

from fastapi import Depends
from sqlalchemy import text
from sqlalchemy.orm import Session
from db.database import get_db

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ===== Static Files =====

BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"

app.mount(
    "/uploaded_images",
    StaticFiles(
        directory=BASE_DIR / "uploaded_images"
    ),
    name="uploaded_images"
)

app.mount(
    "/static",
    StaticFiles(directory=STATIC_DIR),
    name="static"
)

# ===== ===== Router ===== =====
app.include_router(process_router)
# app.include_router(auth_router)


@app.get("/")
async def root():
    return FileResponse(STATIC_DIR / "index.html")




@app.get("/db-test")
def db_test(db: Session = Depends(get_db)):

    result = db.execute(
        text("SELECT version()")
    )

    version = result.scalar()

    return {
        "status": "connected",
        "postgres": version
    }




