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

import logging
import re
from dataclasses import dataclass

from app.services.ocr_service import OcrLine, OcrResult

logger = logging.getLogger(__name__)

# ── Regex Pattern Library ─────────────────────────────────────────────────────

# MRP — "MRP Rs. 50", "M.R.P: ₹50.00", "MRP ₹ 50/-", "Rs 50", "₹50",
# "MRP: 40.00" (currency symbol missing), and mangled rupee symbols that
# OCR engines emit for ₹: "#", "~", "*", "R$" or a bare "R" glued to the
# digits ("MRP:R50.00" — seen on real DOMS/Faber-Castell labels).
# The lookaheads reject false positives like Legal Metrology licence
# numbers ("R-113/9" OCR'd as "Rs.1.13/9" — value followed by /digit).
# Captures must start with a digit — otherwise "Rs," (misread "Rs.")
# would capture the bare comma as a value.
_MRP_PATTERNS = [
    re.compile(
        r"(?:M\.?R\.?P\.?|Maximum\s+Retail\s+Price)\s*[:\-]?\s*"
        r"(?:Rs\.?|₹|INR|R\$|R(?=\d))?[^\w\s]?\s*"
        r"(\d[\d,]*+(?:\.\d{1,2})?+)(?!\s*/\s*\d)",
        re.IGNORECASE,
    ),
    re.compile(
        r"(?:Rs\.?|₹|INR|R\$)[.,*]?\s*(\d[\d,]*+(?:\.\d{1,2})?+)(?!\s*/\s*\d)",
        re.IGNORECASE,
    ),
]

# Net Quantity — "Net Qty: 500g", "Net Wt. 1 kg", "NET CONTENT 500 ml",
# "Qty: 12 nos", "NET QUANTITY: 1 Set" (multi-item packs declare sets)
_NET_QTY_PATTERNS = [
    re.compile(
        r"(?:(?:Net\s*)?(?:Qty|Quantity|Wt\.?|Weight|Content|Vol\.?|Volume))\s*[:\-]?\s*"
        r"([\d.,]+\s*(?:kg|g|gm|gms|gram|grams|mg|ml|mL|L|ltr|litre|litres|nos?|pcs?|pieces?|sets?))",
        re.IGNORECASE,
    ),
    # Bare "500g" — must not be preceded by a letter/digit/hyphen, else
    # addresses like "J-19.G.I.D.C" match as "19.G"
    re.compile(
        r"(?<![\w\-])([\d.,]+\s*(?:kg|g|gm|gms|ml|mL|L|ltr|nos?|pcs?|pieces?|sets?)\b)",
        re.IGNORECASE,
    ),
]

# Manufacture Date — "Mfg: Jan 2025", "Mfd. 01/2025", "Date of Mfg: 12-2024",
# "Mfg Date: 15 Aug 2026", "Date of Manufacture: 2026/08/15"
_MFG_DATE_PATTERNS = [
    re.compile(
        r"(?:Mfg\.?\s*Date|Mfd\.?\s*Date|Mfg\.?|Mfd\.?|Manufactured\s+(?:On|Date)?|Date\s+of\s+(?:Mfg|Mfd|Manufacture|Manufacturing|Packing|Pkg))\s*[:\-]?\s*"
        r"(\d{4}[/\-.]\d{1,2}[/\-.]\d{1,2}"
        r"|\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|"
        r"Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s*,?\s*\d{2,4}"
        r"|(?:\d{1,2}[/\-.])?(?:\d{1,2}[/\-.])?(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|"
        r"Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?|\d{1,2})[/\-. ]*\d{2,4})",
        re.IGNORECASE,
    ),
]

