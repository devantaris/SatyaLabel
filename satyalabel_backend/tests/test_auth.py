"""
Tests for auth: password hashing, JWT round-trips, register/login/me,
and role guards — all with mocked DB sessions.
"""
import uuid

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)
from main import app
from tests.conftest import make_user, override_db_with_scalars

client = TestClient(app)

AUTH = "app.api.v1.auth"


# ── Password hashing ─────────────────────────────────────────────────────────

def test_hash_and_verify_password():
    hashed = hash_password("S3cretPass!")
    assert hashed != "S3cretPass!"
    assert verify_password("S3cretPass!", hashed)
    assert not verify_password("wrong", hashed)


def test_hash_password_unique_salts():
    assert hash_password("same") != hash_password("same")


def test_verify_password_garbage_hash():
    assert verify_password("x", "not-a-real-hash") is False


# ── JWT ──────────────────────────────────────────────────────────────────────

def test_token_round_trip():
    token = create_access_token(user_id="abc-123", role="inspector")
    payload = decode_access_token(token)
    assert payload["sub"] == "abc-123"
    assert payload["role"] == "inspector"
    assert "exp" in payload


def test_expired_token_rejected():
    from jose import JWTError

    token = create_access_token(
        user_id="u1", role="citizen", expires_minutes=-1
    )
    with pytest.raises(JWTError):
        decode_access_token(token)


def test_tampered_token_rejected():
    from jose import JWTError

    token = create_access_token(user_id="u1", role="citizen")
    with pytest.raises(JWTError):
        decode_access_token(token + "tampered")


# ── POST /auth/register ──────────────────────────────────────────────────────

def test_register_citizen_success():
    with patch_db_execute(scalars=[None, None]):  # no email conflict
        resp = client.post("/api/v1/auth/register", json={
            "email": "a@b.com", "password": "password123",
            "full_name": "Test User",
        })
    assert resp.status_code == 201
    assert resp.json()["email"] == "a@b.com"
    assert resp.json()["role"] == "citizen"


def test_register_duplicate_email_409():
    existing = make_user(email="a@b.com")
    with patch_db_execute(scalars=[existing]):
        resp = client.post("/api/v1/auth/register", json={
            "email": "a@b.com", "password": "password123",
        })
    assert resp.status_code == 409


def test_register_inspector_forbidden_without_bootstrap():
    with patch_db_execute(scalars=[None]):
        resp = client.post("/api/v1/auth/register", json={
            "email": "insp@b.com", "password": "password123",
            "role": "inspector", "badge_number": "INSP-001",
        })
    assert resp.status_code == 403


def test_register_inspector_with_bootstrap(monkeypatch):
    monkeypatch.setattr(settings, "BOOTSTRAP_ADMIN_EMAIL", "root@x.com")
    monkeypatch.setattr(settings, "BOOTSTRAP_ADMIN_PASSWORD", "rootpass")
    with patch_db_execute(scalars=[None, None]):
        resp = client.post("/api/v1/auth/register", json={
            "email": "insp@b.com", "password": "password123",
            "role": "inspector", "badge_number": "INSP-001",
            "bootstrap_admin_email": "root@x.com",
            "bootstrap_admin_password": "rootpass",
        })
    assert resp.status_code == 201
    assert resp.json()["role"] == "inspector"


def test_register_short_password_422():
    resp = client.post("/api/v1/auth/register", json={
        "email": "a@b.com", "password": "short",
    })
    assert resp.status_code == 422


# ── POST /auth/login ─────────────────────────────────────────────────────────

def test_login_success():
    user = make_user(email="a@b.com", password="password123")
    with patch_db_execute(scalars=[user]):
        resp = client.post("/api/v1/auth/login", json={
            "email": "a@b.com", "password": "password123",
        })
    assert resp.status_code == 200
    data = resp.json()
    assert data["token_type"] == "bearer"
    assert data["access_token"]
    assert data["user"]["email"] == "a@b.com"


def test_login_wrong_password_401():
    user = make_user(email="a@b.com", password="password123")
    with patch_db_execute(scalars=[user]):
        resp = client.post("/api/v1/auth/login", json={
            "email": "a@b.com", "password": "wrong-pass",
        })
    assert resp.status_code == 401


def test_login_unknown_email_401():
    with patch_db_execute(scalars=[None]):
        resp = client.post("/api/v1/auth/login", json={
            "email": "ghost@b.com", "password": "whatever1",
        })
    assert resp.status_code == 401


def test_login_inactive_user_401():
    user = make_user(email="a@b.com", password="password123", is_active=False)
    with patch_db_execute(scalars=[user]):
        resp = client.post("/api/v1/auth/login", json={
            "email": "a@b.com", "password": "password123",
        })
    assert resp.status_code == 401


# ── GET /auth/me + role guards ───────────────────────────────────────────────

def test_me_with_valid_token():
    user = make_user(email="a@b.com")
    token = create_access_token(user_id=str(user.id), role=user.role)
    with patch_db_execute(scalars=[user]):
        resp = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["email"] == "a@b.com"


def test_me_without_token_401():
    resp = client.get("/api/v1/auth/me")
    assert resp.status_code == 401


def test_me_with_garbage_token_401():
    resp = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer not.a.token"})
    assert resp.status_code == 401


def test_me_with_unknown_user_401():
    token = create_access_token(user_id=str(uuid.uuid4()), role="citizen")
    with patch_db_execute(scalars=[None]):
        resp = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 401


def test_role_guards():
    """Direct unit tests of the dependency functions with mock users."""
    import asyncio

    from app.core.security import get_current_admin, get_current_inspector

    citizen = make_user(role="citizen")
    inspector = make_user(role="inspector")
    admin = make_user(role="admin")

    # inspector guard
    assert asyncio.run(get_current_inspector(inspector)) is inspector
    assert asyncio.run(get_current_inspector(admin)) is admin
    with pytest.raises(Exception) as e:
        asyncio.run(get_current_inspector(citizen))
    assert e.value.status_code == 403

    # admin guard
    assert asyncio.run(get_current_admin(admin)) is admin
    with pytest.raises(Exception) as e:
        asyncio.run(get_current_admin(inspector))
    assert e.value.status_code == 403


# ── helpers ──────────────────────────────────────────────────────────────────

def patch_db_execute(scalars):
    """See conftest.override_db_with_scalars — sequential scalar results."""
    return override_db_with_scalars(scalars)
