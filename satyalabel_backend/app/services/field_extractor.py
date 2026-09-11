"""
Field Extractor for SatyaLabel
================================
Parses raw OCR text (and per-line data) into structured fields
corresponding to the 9 mandatory declarations under:
  Legal Metrology (Packaged Commodities) Rules, 2011

Each extractor function:
  - Takes the full OCR text (and optionally individual lines)
  - Applies regex patterns tuned for Indian product labels
  - Returns an ExtractedField with value, confidence, and the matched snippet

Design principles:
  1. EXPLAINABLE — every match is traceable to a specific regex pattern
  2. ROBUST — multiple pattern variants per field to handle label inconsistencies
  3. CONSERVATIVE — when uncertain, return low confidence rather than wrong data
  4. EXTENSIBLE — add new patterns as edge cases are discovered in the wild

Field priority for confidence weighting:
  - Use the OCR line's confidence score when a field is found on a specific line
  - Fall back to 0.5 (medium) when only the raw text is searched
"""
from __future__ import annotations

import re
import logging
from dataclasses import dataclass, field as dc_field
from datetime import datetime
from typing import List, Optional

from app.services.ocr_service import OcrResult, OcrLine

logger = logging.getLogger(__name__)

# ── Regex Pattern Library ─────────────────────────────────────────────────────

# MRP — "MRP Rs. 50", "M.R.P: ₹50.00", "MRP ₹ 50/-", "Rs 50", "₹50"
_MRP_PATTERNS = [
    re.compile(
        r"(?:M\.?R\.?P\.?|Maximum\s+Retail\s+Price)\s*[:\-]?\s*"
        r"(?:Rs\.?|₹|INR)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:/-|/)?",
        re.IGNORECASE,
    ),
    re.compile(
        r"(?:Rs\.?|₹|INR)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:/-|/)?",
        re.IGNORECASE,
    ),
]

# Net Quantity — "Net Qty: 500g", "Net Wt. 1 kg", "NET CONTENT 500 ml", "Qty: 12 nos"
_NET_QTY_PATTERNS = [
    re.compile(
        r"(?:(?:Net\s*)?(?:Qty|Quantity|Wt\.?|Weight|Content|Vol\.?|Volume))\s*[:\-]?\s*"
        r"([\d.,]+\s*(?:kg|g|gm|gms|gram|grams|mg|ml|mL|L|ltr|litre|litres|nos?|pcs?|pieces?))",
        re.IGNORECASE,
    ),
    re.compile(
        r"([\d.,]+\s*(?:kg|g|gm|gms|ml|mL|L|ltr|nos?|pcs?|pieces?)\b)",
        re.IGNORECASE,
    ),
]

# Manufacture Date — "Mfg: Jan 2025", "Mfd. 01/2025", "Date of Mfg: 12-2024"
_MFG_DATE_PATTERNS = [
    re.compile(
        r"(?:Mfg\.?|Mfd\.?|Manufactured\s+(?:On|Date)?|Date\s+of\s+(?:Mfg|Mfd|Manufacture|Manufacturing|Packing|Pkg))\s*[:\-]?\s*"
        r"((?:\d{1,2}[/\-.])?(?:\d{1,2}[/\-.])?(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|"
        r"Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?|\d{1,2})[/\-. ]*\d{2,4})",
        re.IGNORECASE,
    ),
]

# Best Before / Expiry Date — "Best Before: Dec 2025", "Exp: 12/2025", "Use By: 31.12.2025"
_BBD_PATTERNS = [
    re.compile(
        r"(?:Best\s+Before|BB\.?|BBD|Best\s+By|Exp(?:iry)?\.?|Use\s+By|Use\s+Before|Expiry\s+Date)\s*[:\-]?\s*"
        r"((?:\d{1,2}[/\-.])?(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|"
        r"Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?|\d{1,2})[/\-. ]*\d{2,4})",
        re.IGNORECASE,
    ),
]

# Consumer Care Phone — Indian mobile (10-digit) or toll-free (1800-xxx)
_CONSUMER_PHONE_PATTERNS = [
    re.compile(r"(?:1800[-\s]?\d{3,4}[-\s]?\d{3,4})", re.IGNORECASE),        # Toll-free
    re.compile(r"(?:\+91[-\s]?)?[6-9]\d{9}"),                                   # Indian mobile
    re.compile(r"(?:0\d{2,4}[-\s]?\d{6,8})"),                                   # STD landline
]

# Consumer Care Email
_CONSUMER_EMAIL_PATTERN = re.compile(
    r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}", re.IGNORECASE
)

