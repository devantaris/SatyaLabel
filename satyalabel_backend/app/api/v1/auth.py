"""
Auth API Routes
================
POST /api/v1/auth/register — Create an account (citizen by default)
POST /api/v1/auth/login    — Obtain a JWT access token
GET  /api/v1/auth/me       — Current authenticated user

Role model:
  - Anyone can self-register as a CITIZEN.
  - INSPECTOR/ADMIN accounts can only be created by an ADMIN,
    OR via bootstrap credentials (env: BOOTSTRAP_ADMIN_EMAIL /
    BOOTSTRAP_ADMIN_PASSWORD) to seed the very first admin.
"""
from __future__ import annotations

import logging
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.security import (
    create_access_token,
    get_current_user,
    hash_password,
    verify_password,
)
from app.models.user import User, UserRole
from app.schemas.auth import (
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UserResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter()


def _is_bootstrap_admin(req: RegisterRequest) -> bool:
    """True if the request carries valid first-admin bootstrap credentials."""
    boot_email = getattr(settings, "BOOTSTRAP_ADMIN_EMAIL", None)
    boot_pass = getattr(settings, "BOOTSTRAP_ADMIN_PASSWORD", None)
    if not boot_email or not boot_pass:
        return False
    return (
        req.bootstrap_admin_email == boot_email
        and req.bootstrap_admin_password == boot_pass
    )


async def _email_exists(db: AsyncSession, email: str) -> bool:
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none() is not None


async def _badge_exists(db: AsyncSession, badge: str) -> bool:
    result = await db.execute(select(User).where(User.badge_number == badge))
    return result.scalar_one_or_none() is not None


@router.post(
    "/register",
    summary="Create a new account",
    status_code=status.HTTP_201_CREATED,
    response_model=UserResponse,
)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register a new user. Citizens self-register; inspector/admin roles
    require admin bootstrap credentials (or a future admin endpoint)."""
    if await _email_exists(db, req.email):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists.",
        )

    privileged = req.role in (UserRole.INSPECTOR.value, UserRole.ADMIN.value)
    if privileged and not _is_bootstrap_admin(req):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Privileged roles can only be created via admin bootstrap.",
        )

    if req.badge_number and await _badge_exists(db, req.badge_number):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This badge number is already registered.",
        )

    user = User(
        id=uuid.uuid4(),
        email=req.email,
        hashed_password=hash_password(req.password),
        full_name=req.full_name,
        role=req.role,
        badge_number=req.badge_number,
        district=req.district,
        created_at=datetime.now(UTC),
    )
    db.add(user)
    await db.flush()
    logger.info("New user registered: %s (role=%s)", req.email, req.role)
    return user


@router.post("/login", summary="Obtain a JWT access token", response_model=TokenResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Authenticate with email + password, receive a bearer token."""
    result = await db.execute(select(User).where(User.email == req.email))
    user = result.scalar_one_or_none()

    if user is None or not verify_password(req.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="This account is deactivated.",
        )

    token = create_access_token(user_id=str(user.id), role=user.role)
    return TokenResponse(
        access_token=token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=UserResponse.model_validate(user),
    )


@router.get("/me", summary="Current authenticated user", response_model=UserResponse)
async def me(user: User = Depends(get_current_user)):
    """Return the authenticated user's profile."""
    return user
