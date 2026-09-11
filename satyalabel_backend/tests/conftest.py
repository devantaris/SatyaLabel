"""
Shared test fixtures — overrides the DB dependency with a mock session
so no live Postgres is required for API tests.
"""
import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.database import get_db
from main import app


def make_user(**overrides) -> MagicMock:
    """Build a mock User with realistic values."""
    user = MagicMock()
    user.id = uuid.UUID(overrides.get("id", str(uuid.uuid4())))
    user.email = overrides.get("email", "user@example.com")
    user.hashed_password = overrides.get(
        "hashed_password", "$2b$12$fakehashfakehashfakehashfakehashfake"
    )
    if "password" in overrides:
        from app.core.security import hash_password

        user.hashed_password = hash_password(overrides["password"])
    user.full_name = overrides.get("full_name", "Test User")
    user.role = overrides.get("role", "citizen")
    user.badge_number = overrides.get("badge_number")
    user.district = overrides.get("district")
    user.is_active = overrides.get("is_active", True)
    user.created_at = overrides.get("created_at", datetime.now(UTC))
    return user


@pytest.fixture(autouse=True)
def mock_db_session(monkeypatch):
    """Override get_db with a MagicMock session whose async methods are AsyncMock."""
    session = MagicMock()
    session.execute = AsyncMock(return_value=MagicMock())
    session.flush = AsyncMock()
    session.commit = AsyncMock()
    session.rollback = AsyncMock()
    session.close = AsyncMock()

    async def fake_get_db():
        yield session

    app.dependency_overrides[get_db] = fake_get_db
    yield session
    app.dependency_overrides.clear()


def override_db_with_scalars(scalars):
    """
    Override get_db with a session whose execute() returns results whose
    scalar_one_or_none() yields scalars[i] on successive calls
    (repeats the last value if exhausted). Restores on exit — use as a
    context manager.
    """
    from contextlib import contextmanager

    from app.core.database import get_db as get_db_dep

    @contextmanager
    def _ctx():
        session = MagicMock()
        session.flush = AsyncMock()
        session.commit = AsyncMock()
        session.rollback = AsyncMock()
        session.close = AsyncMock()
        calls = {"i": 0}

        async def fake_execute(stmt):
            result = MagicMock()

            def scalar_one_or_none():
                idx = min(calls["i"], len(scalars) - 1)
                calls["i"] += 1
                return scalars[idx]

            result.scalar_one_or_none = scalar_one_or_none
            return result

        session.execute = fake_execute

        async def fake_get_db():
            yield session

        app.dependency_overrides[get_db_dep] = fake_get_db
        try:
            yield session
        finally:
            # restore the default conftest override (no-op if outer fixture cleared)
            app.dependency_overrides.pop(get_db_dep, None)

    return _ctx()
