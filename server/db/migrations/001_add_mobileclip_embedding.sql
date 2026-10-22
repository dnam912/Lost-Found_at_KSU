-- Apply to the PostgreSQL database used by the FastAPI server.
-- Embeddings are kept server-side; the API returns only threshold-qualified matches.
ALTER TABLE reports
ADD COLUMN IF NOT EXISTS mobileclip_embedding JSONB;