# Best Before / Expiry Date — "Best Before: Dec 2025", "Exp: 12/2025", "Use By: 31.12.2025",
# "Best Before Date: 15 Feb 2027", "Expiry: 2027/02/15", "Best Before: 6 months from packaging"
_BBD_PATTERNS = [
    re.compile(
        r"(?:Best\s+Before|BB\.?|BBD|Best\s+By|Exp(?:iry)?\.?|Use\s+By|Use\s+Before|Expiry\s+Date)"
        r"(?:\s+Date)?\s*[:\-]?\s*"
        r"(\d{4}[/\-.]\d{1,2}[/\-.]\d{1,2}"
        r"|\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|"
        r"Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s*,?\s*\d{2,4}"
        r"|(?:\d{1,2}[/\-.])?(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|"
        r"Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?|\d{1,2})[/\-. ]*\d{2,4})",
        re.IGNORECASE,
    ),
    # Relative durations — "Best Before: 6 months from packaging" (line search only)
    re.compile(
        r"(?:Best\s+Before|Use\s+By|Use\s+Before|Exp(?:iry)?\.?)(?:\s+Date)?\s*[:\-]?\s*"
        r"(\d{1,2}\s*(?:months?|weeks?|years?|days?)\s+from\s+[^,\n]{0,40})",
        re.IGNORECASE,
    ),
]

