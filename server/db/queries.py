"""Centralized SQL queries for reports, items, and images tables."""

def get_reports_table_query() -> str:
    """
    Standard SQL query joining reports, items, and images tables.
    Uses standard JOINs compatible with all PostgreSQL versions.
    """
    return """
        SELECT
            reports.id,
            reports.status,
            reports.location,
            reports.estimated_date,
            reports.estimated_start,
            reports.estimated_end,
            reports.created_at,
            items.category,
            items.primary_color AS color,
            items.material,
            items.description_raw,
            images.image_path
        FROM reports
        JOIN items ON reports.item_id = items.item_id
        LEFT JOIN images ON images.report_id = reports.id
    """