# Manufacturer / Packer / Importer name+address
# Strategy: look for the section header, then grab the following lines
_MANUFACTURER_HEADER_PATTERN = re.compile(
    r"(?:Marketed\s+by|Manufactured\s+by|Mfr\.?\s*by|Packed\s+by|Imported\s+by|"
    r"Manufacturer|Packer|Importer)\s*[:\-]?\s*(.{5,120})",
    re.IGNORECASE,
)

# Batch / Lot number
_BATCH_PATTERNS = [
    re.compile(
        r"(?:Batch\s*(?:No\.?|Number|#)?|Lot\s*(?:No\.?|Number|#)?|B\.?\s*No\.?)\s*[:\-]?\s*([A-Z0-9\-/]+)",
        re.IGNORECASE,
    ),
]

# Country of Origin (for imported goods)
_ORIGIN_PATTERNS = [
    re.compile(
        r"(?:Country\s+of\s+Origin|Made\s+in|Imported\s+from)\s*[:\-]?\s*([A-Za-z\s]+?)(?:\.|,|\n|$)",
        re.IGNORECASE,
    ),
]

# Generic / Common Name
_GENERIC_NAME_PATTERNS = [
    re.compile(
        r"(?:Generic\s+Name|Common\s+Name|Commodity)\s*[:\-]?\s*(.{3,60}?)(?:\n|$)",
        re.IGNORECASE,
    ),
]


# ── Data Classes ──────────────────────────────────────────────────────────────
@dataclass
class ExtractedField:
    """A single extracted field value from the OCR text."""
    field_name: str
    value: Optional[str]               # Extracted value string; None if not found
    confidence: float                  # 0.0–1.0; inherited from OCR line or 0.5 for text-search
    raw_snippet: Optional[str] = None  # The matched text snippet for debugging
    source_line_idx: Optional[int] = None  # Index in OcrResult.lines

    @property
    def is_found(self) -> bool:
        return self.value is not None and self.value.strip() != ""


@dataclass
class ExtractedFields:
    """All mandatory fields extracted from a single label scan."""
    mrp: ExtractedField
    net_quantity: ExtractedField
    mfg_date: ExtractedField
    best_before_date: ExtractedField
    manufacturer: ExtractedField
    consumer_phone: ExtractedField
    consumer_email: ExtractedField
    batch_number: ExtractedField
    country_of_origin: ExtractedField
    generic_name: ExtractedField

    def as_dict(self) -> dict:
        return {
            f.field_name: {
                "value": f.value,
                "confidence": f.confidence,
                "found": f.is_found,
            }
            for f in self._all_fields()
        }

    def _all_fields(self) -> list[ExtractedField]:
        return [
            self.mrp, self.net_quantity, self.mfg_date, self.best_before_date,
            self.manufacturer, self.consumer_phone, self.consumer_email,
            self.batch_number, self.country_of_origin, self.generic_name,
        ]

    @property
    def overall_extraction_confidence(self) -> float:
        """Mean confidence across all found fields."""
        found = [f.confidence for f in self._all_fields() if f.is_found]
        return sum(found) / len(found) if found else 0.0


