from datetime import date, datetime, time
from typing import Any
from pydantic import BaseModel


# =========================
# Response models for report data returned to API clients
# =========================
class ReportData(BaseModel):
    """
    Fields returned for a saved report
    """

    id: int
    status: str
    location: str
    estimated_date: date | None = None
    estimated_start: time | None = None
    estimated_end: time | None = None
    category: str | None = None
    color: str | None = None
    material: str | None = None
    description_raw: str | None = None
    image_path: str | None = None
    created_at: datetime | None = None


class APIResponse(BaseModel):
    status: str
    code: str
    message: str
    data: Any | None = None
