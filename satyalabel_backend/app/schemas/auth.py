"""
Auth API schemas (Pydantic v2).
"""
from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    full_name: str | None = Field(None, max_length=255)
    role: str = Field("citizen", pattern="^(citizen|inspector|admin)$")
    badge_number: str | None = Field(None, max_length=64)
    district: str | None = Field(None, max_length=128)
    # Bootstrap credentials allow creating the FIRST admin account
    bootstrap_admin_email: str | None = None
    bootstrap_admin_password: str | None = None


class UserResponse(BaseModel):
    id: uuid.UUID
    email: EmailStr
    full_name: str | None
    role: str
    badge_number: str | None
    district: str | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int  # seconds
    user: UserResponse
