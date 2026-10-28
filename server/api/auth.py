import hashlib
import re
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError
from fastapi import APIRouter, Depends, HTTPException, status
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
EMAIL_PATTERN = re.compile(r"^[^\s@]+@kent\.edu$", re.IGNORECASE)


class Credentials(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=12, max_length=256)


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


@router.post("/signup", status_code=status.HTTP_201_CREATED)
def sign_up(credentials: Credentials, db: Session = Depends(get_db)) -> dict[str, Any]:
    email = _validate_email(credentials.email)
    password_hash = password_hasher.hash(credentials.password)
    try:
        user_id = db.execute(
            text("""
                INSERT INTO app_users (email, password_hash)
                VALUES (:email, :password_hash)
                RETURNING id
            """),
            {"email": email, "password_hash": password_hash},
        ).scalar_one()
        return _issue_session(db, user_id, email)
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="An account with this email already exists.") from exc


@router.post("/login")
def log_in(credentials: Credentials, db: Session = Depends(get_db)) -> dict[str, Any]:
    email = credentials.email.strip().lower()
    row = db.execute(
        text("SELECT id, email, password_hash FROM app_users WHERE email = :email"),
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

    if password_hasher.check_needs_rehash(row["password_hash"]):
        db.execute(
            text("UPDATE app_users SET password_hash = :password_hash WHERE id = :user_id"),
            {"password_hash": password_hasher.hash(credentials.password), "user_id": row["id"]},
        )
        db.commit()

    return _issue_session(db, row["id"], row["email"])


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Authentication required.", headers={"WWW-Authenticate": "Bearer"})

    token_hash = hashlib.sha256(credentials.credentials.encode("utf-8")).hexdigest()
    row = db.execute(
        text("""
            SELECT u.id, u.email
            FROM app_sessions s
            JOIN app_users u ON u.id = s.user_id
            WHERE s.token_hash = :token_hash
              AND s.revoked_at IS NULL
              AND s.expires_at > now()
        """),
        {"token_hash": token_hash},
    ).mappings().first()
    if row is None:
        raise HTTPException(status_code=401, detail="Session is invalid or expired.", headers={"WWW-Authenticate": "Bearer"})
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
        raise HTTPException(status_code=401, detail="Authentication required.")
    token_hash = hashlib.sha256(credentials.credentials.encode("utf-8")).hexdigest()
    db.execute(
        text("UPDATE app_sessions SET revoked_at = now() WHERE token_hash = :token_hash AND revoked_at IS NULL"),
        {"token_hash": token_hash},
    )
    db.commit()
