"""
Tests for async scan processing: POST /scans/async + task status flow.
"""
import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)

SCANS_MODULE = "app.api.v1.scans"


def _test_image_bytes():
    import io

    from PIL import Image
    buf = io.BytesIO()
    Image.new("RGB", (600, 300), color=(240, 240, 240)).save(buf, format="JPEG")
    return buf.getvalue()


def _pending_record(**overrides) -> MagicMock:
    record = MagicMock()
    record.id = uuid.UUID(overrides.get("id", str(uuid.uuid4())))
    record.status = overrides.get("status", "PENDING")
    record.verdict = overrides.get("verdict")
    record.image_path = overrides.get("image_path", "abc.jpg")
    record.session_id = overrides.get("session_id", "sess-1")
    record.created_at = overrides.get(
        "created_at", datetime(2026, 9, 11, 12, 0, 0, tzinfo=UTC)
    )
    record.violation_count = 0
    record.ocr_engine = None
    record.ocr_confidence = None
    record.extracted_fields = None
    record.compliance_data = None
    record.preprocess_diagnostics = None
    record.needs_review = False
    record.report_generated = False
    return record


# ── POST /scans/async — happy path ───────────────────────────────────────────

def test_async_scan_dispatches_task():
    fake_task = MagicMock()
    fake_task.delay = MagicMock(return_value=MagicMock(id="task-123"))
    record = _pending_record()

    with patch(f"{SCANS_MODULE}.create_pending_scan", new=AsyncMock(return_value=record)), \
         patch("app.core.scan_tasks.process_scan_task", fake_task):
        resp = client.post(
            "/api/v1/scans/async",
            files={"image": ("test.jpg", _test_image_bytes(), "image/jpeg")},
            data={"session_id": "sess-9"},
        )

    assert resp.status_code == 202
    data = resp.json()
    assert data["status"] == "PENDING"
    assert "scan_id" in data
    assert data["session_id"] == "sess-9"


def test_async_scan_falls_back_to_sync(monkeypatch):
    """If Celery broker is down, the endpoint runs the scan synchronously."""
    from app.services.ocr_service import OcrLine, OcrResult

    mock_text = (
        "Net Qty: 100g\nMRP Rs. 10\nMfg: Jan 2025\nBest Before: Jan 2027\n"
        "Manufactured by: Test Foods\nConsumer Care: 1800-000-0000"
    )
    lines = [
        OcrLine(text=ln, confidence=0.9, bbox=(10, i * 25, 300, 20), engine="tesseract")
        for i, ln in enumerate(mock_text.split("\n"))
    ]
    mock_ocr = OcrResult(
        raw_text=mock_text, lines=lines, engine_used="tesseract",
        mean_confidence=0.9, needs_manual_review=False,
    )
    monkeypatch.setattr(
        "app.services.ocr_service.OcrService.run", lambda self, prep: mock_ocr
    )

    record = _pending_record()
    # delay() raises → fallback path
    broken_task = MagicMock()
    broken_task.delay = MagicMock(side_effect=ConnectionError("broker down"))

    with patch(f"{SCANS_MODULE}.create_pending_scan", new=AsyncMock(return_value=record)), \
         patch(f"{SCANS_MODULE}.complete_scan", new=AsyncMock()), \
         patch("app.core.scan_tasks.process_scan_task", broken_task):
        resp = client.post(
            "/api/v1/scans/async",
            files={"image": ("test.jpg", _test_image_bytes(), "image/jpeg")},
        )

    assert resp.status_code == 202
    data = resp.json()
    assert data["status"] == "COMPLETED"
    assert "verdict" in data


def test_async_scan_invalid_image_415():
    resp = client.post(
        "/api/v1/scans/async",
        files={"image": ("doc.txt", b"x" * 2048, "text/plain")},
    )
    assert resp.status_code == 415


# ── GET /scans/{id} — status values ──────────────────────────────────────────

def test_get_scan_pending_status():
    record = _pending_record(status="PROCESSING", verdict=None)
    with patch(f"{SCANS_MODULE}.get_scan", new=AsyncMock(return_value=record)):
        resp = client.get(f"/api/v1/scans/{record.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "PROCESSING"
    assert data["verdict"] is None


def test_get_scan_failed_status():
    record = _pending_record(status="FAILED")
    record.compliance_data = {"error": "boom"}
    with patch(f"{SCANS_MODULE}.get_scan", new=AsyncMock(return_value=record)):
        resp = client.get(f"/api/v1/scans/{record.id}")
    assert resp.status_code == 200
    assert resp.json()["status"] == "FAILED"


# ── Celery task unit test (mocked persistence) ───────────────────────────────

def test_process_scan_task_persists_results(monkeypatch, tmp_path):
    """process_scan_task runs pipeline + complete_scan with correct args."""
    from app.core.scan_tasks import _run_pipeline_and_persist
    from app.services.ocr_service import OcrLine, OcrResult

    mock_text = "MRP Rs. 30\nNet Qty: 250g\nMfg: Jan 2025\nBest Before: Jan 2027\nManufactured by: X\nConsumer Care: 1800-111-2222"
    lines = [
        OcrLine(text=ln, confidence=0.9, bbox=(10, i * 25, 300, 20), engine="tesseract")
        for i, ln in enumerate(mock_text.split("\n"))
    ]
    mock_ocr = OcrResult(
        raw_text=mock_text, lines=lines, engine_used="tesseract",
        mean_confidence=0.9, needs_manual_review=False,
    )
    monkeypatch.setattr(
        "app.services.ocr_service.OcrService.run", lambda self, prep: mock_ocr
    )

    # Write a fake uploaded image
    img_path = tmp_path / "img.jpg"
    img_path.write_bytes(_test_image_bytes())

    captured = {}

    async def fake_complete(session, scan_id, **kwargs):
        captured.update(kwargs)
        captured["scan_id"] = scan_id

    async def fake_session_ctx():
        class Ctx:
            async def __aenter__(self):
                return MagicMock()

            async def __aexit__(self, *a):
                return False
        return Ctx()

    with patch("app.core.scan_tasks.settings") as mock_settings, \
         patch("app.core.scan_tasks.complete_scan", new=fake_complete), \
         patch("app.core.scan_tasks.AsyncSessionLocal") as mock_session_local:
        mock_settings.UPLOAD_DIR = str(tmp_path)
        mock_session_local.return_value = MagicMock()
        mock_session_local.side_effect = None
        # AsyncSessionLocal() used as async context manager
        class _Factory:
            def __call__(self):
                class Ctx:
                    async def __aenter__(self):
                        return MagicMock()

                    async def __aexit__(self, *a):
                        return False
                return Ctx()
        mock_session_local.side_effect = None
        mock_session_local.__call__ = lambda *a, **k: _Factory()()
        result = _run_pipeline_and_persist(str(uuid.uuid4()), "img.jpg")

    assert result["verdict"] is not None
    assert captured["verdict"] == result["verdict"]
    assert captured["ocr_engine"] == "tesseract"
    assert captured["extracted_fields"]["mrp"]["found"] is True