# Consumer Care Phone — Indian mobile (10-digit) or toll-free (1800-xxx)
_CONSUMER_PHONE_PATTERNS = [
    re.compile(r"(?:1800[-\s]?\d{3,4}[-\s]?\d{3,4})", re.IGNORECASE),        # Toll-free
    re.compile(r"\+91[-\s]?\d{2,4}[-\s]?\d{3,4}[-\s]?\d{4}"),                 # +91 STD landline
    re.compile(r"(?:\+91[-\s]?)?[6-9]\d{4}[-\s]?\d{5}"),                                   # Indian mobile
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

# Batch / Lot number — the captured code must contain at least one digit
# (rejects false hits like the bare word "No" from "Lot No.")
_BATCH_PATTERNS = [
    re.compile(
        r"(?:Batch\s*(?:No\.?|Number|#)?|Lot\s*(?:No\.?|Number|#)?|B\.?\s*No\.?)\s*[:\-]?\s*"
        r"([A-Z0-9\-/]*\d[A-Z0-9\-/]*)",
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
    value: str | None               # Extracted value string; None if not found
    confidence: float                  # 0.0–1.0; inherited from OCR line or 0.5 for text-search
    raw_snippet: str | None = None  # The matched text snippet for debugging
    source_line_idx: int | None = None  # Index in OcrResult.lines

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
# ── Misaligned key/value reassembly ───────────────────────────────────────────
# Labels sometimes print keys and values in separate, non-aligned blocks:
#   "MRP  Mfg Date  Best Before"     ← key row
#   "40.00  05/2026  10/2026"        ← value row (printed later / offset)
# or stack them vertically:
#   "MRP"
#   "₹ 40.00"
# OCR reads these as unassociated lines, so every extractor misses. The
# helpers below glue key lines to their value lines — geometrically via
# bounding boxes when available (ML Kit / RapidOCR), by adjacency otherwise.

_KEY_LINE_RE = re.compile(
    r"^(?:m\.?\s*r\.?\s*p\.?|maximum\s+retail\s+price|u\.?\s*s\.?\s*p\.?|"
    r"unit\s+sale\s+price|net\s+(?:qty|quantity|wt\.?|weight|content|vol\.?|volume)|"
    r"(?:mfg|mfd)\.?\s*date?|(?:mfg|mfd)|date\s+of\s+(?:mfg|manufactur\w+)|"
    r"month\s+of\s+(?:mfg|manufactur\w+)|best\s+before(?:\s+date)?|use\s+by|"
    r"exp(?:iry)?(?:\s+date)?|batch(?:\s*(?:no\.?|number))?|lot(?:\s*(?:no\.?|number))?|"
    r"consumer\s+care|country\s+of\s+origin|origin|generic\s+name|packed\s+on"
    r")\s*[:.\-–]*$",
    re.IGNORECASE,
)


def _is_key_only(text: str) -> bool:
    """A line that holds ONLY a declaration key (no value attached)."""
    t = text.strip()
    return bool(_KEY_LINE_RE.match(t)) and not re.search(r"\d", t)


def _has_value(text: str) -> bool:
    return bool(re.search(r"\d", text))


def _merge_line(a: OcrLine, b: OcrLine) -> OcrLine:
    """Glue two lines into one, spanning both bounding boxes."""
    ax, ay, aw, ah = a.bbox
    bx, by, bw, bh = b.bbox
    x0, y0 = min(ax, bx), min(ay, by)
    x1, y1 = max(ax + aw, bx + bw), max(ay + ah, by + bh)
    return OcrLine(
        text=f"{a.text.strip()} {b.text.strip()}",
        confidence=min(a.confidence, b.confidence),
        bbox=(x0, y0, x1 - x0, y1 - y0),
        engine=a.engine,
    )


def _group_rows(lines: list[OcrLine]) -> list[list[OcrLine]]:
    """Group lines into visual rows by vertical-center proximity."""
    rows: list[list[OcrLine]] = []
    for ln in sorted(lines, key=lambda ln: (ln.bbox[1] + ln.bbox[3] / 2, ln.bbox[0])):
        cy = ln.bbox[1] + ln.bbox[3] / 2
        h = max(ln.bbox[3], 1)
        if rows:
            row_cy = sum(r.bbox[1] + r.bbox[3] / 2 for r in rows[-1]) / len(rows[-1])
            if abs(cy - row_cy) <= 0.6 * h:
                rows[-1].append(ln)
                continue
        rows.append([ln])
    return [sorted(r, key=lambda ln: ln.bbox[0]) for r in rows]


def _has_geometry(lines: list[OcrLine]) -> bool:
    return any(ln.bbox[2] > 0 for ln in lines)


def reassemble_misaligned(lines: list[OcrLine]) -> list[OcrLine]:
    """
    Glue key-only lines to their value lines so per-line extractors work.
    Handles vertical stacking and columnar (row-of-keys + row-of-values)
    layouts. Lines are returned in original order when nothing matches.
    """
    if not lines:
        return lines

    if not _has_geometry(lines):
        # Text-only: join a key-only line with the value line that follows.
        out: list[OcrLine] = []
        i = 0
        while i < len(lines):
            cur, nxt = lines[i], lines[i + 1] if i + 1 < len(lines) else None
            if (nxt is not None and _is_key_only(cur.text)
                    and _has_value(nxt.text) and not _is_key_only(nxt.text)):
                out.append(_merge_line(cur, nxt))
                i += 2
            else:
                out.append(cur)
                i += 1
        return out

    # Geometric: pair a row made entirely of keys with the value row below it,
    # matching each key to the nearest value by horizontal position.
    rows = _group_rows(lines)
    out: list[OcrLine] = []
    consumed: set[int] = set()
    for ri, row in enumerate(rows):
        if ri in consumed:
            continue
        next_row = rows[ri + 1] if ri + 1 < len(rows) else None
        keys = [ln for ln in row if _is_key_only(ln.text)]
        if (next_row is not None and keys and len(keys) == len(row)
                and all(not _has_value(ln.text) for ln in row)
                and not any(_is_key_only(ln.text) for ln in next_row)):
            values = [ln for ln in next_row if _has_value(ln.text)]
            used: set[int] = set()
            for k in keys:
                kcx = k.bbox[0] + k.bbox[2] / 2
                best_j, best_d = None, None
                for j, v in enumerate(values):
                    if j in used:
                        continue
                    d = abs((v.bbox[0] + v.bbox[2] / 2) - kcx)
                    if best_d is None or d < best_d:
                        best_j, best_d = j, d
                if best_j is not None:
                    used.add(best_j)
                    out.append(_merge_line(k, values[best_j]))
                else:
                    out.append(k)
            # pass through any next-row content that was not consumed
            out.extend(v for j, v in enumerate(values) if j not in used)
            out.extend(ln for ln in next_row if not _has_value(ln.text))
            consumed.add(ri + 1)
            continue
        out.extend(row)
    return out


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
        lines = reassemble_misaligned(ocr_result.lines)
        if len(lines) != len(ocr_result.lines):
            # Reassembly glued some lines — rebuild the raw text so the
            # full-text fallback pass sees the same associations.
            text = "\n".join(ln.text for ln in lines)

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
