import hashlib
import html
import os
import re
import secrets
import smtplib
import ssl
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from typing import Any
from urllib.parse import urlencode
from uuid import UUID

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError
from fastapi import APIRouter, Depends, Form, HTTPException, status
from fastapi.responses import HTMLResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from db.database import get_db

router = APIRouter(prefix="/api/auth", tags=["authentication"])
bearer_scheme = HTTPBearer(auto_error=False)
password_hasher = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=2)
SESSION_LIFETIME = timedelta(days=30)
VERIFICATION_LIFETIME = timedelta(minutes=30)
VERIFICATION_RESEND_COOLDOWN = timedelta(minutes=1)
EMAIL_PATTERN = re.compile(r"^[^\s@]+@kent\.edu$", re.IGNORECASE)


class Credentials(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=12, max_length=256)


class EmailAddress(BaseModel):
    email: str = Field(min_length=3, max_length=254)


class AuthenticatedUser(BaseModel):
    id: UUID
    email: str


def _validate_email(email: str) -> str:
    normalized = email.strip().lower()
    if not EMAIL_PATTERN.fullmatch(normalized):
        raise HTTPException(status_code=400, detail="Use a valid @kent.edu email address.")
    return normalized


def _user_payload(user_id: UUID, email: str) -> dict[str, str]:
    return {"id": str(user_id), "email": email}


def _issue_session(db: Session, user_id: UUID, email: str) -> dict[str, Any]:
    token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    expires_at = datetime.now(timezone.utc) + SESSION_LIFETIME
    db.execute(
        text("""
            INSERT INTO app_sessions (user_id, token_hash, expires_at)
            VALUES (:user_id, :token_hash, :expires_at)
        """),
        {"user_id": user_id, "token_hash": token_hash, "expires_at": expires_at},
    )
    db.commit()
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": int(SESSION_LIFETIME.total_seconds()),
        "user": _user_payload(user_id, email),
    }


def _send_verification_email(email: str, token: str) -> None:
    required = ("SMTP_HOST", "SMTP_USERNAME", "SMTP_PASSWORD", "SMTP_FROM", "EMAIL_VERIFICATION_URL")
    settings = {name: os.getenv(name) for name in required}
    if any(not value for value in settings.values()):
        raise RuntimeError("Email verification is not configured on the server.")

    try:
        port = int(os.getenv("SMTP_PORT", "587"))
        verification_url = settings["EMAIL_VERIFICATION_URL"]
        if not verification_url.startswith("https://"):
            raise ValueError("EMAIL_VERIFICATION_URL must use HTTPS.")
        link = f"{verification_url}?{urlencode({'token': token})}"

        message = EmailMessage()
        message["Subject"] = "Verify your KSU Lost & Found account"
        message["From"] = settings["SMTP_FROM"]
        message["To"] = email
        message.set_content(
            "Verify your KSU Lost & Found account by opening this link:\n\n"
            f"{link}\n\nThis link expires in 30 minutes. If you did not request this, ignore this email."
        )

        with smtplib.SMTP(settings["SMTP_HOST"], port, timeout=15) as smtp:
            smtp.starttls(context=ssl.create_default_context())
            smtp.login(settings["SMTP_USERNAME"], settings["SMTP_PASSWORD"])
            smtp.send_message(message)
    except Exception as exc:
        raise RuntimeError("The verification email could not be sent.") from exc


def _create_and_send_verification(db: Session, user_id: UUID, email: str) -> bool:
    recent = db.execute(
        text("""
            SELECT EXISTS (
                SELECT 1 FROM app_email_verification_tokens
                WHERE user_id = :user_id
                  AND consumed_at IS NULL
                  AND created_at > now() - interval '1 minute'
            )
        """),
        {"user_id": user_id},
    ).scalar_one()
    if recent:
        return False

    db.execute(
        text("""
            UPDATE app_email_verification_tokens
            SET consumed_at = now()
            WHERE user_id = :user_id AND consumed_at IS NULL
        """),
        {"user_id": user_id},
    )
    token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    db.execute(
        text("""
            INSERT INTO app_email_verification_tokens (user_id, token_hash, expires_at)
            VALUES (:user_id, :token_hash, :expires_at)
        """),
        {
            "user_id": user_id,
            "token_hash": token_hash,
            "expires_at": datetime.now(timezone.utc) + VERIFICATION_LIFETIME,
        },
    )
    db.commit()

    try:
        _send_verification_email(email, token)
    except RuntimeError as exc:
        db.execute(
            text("UPDATE app_email_verification_tokens SET consumed_at = now() WHERE token_hash = :token_hash"),
            {"token_hash": token_hash},
        )
        db.commit()
        raise HTTPException(
            status_code=503,
            detail="Email delivery is temporarily unavailable. Please try again later.",
        ) from exc
    return True


SIGNUP_NOTICE = "If this address can be registered, a verification email will be sent. Check your inbox."


@router.post("/signup", status_code=status.HTTP_202_ACCEPTED)
def sign_up(credentials: Credentials, db: Session = Depends(get_db)) -> dict[str, str]:
    email = _validate_email(credentials.email)
    password_hash = password_hasher.hash(credentials.password)
    try:
<<<<<<< Updated upstream
        user_id = db.execute(
            text("""
                INSERT INTO users (email, password_hash)
                VALUES (:email, :password_hash)
                RETURNING user_id
            """),
            {"email": email, "password_hash": password_hash},
        ).scalar_one()
        return _issue_session(db, user_id, email)
