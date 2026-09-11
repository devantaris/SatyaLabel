"""
Analytics API tests — mocked DB sessions (no live Postgres required).
"""
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.security import get_current_inspector
from main import app
from tests.conftest import make_user

client = TestClient(app)


class _FakeMappings:
    def __init__(self, rows):
        self._rows = rows

    def all(self):
        return self._rows

    def first(self):
        return self._rows[0] if self._rows else None


class _FakeResult:
    def __init__(self, rows):
        self._mappings = _FakeMappings(rows)

    def mappings(self):
        return self._mappings


@pytest.fixture
def inspector_auth():
    app.dependency_overrides[get_current_inspector] = lambda: make_user(
        role="inspector", district="New Delhi"
    )
    yield
    app.dependency_overrides.pop(get_current_inspector, None)


def _set_execute(mock_db_session, rows):
    mock_db_session.execute = AsyncMock(return_value=_FakeResult(rows))


def test_overview(mock_db_session, inspector_auth):
    _set_execute(
        mock_db_session,
        [{
            "total_scans": 42,
            "non_compliant": 10,
            "needs_verification": 5,
            "compliant": 27,
            "needs_review": 3,
            "sessions": 4,
            "scans_24h": 12,
        }],
    )
    response = client.get("/api/v1/analytics/overview")
    assert response.status_code == 200
    body = response.json()
    assert body["total_scans"] == 42
    assert body["non_compliant"] == 10
    assert body["scans_24h"] == 12


def test_heatmap(mock_db_session, inspector_auth):
    _set_execute(
        mock_db_session,
        [{
            "latitude": 28.6139,
            "longitude": 77.2090,
            "total_scans": 8,
            "violations": 6,
            "needs_verification": 1,
        }],
    )
    response = client.get("/api/v1/analytics/heatmap?grid_size=0.1&min_scans=2")
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1
    point = body["points"][0]
    assert point["latitude"] == 28.6139
    assert point["longitude"] == 77.2090
    assert point["violations"] == 6
    assert point["violation_rate"] == 0.75


def test_manufacturers(mock_db_session, inspector_auth):
    _set_execute(
        mock_db_session,
        [{
            "manufacturer": "Britannia",
            "total_scans": 5,
            "non_compliant": 3,
            "needs_verification": 1,
            "compliant": 1,
            "last_seen": None,
        }],
    )
    response = client.get("/api/v1/analytics/manufacturers?min_scans=2")
    assert response.status_code == 200
    item = response.json()["items"][0]
    assert item["manufacturer"] == "Britannia"
    assert item["non_compliant"] == 3
    assert item["last_seen"] is None


def test_districts(mock_db_session, inspector_auth):
    _set_execute(
        mock_db_session,
        [{
            "district": "New Delhi",
            "total_scans": 15,
            "non_compliant": 4,
            "needs_verification": 2,
            "contributors": 3,
        }],
    )
    response = client.get("/api/v1/analytics/districts")
    assert response.status_code == 200
    assert response.json()["items"][0]["district"] == "New Delhi"


def test_csv_export(mock_db_session, inspector_auth):
    _set_execute(
        mock_db_session,
        [{
            "scan_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
            "created_at": "2026-09-11T12:00:00+00:00",
            "verdict": "NON_COMPLIANT",
            "violation_count": 2,
            "session_id": "raid-01",
            "needs_review": False,
            "manufacturer": "Britannia",
            "mrp": "25.00",
            "net_quantity": "200g",
            "country_of_origin": "India",
            "latitude": 28.6139,
            "longitude": 77.2090,
            "district": "New Delhi",
        }],
    )
    response = client.get("/api/v1/analytics/export")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/csv")
    assert "satyalabel_evidence_" in response.headers["content-disposition"]

    lines = response.text.strip().splitlines()
    assert lines[0].startswith("scan_id,created_at,verdict")
    assert "7c9e6679-7425-40de-944b-e07fc1f90ae7" in lines[1]
    assert "Britannia" in lines[1]
    assert "28.613900" in lines[1]


def test_requires_authentication(mock_db_session):
    """Anonymous citizens cannot access enforcement analytics."""
    response = client.get("/api/v1/analytics/overview")
    assert response.status_code in (401, 403)


def test_invalid_days_rejected(mock_db_session, inspector_auth):
    response = client.get("/api/v1/analytics/overview?days=0")
    assert response.status_code == 400
    assert "days" in response.json()["detail"]


def test_invalid_grid_size_rejected(mock_db_session, inspector_auth):
    response = client.get("/api/v1/analytics/heatmap?grid_size=0")
    assert response.status_code == 422  # pydantic/fastapi validation
