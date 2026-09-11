"""
Integration tests for FastAPI scan endpoints.
"""
import io

from fastapi.testclient import TestClient
from PIL import Image

from main import app

client = TestClient(app)


def _make_test_image(text: str = "BRITANNIA Marie Gold\nMRP Rs. 20\nNet Qty: 200g") -> bytes:
    img = Image.new("RGB", (600, 300), color=(240, 240, 240))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "SatyaLabel"


def test_scan_endpoint_success(monkeypatch):
    """Test POST /api/v1/scans with mocked OCR to ensure end-to-end API response contract."""
    from app.services.ocr_service import OcrLine, OcrResult

    mock_text = (
        "BRITANNIA Marie Gold Biscuits\n"
        "Net Qty: 200g\n"
        "MRP Rs. 25.00 (Inclusive of all taxes)\n"
        "Mfg: Jan 2025\n"
        "Best Before: Jan 2027\n"
        "Manufactured by: Britannia Industries Ltd\n"
        "Consumer Care: 1800-103-1516\n"
        "care@britannia.co.in\n"
        "Batch No: MG-2025-01"
    )
    lines = [
        OcrLine(text=ln, confidence=0.92, bbox=(10, i * 25, 400, 20), engine="tesseract")
        for i, ln in enumerate(mock_text.split("\n"))
    ]
    mock_ocr = OcrResult(
        raw_text=mock_text,
        lines=lines,
        engine_used="tesseract",
        mean_confidence=0.92,
        needs_manual_review=False,
    )

    # Monkeypatch OcrService.run to isolate API contract testing
    monkeypatch.setattr("app.services.ocr_service.OcrService.run", lambda self, prep: mock_ocr)

    img_bytes = _make_test_image()
    response = client.post(
        "/api/v1/scans/",
        files={"image": ("test_label.jpg", img_bytes, "image/jpeg")},
        data={"latitude": 28.6139, "longitude": 77.2090, "session_id": "session-123"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "scan_id" in data
    assert data["verdict"] == "COMPLIANT"
    assert data["extracted_fields"]["mrp"]["found"] is True
    assert "25" in data["extracted_fields"]["mrp"]["value"]
    assert data["location"]["latitude"] == 28.6139
    assert data["session_id"] == "session-123"


def test_scan_pdf_report_endpoint(monkeypatch):
    """Test POST /api/v1/scans/report generates downloadable PDF."""
    from app.services.ocr_service import OcrLine, OcrResult

    mock_text = (
        "Sample Biscuit Label\n"
        "Net Qty: 100g\n"
        "Mfg: Jan 2025\n"
        "Best Before: Jan 2026\n"
        "Manufactured by: Test Foods\n"
        "Consumer Care: 1800-000-0000"
    )
    lines = [
        OcrLine(text=ln, confidence=0.88, bbox=(10, i * 25, 300, 20), engine="tesseract")
        for i, ln in enumerate(mock_text.split("\n"))
    ]
    mock_ocr = OcrResult(
        raw_text=mock_text,
        lines=lines,
        engine_used="tesseract",
        mean_confidence=0.88,
        needs_manual_review=False,
    )
    monkeypatch.setattr("app.services.ocr_service.OcrService.run", lambda self, prep: mock_ocr)

    img_bytes = _make_test_image()
    response = client.post(
        "/api/v1/scans/report",
        files={"image": ("test_label.jpg", img_bytes, "image/jpeg")},
        data={"inspector_badge": "INSP-007"},
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content.startswith(b"%PDF-")


def test_scan_invalid_file_type():
    response = client.post(
        "/api/v1/scans/",
        files={"image": ("document.txt", b"plain text data", "text/plain")},
    )
    assert response.status_code == 415
