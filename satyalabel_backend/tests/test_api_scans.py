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


def test_scan_with_client_ocr_text_skips_server_ocr(monkeypatch):
    """POST /scans with client_ocr_text (ML Kit) must skip server OCR entirely."""
    def _fail(self, prep):
        raise AssertionError("server OCR must not run when client_ocr_text is provided")

    monkeypatch.setattr("app.services.ocr_service.OcrService.run", _fail)

    client_text = (
        "TATA Salt\n"
        "Net Qty: 1 kg\n"
        "MRP Rs. 30.00\n"
        "Mfg: 12 Jan 2026\n"
        "Best Before: 12 Jan 2027\n"
        "Manufactured by: Tata Chemicals Ltd\n"
        "Consumer Care: 1800-209-1100\n"
        "care@tatachemicals.com\n"
        "Batch No: TCS-2026-01\n"
    )
    response = client.post(
        "/api/v1/scans/",
        files={"image": ("test_label.jpg", _make_test_image(), "image/jpeg")},
        data={"client_ocr_text": client_text},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["ocr"]["engine_used"] == "mlkit"
    assert data["verdict"] == "COMPLIANT"
    assert data["extracted_fields"]["mrp"]["found"] is True
    assert "30" in data["extracted_fields"]["mrp"]["value"]


def test_scan_with_blank_client_ocr_text_falls_back_to_server_ocr(monkeypatch):
    """Empty/whitespace client_ocr_text is treated as absent — server OCR runs."""
    from app.services.ocr_service import OcrLine, OcrResult

    mock_ocr = OcrResult(
        raw_text="MRP Rs. 10",
        lines=[OcrLine(text="MRP Rs. 10", confidence=0.9, bbox=(0, 0, 1, 1), engine="tesseract")],
        engine_used="tesseract",
        mean_confidence=0.9,
        needs_manual_review=False,
    )
    monkeypatch.setattr("app.services.ocr_service.OcrService.run", lambda self, prep: mock_ocr)

    response = client.post(
        "/api/v1/scans/",
        files={"image": ("test_label.jpg", _make_test_image(), "image/jpeg")},
        data={"client_ocr_text": "   "},
    )
    assert response.status_code == 200
    assert response.json()["ocr"]["engine_used"] == "tesseract"


def test_scan_rejects_oversized_client_ocr_text():
    response = client.post(
        "/api/v1/scans/",
        files={"image": ("test_label.jpg", _make_test_image(), "image/jpeg")},
        data={"client_ocr_text": "x" * 20_001},
    )
    assert response.status_code == 400
