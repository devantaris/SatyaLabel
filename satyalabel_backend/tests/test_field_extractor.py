"""
Tests for the Field Extractor — regex patterns against realistic label text.
"""
from __future__ import annotations

import pytest

from app.services.field_extractor import FieldExtractor, extract_fields
from app.services.ocr_service import OcrLine, OcrResult


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
    raw = "\n".join(ln.text for ln in lines)
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
        ("Mfg Date: 15 Aug 2026", "mfg_date"),
        ("Date of Manufacture: 2026/08/15", "mfg_date"),
        ("Best Before: Dec 2027", "best_before_date"),
        ("Exp: 12/2026", "best_before_date"),
        ("Use By: March 2026", "best_before_date"),
        ("Best Before Date: 15 Feb 2027", "best_before_date"),
        ("Expiry: 2027/02/15", "best_before_date"),
        ("Best Before: 6 months from packaging", "best_before_date"),
    ])
    def test_date_patterns(self, extractor, text, field_attr):
        ocr = _make_ocr(text)
        fields = extractor.extract(ocr)
        f = getattr(fields, field_attr)
        assert f.is_found, f"Expected {field_attr} to be found in: '{text}'"

    @pytest.mark.parametrize("text,field_attr,expected", [
        ("Date of Manufacture: 2026/08/15", "mfg_date", "2026/08/15"),
        ("Mfg Date: 15 Aug 2026", "mfg_date", "15 Aug 2026"),
        ("Expiry: 2027/02/15", "best_before_date", "2027/02/15"),
        ("Best Before Date: 15 Feb 2027", "best_before_date", "15 Feb 2027"),
        ("Best Before: 6 months from packaging", "best_before_date", "6 months from packaging"),
    ])
    def test_date_values(self, extractor, text, field_attr, expected):
        ocr = _make_ocr(text)
        fields = extractor.extract(ocr)
        f = getattr(fields, field_attr)
        assert f.is_found
        assert f.value == expected


# ── Consumer Care ─────────────────────────────────────────────────────────────

class TestConsumerCareExtraction:

    @pytest.mark.parametrize("text", [
        "1800-123-4567",
        "18001234567",
        "+91 9876543210",
        "9876543210",
        "+91 98765 43210",
        "98765 43210",
        "+91 11 4000 5000",
        "011-40005000",
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


# ── False-positive guards ─────────────────────────────────────────────────────

class TestFalsePositiveGuards:
    """LM licence numbers and bare header words must not become field values."""

    def _ocr(self, text: str) -> OcrResult:
        lines = [OcrLine(t, 0.85, (0, i * 20, 100, 15), "rapidocr") for i, t in enumerate(text.split("\n"))]
        return OcrResult(text, lines, "rapidocr", 0.85, False)

    def test_mrp_ignores_licence_number(self):
        # "R-113/9" licence OCR'd as "Rs.1.13/9" must NOT yield MRP=1.13
        fields = FieldExtractor().extract(self._ocr("MRP: (incl. of all taxes)\n395.00 Rs.1.13/9"))
        assert not fields.mrp.is_found

    def test_mrp_still_matches_slash_dash_suffix(self):
        fields = FieldExtractor().extract(self._ocr("MRP Rs. 50/-"))
        assert fields.mrp.is_found and fields.mrp.value == "50"

    def test_batch_requires_digit(self):
        # "Lot No." with no code must not capture the bare word "No"
        fields = FieldExtractor().extract(self._ocr("Lot No.\nBest Before: 6 months"))
        assert not fields.batch_number.is_found

    def test_batch_with_code_still_matches(self):
        fields = FieldExtractor().extract(self._ocr("Batch No: TF20260815A"))
        assert fields.batch_number.is_found and fields.batch_number.value == "TF20260815A"

    def test_two_column_row_merges(self):
        from app.services.ocr_service import OcrService
        # Two-column label: name on the left, value on the right (same row)
        lines = [
            OcrLine("Net Weight:", 0.85, (100, 737, 90, 35), "rapidocr"),
            OcrLine("350g", 0.80, (533, 740, 50, 32), "rapidocr"),
            OcrLine("Second row", 0.80, (100, 830, 120, 35), "rapidocr"),
        ]
        merged = OcrService._merge_same_row(lines)
        assert len(merged) == 2
        assert merged[0].text == "Net Weight: 350g"
        assert merged[1].text == "Second row"


class TestMisalignedKeyValues:
    """Labels that print keys and values in separate rows/blocks."""

    def _result(self, rows):
        from app.services.ocr_service import OcrResult
        return OcrResult.from_client_lines(rows)

    def test_columnar_key_row_then_value_row(self):
        r = self._result([
            {"text": "MRP", "x": 20, "y": 100, "w": 80, "h": 24},
            {"text": "Mfg Date", "x": 200, "y": 102, "w": 120, "h": 24},
            {"text": "Best Before", "x": 380, "y": 100, "w": 140, "h": 24},
            {"text": "Rs 40.00", "x": 15, "y": 150, "w": 100, "h": 24},
            {"text": "05/2026", "x": 210, "y": 152, "w": 90, "h": 24},
            {"text": "10/2027", "x": 390, "y": 150, "w": 90, "h": 24},
        ])
        f = extract_fields(r)
        assert f.mrp.value == "40.00"
        assert f.mfg_date.value == "05/2026"
        assert f.best_before_date.value == "10/2027"

    def test_columnar_values_must_not_cross_pair(self):
        # Values offset from keys — nearest-x matching must pair correctly
        r = self._result([
            {"text": "MRP", "x": 20, "y": 100, "w": 80, "h": 24},
            {"text": "Net Qty", "x": 300, "y": 100, "w": 120, "h": 24},
            {"text": "Rs 99.00", "x": 30, "y": 160, "w": 110, "h": 24},
            {"text": "500 g", "x": 310, "y": 158, "w": 80, "h": 24},
        ])
        f = extract_fields(r)
        assert f.mrp.value == "99.00"
        assert f.net_quantity.value == "500 g"

    def test_vertical_key_then_value(self):
        from app.services.ocr_service import OcrResult
        r = OcrResult.from_client_text("TATA Salt\nMRP\n₹ 30.00\nNet Qty: 1 kg")
        f = extract_fields(r)
        assert f.mrp.value == "30.00"
        assert f.net_quantity.value == "1 kg"

    def test_normal_inline_label_untouched(self):
        from app.services.ocr_service import OcrResult
        r = OcrResult.from_client_text(
            "MRP Rs. 30.00\nNet Qty: 1 kg\nMfg: 12 Jan 2026\nBest Before: 12 Jan 2027"
        )
        f = extract_fields(r)
        assert f.mrp.value == "30.00"
        assert f.mfg_date.value == "12 Jan 2026"
