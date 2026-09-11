"""
Unit tests for the PDF report generator.
"""
import io
from PIL import Image
import pytest

from app.services.field_extractor import ExtractedField, ExtractedFields
from app.services.rule_engine import RuleEngine, Verdict
from app.services.report_generator import generate_inspection_pdf


def _dummy_image_bytes() -> bytes:
    img = Image.new("RGB", (200, 100), color=(240, 240, 240))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_generate_pdf_compliant():
    engine = RuleEngine()
    fields = ExtractedFields(
        mrp=ExtractedField("mrp", "50.00", 0.95),
        net_quantity=ExtractedField("net_quantity", "200g", 0.90),
        mfg_date=ExtractedField("mfg_date", "Jan 2025", 0.88),
        best_before_date=ExtractedField("best_before_date", "Jan 2027", 0.89),
        manufacturer=ExtractedField("manufacturer", "Britannia Industries Ltd", 0.85),
        consumer_phone=ExtractedField("consumer_phone", "18001234567", 0.92),
        consumer_email=ExtractedField("consumer_email", "care@britannia.co.in", 0.91),
        batch_number=ExtractedField("batch_number", "B-001", 0.84),
        country_of_origin=ExtractedField("country_of_origin", "India", 0.80),
        generic_name=ExtractedField("generic_name", "Biscuits", 0.82),
    )
    report = engine.run(fields)
    assert report.verdict == Verdict.COMPLIANT

    pdf_bytes = generate_inspection_pdf(
        compliance_report=report,
        scan_id="test-scan-001",
        image_bytes=_dummy_image_bytes(),
        location_hint="Test Market, New Delhi",
    )
    assert pdf_bytes is not None
    assert len(pdf_bytes) > 1000
    assert pdf_bytes.startswith(b"%PDF-")


def test_generate_pdf_non_compliant():
    engine = RuleEngine()
    fields = ExtractedFields(
        mrp=ExtractedField("mrp", None, 0.0),  # Missing MRP
        net_quantity=ExtractedField("net_quantity", "200g", 0.90),
        mfg_date=ExtractedField("mfg_date", "Jan 2025", 0.88),
        best_before_date=ExtractedField("best_before_date", "Dec 2024", 0.89),  # Date inconsistency!
        manufacturer=ExtractedField("manufacturer", None, 0.0),  # Missing manufacturer
        consumer_phone=ExtractedField("consumer_phone", None, 0.0),
        consumer_email=ExtractedField("consumer_email", None, 0.0),
        batch_number=ExtractedField("batch_number", None, 0.0),
        country_of_origin=ExtractedField("country_of_origin", None, 0.0),
        generic_name=ExtractedField("generic_name", None, 0.0),
    )
    report = engine.run(fields)
    assert report.verdict == Verdict.NON_COMPLIANT
    assert report.violation_count > 0

    pdf_bytes = generate_inspection_pdf(
        compliance_report=report,
        scan_id="test-scan-violation",
        image_bytes=None,
    )
    assert pdf_bytes is not None
    assert len(pdf_bytes) > 1000
    assert pdf_bytes.startswith(b"%PDF-")
