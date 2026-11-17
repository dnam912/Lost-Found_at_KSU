from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session
from db.database import get_db
from db.queries import get_reports_table_query

router = APIRouter(prefix="/api", tags=["reports-view"])

@router.get("/reports")
def get_all_reports(db: Session = Depends(get_db)):
    """
    Returns a list of all reports joined with items and images for the developer debug panel.
    """
    try:
        query_str = f"""
            {get_reports_table_query()}
            ORDER BY reports.created_at DESC
            LIMIT 50
        """
        rows = db.execute(text(query_str)).mappings().all()


        reports_list = []
        for row in rows:
            reports_list.append({
                "id": row["id"],
                "status": row["status"],
                "location": row["location"],
                "estimated_date": row["estimated_date"],
                "estimated_start": str(row["estimated_start"]) if row["estimated_start"] else None,
                "estimated_end": str(row["estimated_end"]) if row["estimated_end"] else None,
                "category": row["category"],
                "color": row["color"],
                "material": row["material"],
                "description_raw": row["description_raw"],
                "image_path": row["image_path"],
                "created_at": row["created_at"].isoformat() if row["created_at"] else None
            })

        return reports_list
    except Exception as e:
        print(f"[Error] Failed to fetch reports for developer panel: {e}")
        raise HTTPException(status_code=500, detail="Failed to load reports.")