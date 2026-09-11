"""
Tests for scan persistence: repository functions and GET endpoints
using a mocked AsyncSession (no live Postgres required).
"""
import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient

from app.services.scan_repository import build_location_column, scan_to_dict
from main import app

client = TestClient(app)

# Endpoint module imports repository functions by name — patch there.
SCANS_MODULE = "app.api.v1.scans"


def _make_scan_record(**overrides) -> MagicMock:
    """Build a mock ScanRecord with realistic field values."""
    record = MagicMock()
    record.id = uuid.UUID(overrides.get("id", str(uuid.uuid4())))
    record.status = overrides.get("status", "COMPLETED")
    record.verdict = overrides.get("verdict", "NON_COMPLIANT")
    record.violation_count = overrides.get("violation_count", 2)
    record.ocr_engine = overrides.get("ocr_engine", "tesseract")
    record.ocr_confidence = overrides.get("ocr_confidence", 0.91)
    record.extracted_fields = overrides.get("extracted_fields", {"mrp": {"found": True}})
    record.compliance_data = overrides.get("compliance_data", {"verdict": "NON_COMPLIANT"})
    record.preprocess_diagnostics = overrides.get("preprocess_diagnostics", {})
    record.session_id = overrides.get("session_id", "session-1")
    record.image_path = overrides.get("image_path", "abc123.jpg")
    record.needs_review = overrides.get("needs_review", False)
    record.report_generated = overrides.get("report_generated", False)
    record.created_at = overrides.get(
        "created_at", datetime(2026, 9, 11, 12, 0, 0, tzinfo=UTC)
    )
    return record


# ── build_location_column ────────────────────────────────────────────────────

def test_build_location_column_none():
    assert build_location_column(None, 77.2) is None
    assert build_location_column(28.6, None) is None


def test_build_location_column_point():
    col = build_location_column(28.6139, 77.2090)
    assert col is not None


# ── scan_to_dict ─────────────────────────────────────────────────────────────

def test_scan_to_dict_serialization():
    record = _make_scan_record()
    d = scan_to_dict(record)
    assert d["scan_id"] == str(record.id)
    assert d["status"] == "COMPLETED"
    assert d["verdict"] == "NON_COMPLIANT"
    assert d["image_url"] == "/uploads/abc123.jpg"
    assert d["created_at"].startswith("2026-09-11")


def test_scan_to_dict_no_image():
    record = _make_scan_record(image_path=None)
    assert scan_to_dict(record)["image_url"] is None


# ── GET /scans/{id} ──────────────────────────────────────────────────────────

def test_get_scan_404_not_found():
    with patch(f"{SCANS_MODULE}.get_scan", new=AsyncMock(return_value=None)):
        resp = client.get(f"/api/v1/scans/{uuid.uuid4()}")
    assert resp.status_code == 404


def test_get_scan_200_returns_record():
    record = _make_scan_record()
    with patch(f"{SCANS_MODULE}.get_scan", new=AsyncMock(return_value=record)):
        resp = client.get(f"/api/v1/scans/{record.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["scan_id"] == str(record.id)
    assert data["verdict"] == "NON_COMPLIANT"
    assert data["image_url"] == "/uploads/abc123.jpg"


def test_get_scan_invalid_uuid_404():
    with patch(f"{SCANS_MODULE}.get_scan", new=AsyncMock(return_value=None)):
        resp = client.get("/api/v1/scans/not-a-uuid")
    assert resp.status_code == 404


# ── GET /scans/ (list) ───────────────────────────────────────────────────────

def test_list_scans_endpoint():
    records = [_make_scan_record() for _ in range(3)]
    with patch(
        f"{SCANS_MODULE}.list_scans", new=AsyncMock(return_value=(records, 3))
    ):
        resp = client.get("/api/v1/scans/?limit=10&offset=0")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
    assert len(data["items"]) == 3
    assert data["limit"] == 10
    assert data["offset"] == 0


def test_list_scans_invalid_verdict_400():
    resp = client.get("/api/v1/scans/?verdict=BOGUS")
    assert resp.status_code == 400


def test_list_scans_invalid_pagination_400():
    resp = client.get("/api/v1/scans/?limit=0")
    assert resp.status_code == 400


# ── POST /scans/ persists ────────────────────────────────────────────────────

def _mock_ocr(monkeypatch, verdict_text):
    from app.services.ocr_service import OcrLine, OcrResult
    lines = [
        OcrLine(text=ln, confidence=0.92, bbox=(10, i * 25, 400, 20), engine="tesseract")
        for i, ln in enumerate(verdict_text.split("\n"))
    ]
    mock_ocr = OcrResult(
        raw_text=verdict_text, lines=lines, engine_used="tesseract",
        mean_confidence=0.92, needs_manual_review=False,
    )
    monkeypatch.setattr(
        "app.services.ocr_service.OcrService.run", lambda self, prep: mock_ocr
    )


def _test_image_bytes():
    import io

    from PIL import Image
    buf = io.BytesIO()
    Image.new("RGB", (600, 300), color=(240, 240, 240)).save(buf, format="JPEG")
    return buf.getvalue()


def test_post_scan_persists_record(monkeypatch):
    _mock_ocr(
        monkeypatch,
        "BRITANNIA Marie Gold Biscuits\nNet Qty: 200g\nMRP Rs. 25.00\n"
        "Mfg: Jan 2025\nBest Before: Jan 2027\nManufactured by: Britannia Industries Ltd\n"
        "Consumer Care: 1800-103-1516\ncare@britannia.co.in\nBatch No: MG-2025-01",
    )

    saved = {}

    async def fake_save_scan(session, **kwargs):
        saved.update(kwargs)
        return _make_scan_record(verdict=kwargs.get("verdict", "COMPLIANT"))

    with patch(f"{SCANS_MODULE}.save_scan", new=fake_save_scan):
        resp = client.post(
            "/api/v1/scans/",
            files={"image": ("test.jpg", _test_image_bytes(), "image/jpeg")},
            data={"latitude": 28.6139, "longitude": 77.2090, "session_id": "sess-42"},
        )

    assert resp.status_code == 200
    assert resp.json()["verdict"] == "COMPLIANT"
    # save_scan was called with the pipeline results
    assert saved["verdict"] == "COMPLIANT"
    assert saved["session_id"] == "sess-42"
    assert saved["needs_review"] is False
    assert saved["image_path"].endswith(".jpg")
    assert saved["extracted_fields"]["mrp"]["found"] is True


def test_post_scan_survives_persistence_failure(monkeypatch):
    """Scan result is still returned even if DB persistence fails."""
    _mock_ocr(
        monkeypatch,
        "Net Qty: 100g\nMRP Rs. 10\nMfg: Jan 2025\nBest Before: Jan 2027\n"
        "Manufactured by: Test Foods\nConsumer Care: 1800-000-0000",
    )

    async def failing_save_scan(session, **kwargs):
        raise RuntimeError("DB down")

    with patch(f"{SCANS_MODULE}.save_scan", new=failing_save_scan):
        resp = client.post(
            "/api/v1/scans/",
            files={"image": ("test.jpg", _test_image_bytes(), "image/jpeg")},
        )

    assert resp.status_code == 200
    assert "scan_id" in resp.json()
