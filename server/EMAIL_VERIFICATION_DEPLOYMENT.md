# Email verification deployment

Signup now creates a pending account and sends a single-use verification link. It does not create a session or return an access token until the user verifies their mailbox and signs in. Passwords continue to be hashed server-side with Argon2id.

## Deploy

1. Back up the PostgreSQL database used by FastAPI.
2. Merge the changes to `api/auth.py`, `api/process.py`, and `main.py` into the deployed server. Preserve the existing website routes and optional security integrations. Resolve merge conflicts; do not deploy conflict markers.
3. Install existing requirements in the server's environment:

   ```bash
   pip install -r requirements.txt
   ```

4. Configure the mail provider in the server environment (never commit these secrets):

   ```text
   SMTP_HOST=<provider SMTP host>
   SMTP_PORT=587
   SMTP_USERNAME=<provider SMTP username>
   SMTP_PASSWORD=<provider SMTP password or API credential>
   SMTP_FROM=<verified sender address>
   EMAIL_VERIFICATION_URL=https://lost-and-found-ksu.taildfefb3.ts.net/api/auth/verify-email
   ```

   Verify the sender/domain with the provider. The API requires an HTTPS verification URL and sends using SMTP STARTTLS.

5. Apply migrations against the same database used by FastAPI, in order if not already applied:

   ```bash
   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/migrations/001_add_mobileclip_embedding.sql
   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/migrations/002_add_app_auth.sql
   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/migrations/003_add_email_verification.sql
   ```

   Migration 003 adds `app_users.email_verified_at` and hashed, expiring, single-use verification tokens. Existing accounts remain unverified until mailbox ownership is confirmed. Do not apply the Supabase-only `lostfoundschemadb.sql` to this standalone FastAPI database.

6. Restart FastAPI and verify `/openapi.json` lists `/api/auth/signup`, `/api/auth/resend-verification`, `/api/auth/verify-email`, `/api/auth/login`, `/api/auth/me`, `/api/auth/logout`, `/api/found`, and `/api/match`.

## Smoke test

1. `POST /api/auth/signup` with a disposable `@kent.edu` address and a 12+ character password should return HTTP 202 and a generic message, not an access token.
2. Confirm email delivery, open its link, and press **Verify email**. The link is single-use and expires after 30 minutes.
3. Before verification, login must return HTTP 403. After verification, login returns a session token; use it as `Authorization: Bearer <token>` for protected endpoints.
4. `/api/auth/resend-verification` should return a generic response and enforce a one-minute resend cooldown. Logout revokes the token; later protected requests with it must return HTTP 401.

Use a disposable test account and clean up any test report/image. Add broader rate limiting to signup/login and verification endpoints at the API gateway or middleware before public production use; the resend cooldown is not general abuse protection.

`/api/process` now requires authentication too, so the existing website's report form must attach a bearer token. This change does not make uploaded images or report-listing endpoints private; review those separately before using real item data.
