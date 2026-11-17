# Authentication deployment checklist

The app now has FastAPI account endpoints and stores opaque bearer sessions in the iOS Keychain. Passwords are hashed server-side with Argon2id. The mobile matching routes and `/api/process` require a bearer token. New reports record their owner in `reports.owner_user_id`.

## Deploy

1. Back up the website's PostgreSQL database.
2. Deploy these repository changes while preserving existing website routes and the existing `DATABASE_URL`:
   - `server/api/auth.py`
   - `server/api/mobile_matching.py`
   - `server/api/process.py`
   - `server/main.py`
   - `server/requirements.txt`
3. Install updated dependencies in the server's environment:

   ```bash
   pip install -r requirements.txt
   ```

4. Apply migrations against the same database used by FastAPI, in order if not already applied:
   - `db/migrations/001_add_mobileclip_embedding.sql`
   - `db/migrations/002_add_app_auth.sql`

   Migration 002 adds `app_users`, `app_sessions`, and nullable `reports.owner_user_id`; it leaves existing reports intact. Do not apply the Supabase-only `lostfoundschemadb.sql` to this standalone FastAPI database.
5. Restart FastAPI and verify `/openapi.json` contains `/api/auth/signup`, `/api/auth/login`, `/api/auth/me`, `/api/auth/logout`, `/api/found`, and `/api/match`.

## Smoke tests

Unauthenticated matching and report submission must return HTTP 401:

```bash
curl -i -X POST https://lost-and-found-ksu.taildfefb3.ts.net/api/match \
  -H 'Content-Type: application/json' \
  -d '{"embedding":[1.0]}'
```

Create a temporary `@kent.edu` test account with a password of at least 12 characters using `/api/auth/signup`, then use its returned `access_token` as `Authorization: Bearer <token>` for `/api/auth/me`, `/api/match`, and `/api/found`. `/api/auth/logout` should revoke the token; subsequent protected requests with it must return 401. Remove any test report/image afterward.

The signup endpoint currently checks the email domain but does not verify control of that mailbox. Add email verification before treating accounts as verified KSU identities. Add rate limiting to signup/login before broader deployment.

## Website coordination and privacy blockers

`/api/process` now requires a bearer token and writes `owner_user_id`; the current static website must be updated to sign in/sign up and attach the bearer token before its report-submission form will work. Do not restore unauthenticated writes as a workaround.

This change does **not** make uploaded photos private: `main.py` still mounts `/uploaded_images` publicly, and the admin gallery routes are not authenticated. Restrict those image/gallery routes and protect any public report-listing endpoints before using real item data. The iOS match threshold protects only the `/api/match` response and cannot protect a photo URL that is publicly accessible.