# ── Field Extractor ───────────────────────────────────────────────────────────
class FieldExtractor:
    """
    Extracts mandatory label fields from OCR output.

    Two-pass strategy:
      Pass 1: Search per OCR line (preserves line-level confidence scores)
      Pass 2: Fall back to full raw text search if not found in Pass 1
    """

    def extract(self, ocr_result: OcrResult) -> ExtractedFields:
        """
        Extract all mandatory fields from the OCR result.

        Args:
            ocr_result: Output from OcrService.run()

        Returns:
            ExtractedFields dataclass with all 10 field slots populated.
        """
        text = ocr_result.raw_text
        lines = ocr_result.lines

        return ExtractedFields(
            mrp=self._extract_mrp(text, lines),
            net_quantity=self._extract_net_qty(text, lines),
            mfg_date=self._extract_mfg_date(text, lines),
            best_before_date=self._extract_bbd(text, lines),
            manufacturer=self._extract_manufacturer(text, lines),
            consumer_phone=self._extract_consumer_phone(text, lines),
            consumer_email=self._extract_consumer_email(text, lines),
            batch_number=self._extract_batch(text, lines),
            country_of_origin=self._extract_country_of_origin(text, lines),
            generic_name=self._extract_generic_name(text, lines),
        )

    # ── Individual field extractors ───────────────────────────────────────────

    def _extract_mrp(self, text: str, lines: list[OcrLine]) -> ExtractedField:
        for pattern in _MRP_PATTERNS:
            result = self._search_lines(lines, pattern, "mrp")
            if result.is_found:
                return result
        return self._search_text(text, _MRP_PATTERNS[0], "mrp")

    def _extract_net_qty(self, text: str, lines: list[OcrLine]) -> ExtractedField:
        for pattern in _NET_QTY_PATTERNS:
            result = self._search_lines(lines, pattern, "net_quantity")
            if result.is_found:
                return result
        return self._search_text(text, _NET_QTY_PATTERNS[0], "net_quantity")

    def _extract_mfg_date(self, text: str, lines: list[OcrLine]) -> ExtractedField:
        for pattern in _MFG_DATE_PATTERNS:
            result = self._search_lines(lines, pattern, "mfg_date")
            if result.is_found:
                return result
        return self._search_text(text, _MFG_DATE_PATTERNS[0], "mfg_date")

    def _extract_bbd(self, text: str, lines: list[OcrLine]) -> ExtractedField:
        for pattern in _BBD_PATTERNS:
            result = self._search_lines(lines, pattern, "best_before_date")
            if result.is_found:
                return result
        return self._search_text(text, _BBD_PATTERNS[0], "best_before_date")

    def _extract_manufacturer(self, text: str, lines: list[OcrLine]) -> ExtractedField:
        result = self._search_lines(lines, _MANUFACTURER_HEADER_PATTERN, "manufacturer")
        if result.is_found:
            return result
        return self._search_text(text, _MANUFACTURER_HEADER_PATTERN, "manufacturer")

    def _extract_consumer_phone(self, text: str, lines: list[OcrLine]) -> ExtractedField:
        for pattern in _CONSUMER_PHONE_PATTERNS:
            result = self._search_lines(lines, pattern, "consumer_phone")
            if result.is_found:
                return result
            result = self._search_text(text, pattern, "consumer_phone")
            if result.is_found:
                return result
        return ExtractedField("consumer_phone", None, 0.0)

    def _extract_consumer_email(self, text: str, lines: list[OcrLine]) -> ExtractedField:
        result = self._search_lines(lines, _CONSUMER_EMAIL_PATTERN, "consumer_email")
        if result.is_found:
            return result
        return self._search_text(text, _CONSUMER_EMAIL_PATTERN, "consumer_email")

    def _extract_batch(self, text: str, lines: list[OcrLine]) -> ExtractedField:
        for pattern in _BATCH_PATTERNS:
            result = self._search_lines(lines, pattern, "batch_number")
            if result.is_found:
                return result
        return self._search_text(text, _BATCH_PATTERNS[0], "batch_number")

    def _extract_country_of_origin(self, text: str, lines: list[OcrLine]) -> ExtractedField:
        for pattern in _ORIGIN_PATTERNS:
            result = self._search_lines(lines, pattern, "country_of_origin")
            if result.is_found:
                return result
        return self._search_text(text, _ORIGIN_PATTERNS[0], "country_of_origin")

    def _extract_generic_name(self, text: str, lines: list[OcrLine]) -> ExtractedField:
        for pattern in _GENERIC_NAME_PATTERNS:
            result = self._search_lines(lines, pattern, "generic_name")
            if result.is_found:
                return result
        return self._search_text(text, _GENERIC_NAME_PATTERNS[0], "generic_name")

    # ── Search helpers ────────────────────────────────────────────────────────

    def _search_lines(
        self, lines: list[OcrLine], pattern: re.Pattern, field_name: str
    ) -> ExtractedField:
        """
        Search each OCR line individually, preserving per-line confidence.
        Returns the first match found.
        """
        for idx, line in enumerate(lines):
            m = pattern.search(line.text)
            if m:
                # Use group(1) if available (captured value), else group(0) (full match)
                value = m.group(1).strip() if m.lastindex and m.lastindex >= 1 else m.group(0).strip()
                return ExtractedField(
                    field_name=field_name,
                    value=value,
                    confidence=line.confidence,
                    raw_snippet=m.group(0),
                    source_line_idx=idx,
                )
        return ExtractedField(field_name, None, 0.0)

    def _search_text(
        self, text: str, pattern: re.Pattern, field_name: str
    ) -> ExtractedField:
        """
        Fallback: search full concatenated OCR text.
        Confidence defaults to 0.5 (medium) since we lost line-level info.
        """
        m = pattern.search(text)
        if m:
            value = m.group(1).strip() if m.lastindex and m.lastindex >= 1 else m.group(0).strip()
            return ExtractedField(
                field_name=field_name,
                value=value,
                confidence=0.5,
                raw_snippet=m.group(0),
            )
        return ExtractedField(field_name, None, 0.0)


# ── Singleton ─────────────────────────────────────────────────────────────────
_field_extractor = FieldExtractor()


def extract_fields(ocr_result: OcrResult) -> ExtractedFields:
    """Module-level convenience function."""
    return _field_extractor.extract(ocr_result)