=======
        row = db.execute(
            text("SELECT id, email_verified_at FROM app_users WHERE email = :email"),
            {"email": email},
        ).mappings().first()
        if row is None:
            user_id = db.execute(
                text("""
                    INSERT INTO app_users (email, password_hash)
                    VALUES (:email, :password_hash)
                    RETURNING id
                """),
                {"email": email, "password_hash": password_hash},
            ).scalar_one()
            db.commit()
            _create_and_send_verification(db, user_id, email)
        elif row["email_verified_at"] is None:
            _create_and_send_verification(db, row["id"], email)
        return {"message": SIGNUP_NOTICE}
>>>>>>> Stashed changes
    except IntegrityError as exc:
        db.rollback()
        return {"message": SIGNUP_NOTICE}


@router.post("/resend-verification", status_code=status.HTTP_202_ACCEPTED)
def resend_verification(request: EmailAddress, db: Session = Depends(get_db)) -> dict[str, str]:
    email = _validate_email(request.email)
    row = db.execute(
        text("SELECT id FROM app_users WHERE email = :email AND email_verified_at IS NULL"),
        {"email": email},
    ).first()
    if row:
        _create_and_send_verification(db, row.id, email)
    return {"message": "If the account needs verification, a new email will be sent."}


@router.get("/verify-email", response_class=HTMLResponse)
def verification_confirmation(token: str) -> HTMLResponse:
    safe_token = html.escape(token, quote=True)
    return HTMLResponse(f"""
        <!doctype html><html lang="en"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Verify KSU Lost &amp; Found</title>
        <body style="font:16px system-ui;max-width:480px;margin:12vh auto;padding:24px;color:#222">
        <h1>Verify your email</h1><p>Confirm this address to activate your KSU Lost &amp; Found account.</p>
        <form method="post" action="/api/auth/verify-email">
        <input type="hidden" name="token" value="{safe_token}">
        <button style="padding:12px 20px;font-size:16px" type="submit">Verify email</button></form>
        </body></html>
    """)


@router.post("/verify-email", response_class=HTMLResponse)
def verify_email(token: str = Form(min_length=20, max_length=256), db: Session = Depends(get_db)) -> HTMLResponse:
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    user_id = db.execute(
        text("""
            UPDATE app_email_verification_tokens
            SET consumed_at = now()
            WHERE token_hash = :token_hash
              AND consumed_at IS NULL
              AND expires_at > now()
            RETURNING user_id
        """),
        {"token_hash": token_hash},
    ).scalar_one_or_none()
    if user_id is None:
        db.rollback()
        return HTMLResponse("<h1>Link expired or already used</h1><p>Return to the app and request another verification email.</p>", status_code=400)

    db.execute(
        text("UPDATE app_users SET email_verified_at = now() WHERE id = :user_id AND email_verified_at IS NULL"),
        {"user_id": user_id},
    )
    db.commit()
    return HTMLResponse("<h1>Email verified</h1><p>Your account is active. Return to KSU Lost &amp; Found and sign in.</p>")


@router.post("/login")
def log_in(credentials: Credentials, db: Session = Depends(get_db)) -> dict[str, Any]:
    email = credentials.email.strip().lower()
    row = db.execute(
<<<<<<< Updated upstream
        text(
            """
            SELECT user_id AS id, email, password_hash
            FROM users
            WHERE email = :email
        """),
=======
        text("SELECT id, email, password_hash, email_verified_at FROM app_users WHERE email = :email"),
>>>>>>> Stashed changes
        {"email": email},
    ).mappings().first()

    valid_password = False
    if row:
        try:
            valid_password = password_hasher.verify(row["password_hash"], credentials.password)
        except (VerifyMismatchError, InvalidHashError):
            valid_password = False
    if not valid_password:
        raise HTTPException(status_code=401, detail="Invalid email or password.")

    if row["email_verified_at"] is None:
        raise HTTPException(status_code=403, detail="Verify your email address before signing in.")

    if password_hasher.check_needs_rehash(row["password_hash"]):
        db.execute(
            text(
                """
                UPDATE users
                SET password_hash = :password_hash
                WHERE user_id = :user_id
            """),
            {"password_hash": password_hasher.hash(credentials.password), "user_id": row["id"]},
        )
        db.commit()

    return _issue_session(db, row["id"], row["email"])


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=401, 
            detail="Authentication required.", 
            headers={"WWW-Authenticate": "Bearer"}
        )

    token_hash = hashlib.sha256(credentials.credentials.encode("utf-8")).hexdigest()
    row = db.execute(
        text("""
            SELECT u.user_id AS id, u.email
            FROM app_sessions s
            JOIN users u ON u.user_id = s.user_id
            WHERE s.token_hash = :token_hash
              AND s.revoked_at IS NULL
              AND s.expires_at > now()
              AND u.email_verified_at IS NOT NULL
        """),
        {"token_hash": token_hash},
    ).mappings().first()

    if row is None:
        raise HTTPException(
            status_code=401, 
            detail="Session is invalid or expired.", 
            headers={"WWW-Authenticate": "Bearer"}
        )
    return AuthenticatedUser(id=row["id"], email=row["email"])


@router.get("/me")
def current_user(user: AuthenticatedUser = Depends(get_current_user)) -> dict[str, str]:
    return _user_payload(user.id, user.email)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def log_out(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    if credentials is None:
        raise HTTPException(
            status_code=401, 
            detail="Authentication required."
        )
    token_hash = hashlib.sha256(credentials.credentials.encode("utf-8")).hexdigest()
    db.execute(
        text("UPDATE app_sessions SET revoked_at = now() WHERE token_hash = :token_hash AND revoked_at IS NULL"),
        {"token_hash": token_hash},
    )
    db.commit()
