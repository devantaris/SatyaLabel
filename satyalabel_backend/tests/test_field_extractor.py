"""
Tests for the Field Extractor — regex patterns against realistic label text.
"""
from __future__ import annotations

import pytest
from app.services.ocr_service import OcrResult, OcrLine
from app.services.field_extractor import FieldExtractor, extract_fields


def _make_ocr(text: str, conf: float = 0.85) -> OcrResult:
    """Create a minimal OcrResult from a multi-line string."""
    lines = []
    for i, line_text in enumerate(text.strip().split("\n")):
        if line_text.strip():
            lines.append(OcrLine(
                text=line_text.strip(),
                confidence=conf,
                bbox=(0, i * 30, 500, 25),
                engine="tesseract",
            ))
    raw = "\n".join(l.text for l in lines)
    return OcrResult(
        raw_text=raw, lines=lines, engine_used="tesseract",
        mean_confidence=conf, needs_manual_review=False,
    )


@pytest.fixture
def extractor():
    return FieldExtractor()


# ── MRP ───────────────────────────────────────────────────────────────────────

class TestMrpExtraction:

    @pytest.mark.parametrize("text,expected", [
        ("MRP Rs. 50", "50"),
        ("MRP: ₹50.00", "50.00"),
        ("M.R.P: Rs 120/-", "120"),
        ("Maximum Retail Price Rs. 299", "299"),
        ("MRP ₹ 15.50", "15.50"),
    ])
    def test_mrp_variants(self, extractor, text, expected):
        ocr = _make_ocr(text)
        fields = extractor.extract(ocr)
        assert fields.mrp.is_found
        assert expected in fields.mrp.value

    def test_no_mrp_not_found(self, extractor):
        ocr = _make_ocr("Britannia Industries Ltd\nNet Qty: 100g")
        fields = extractor.extract(ocr)
        assert not fields.mrp.is_found


# ── Net Quantity ──────────────────────────────────────────────────────────────

class TestNetQtyExtraction:

    @pytest.mark.parametrize("text,expected_unit", [
        ("Net Qty: 200g", "g"),
        ("Net Wt. 1 kg", "kg"),
        ("NET CONTENT 500 ml", "ml"),
        ("Net Vol: 1L", "L"),
        ("Qty: 12 nos", "nos"),
    ])
    def test_net_qty_variants(self, extractor, text, expected_unit):
        ocr = _make_ocr(text)
        fields = extractor.extract(ocr)
        assert fields.net_quantity.is_found
        assert expected_unit.lower() in fields.net_quantity.value.lower()


# ── Dates ─────────────────────────────────────────────────────────────────────

class TestDateExtraction:

    @pytest.mark.parametrize("text,field_attr", [
        ("Mfg: Jan 2025", "mfg_date"),
        ("Mfd. 01/2025", "mfg_date"),
        ("Date of Manufacture: December 2024", "mfg_date"),
        ("Best Before: Dec 2027", "best_before_date"),
        ("Exp: 12/2026", "best_before_date"),
        ("Use By: March 2026", "best_before_date"),
    ])
    def test_date_patterns(self, extractor, text, field_attr):
        ocr = _make_ocr(text)
        fields = extractor.extract(ocr)
        f = getattr(fields, field_attr)
        assert f.is_found, f"Expected {field_attr} to be found in: '{text}'"


# ── Consumer Care ─────────────────────────────────────────────────────────────

class TestConsumerCareExtraction:

    @pytest.mark.parametrize("text", [
        "1800-123-4567",
        "18001234567",
        "+91 9876543210",
        "9876543210",
    ])
    def test_phone_variants(self, extractor, text):
        ocr = _make_ocr(f"Consumer Care: {text}")
        fields = extractor.extract(ocr)
        assert fields.consumer_phone.is_found

    @pytest.mark.parametrize("text", [
        "care@britannia.co.in",
        "consumer@itcfoods.com",
        "helpdesk@brand.in",
    ])
    def test_email_variants(self, extractor, text):
        ocr = _make_ocr(f"Email: {text}")
        fields = extractor.extract(ocr)
        assert fields.consumer_email.is_found


# ── Full Label Integration ────────────────────────────────────────────────────

MARIE_GOLD_LABEL = """
BRITANNIA Marie Gold Biscuits
Net Wt. 200g
MRP Rs. 20 (Inclusive of all taxes)
Mfg: Oct 2024
Best Before: Oct 2026
Manufactured by: Britannia Industries Ltd, 5/1A, Hungerford St, Kolkata 700017
Consumer Care: 1800-103-1516  care@britannia.co.in
Batch No: MG-2024-100
"""

def test_full_marie_gold_label(extractor):
    ocr = _make_ocr(MARIE_GOLD_LABEL)
    fields = extractor.extract(ocr)

    assert fields.mrp.is_found, "MRP should be found"
    assert fields.net_quantity.is_found, "Net qty should be found"
    assert fields.mfg_date.is_found, "Mfg date should be found"
    assert fields.best_before_date.is_found, "Best before should be found"
    assert fields.manufacturer.is_found, "Manufacturer should be found"
    assert fields.consumer_phone.is_found, "Consumer phone should be found"
    assert fields.consumer_email.is_found, "Consumer email should be found"
    assert fields.batch_number.is_found, "Batch number should be found"

    # Verify extracted values make sense
    assert "20" in fields.mrp.value
    assert "200" in fields.net_quantity.value
