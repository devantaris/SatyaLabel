"""
Security primitives — password hashing (bcrypt) + JWT tokens.

Uses the bcrypt package directly (passlib 1.7.x is unmaintained and
breaks on newer Python versions). JWT via python-jose.
"""
from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.models.user import User, UserRole

# ── Password hashing ─────────────────────────────────────────────────────────

_BCRYPT_ROUNDS = 12


def hash_password(password: str) -> str:
    """Hash a plaintext password with bcrypt. Returns utf-8 str."""
    salt = bcrypt.gensalt(rounds=_BCRYPT_ROUNDS)
    hashed = bcrypt.hashpw(password.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def verify_password(password: str, hashed_password: str) -> bool:
    """Check a plaintext password against a bcrypt hash."""
    try:
        return bcrypt.checkpw(
            password.encode("utf-8"), hashed_password.encode("utf-8")
        )
    except (ValueError, TypeError):
        return False


# ── JWT ──────────────────────────────────────────────────────────────────────

def create_access_token(
    *,
    user_id: str,
    role: str,
    expires_minutes: int | None = None,
) -> str:
    """Create a signed JWT containing the user's id and role."""
    expire = datetime.now(UTC) + timedelta(
        minutes=expires_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload: dict[str, Any] = {
        "sub": user_id,
        "role": role,
        "iat": int(datetime.now(UTC).timestamp()),
        "exp": int(expire.timestamp()),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> dict[str, Any]:
    """Decode and validate a JWT. Raises JWTError on invalid/expired tokens."""
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])


# ── FastAPI dependencies ─────────────────────────────────────────────────────

# tokenUrl points at the login endpoint for OpenAPI docs
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)

_CREDENTIALS_EXCEPTION = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Invalid or expired credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


def _role_forbidden(required: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=f"This action requires the '{required}' role.",
    )


async def get_current_user(
    token: str | None = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Resolve the authenticated user from the Bearer token."""
    if token is None:
        raise _CREDENTIALS_EXCEPTION
    try:
        payload = decode_access_token(token)
        user_id = payload.get("sub")
        if user_id is None:
            raise _CREDENTIALS_EXCEPTION
        uuid.UUID(user_id)  # validate format
    except (JWTError, ValueError):
        raise _CREDENTIALS_EXCEPTION from None

    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise _CREDENTIALS_EXCEPTION
    return user


async def get_current_inspector(
    user: User = Depends(get_current_user),
) -> User:
    """Require inspector or admin role."""
    if user.role not in (UserRole.INSPECTOR.value, UserRole.ADMIN.value):
        raise _role_forbidden(UserRole.INSPECTOR.value)
    return user


async def get_optional_user(
    token: str | None = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User | None:
    """Resolve the user if a valid token is provided; None otherwise.

    Used by scan endpoints: citizens may scan anonymously, but an
    authenticated inspector's scans are bound to their account.
    """
    if token is None:
        return None
    try:
        return await get_current_user(token=token, db=db)
    except HTTPException:
        return None


async def get_current_admin(user: User = Depends(get_current_user)) -> User:
    """Require admin role."""
    if user.role != UserRole.ADMIN.value:
        raise _role_forbidden(UserRole.ADMIN.value)
    return user
