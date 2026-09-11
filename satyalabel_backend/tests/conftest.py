"""
Shared test fixtures — overrides the DB dependency with a mock session
so no live Postgres is required for API tests.
"""
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.database import get_db
from main import app


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
