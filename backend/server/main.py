from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.server.api.process import router as process_router

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ===== ===== Router ===== =====
app.include_router(process_router)
# app.include_router(auth_router)


@app.get("/")
async def root():
    return {"message": "Lost & Found API Server Running"}