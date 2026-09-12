"""
Rule Engine for SatyaLabel
============================
Deterministic compliance checker against:
  Legal Metrology (Packaged Commodities) Rules, 2011

Each rule function:
  - Takes the ExtractedFields for a scanned label
  - Applies the specific legal requirement
  - Returns a RuleResult with pass/fail and an explainable message

Design principle: EXPLAINABLE over MAGICAL.
  Instead of "AI says non-compliant", the engine says:
  "VIOLATION — MRP: MRP declaration not found on label.
   Required per Rule 6(1)(f) of LM(PC) Rules, 2011."

The ComplianceReport includes:
  - Overall verdict: COMPLIANT | NON_COMPLIANT | NEEDS_VERIFICATION
  - List of violations (each with rule reference)
  - List of warnings (low-confidence fields that may be wrong)
  - Raw extracted fields for the PDF report
  - needs_manual_review flag (OCR was too uncertain on critical fields)
"""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from dataclasses import field as dc_field
from datetime import UTC, datetime
from enum import Enum

from dateutil import parser as dateutil_parser

from app.services.field_extractor import ExtractedField, ExtractedFields

logger = logging.getLogger(__name__)

# ── Enums ─────────────────────────────────────────────────────────────────────
class Verdict(str, Enum):
    COMPLIANT = "COMPLIANT"
    NON_COMPLIANT = "NON_COMPLIANT"
    NEEDS_VERIFICATION = "NEEDS_VERIFICATION"  # OCR confidence too low for certainty


class Severity(str, Enum):
    CRITICAL = "CRITICAL"    # Clear violation — field missing or clearly wrong
    WARNING = "WARNING"      # Possible issue, but low OCR confidence
    INFO = "INFO"            # Informational (e.g. field not required for this product type)


# ── Data Classes ──────────────────────────────────────────────────────────────
@dataclass
class Violation:
    """A single rule violation or warning."""
    field_name: str
    severity: Severity
    message: str                    # Human-readable violation description
    rule_reference: str             # e.g. "Rule 6(1)(f), LM(PC) Rules 2011"
    extracted_value: str | None  # What we found (or None)
    confidence: float               # OCR confidence for this field


@dataclass
class ComplianceReport:
    """
    Final compliance report for a scanned label.

    Fields:
        verdict             : COMPLIANT | NON_COMPLIANT | NEEDS_VERIFICATION
        violations          : List of rule violations (CRITICAL/WARNING)
        extracted_fields    : The raw field extraction result (for PDF report)
        needs_manual_review : True if OCR confidence was too low on critical fields
        checked_at          : ISO timestamp
    """
    verdict: Verdict
    violations: list[Violation]
    extracted_fields: ExtractedFields
    needs_manual_review: bool
    checked_at: str = dc_field(default_factory=lambda: datetime.now(UTC).isoformat())

    @property
    def critical_violations(self) -> list[Violation]:
        return [v for v in self.violations if v.severity == Severity.CRITICAL]

    @property
    def warnings(self) -> list[Violation]:
        return [v for v in self.violations if v.severity == Severity.WARNING]

    @property
    def violation_count(self) -> int:
        return len(self.critical_violations)

    def summary_text(self) -> str:
        """One-line summary for display in the mobile app."""
        if self.verdict == Verdict.COMPLIANT:
            return "✅ COMPLIANT — All mandatory declarations detected"
        elif self.verdict == Verdict.NEEDS_VERIFICATION:
            return f"⚠️ NEEDS VERIFICATION — {len(self.warnings)} field(s) unclear, manual check required"
        else:
            msgs = "; ".join(v.message for v in self.critical_violations[:3])
            return f"❌ NON-COMPLIANT — {msgs}"

    def as_dict(self) -> dict:
        return {
            "verdict": self.verdict.value,
            "critical_violations": [
                {
                    "field": v.field_name,
                    "severity": v.severity.value,
                    "message": v.message,
                    "rule": v.rule_reference,
                    "found_value": v.extracted_value,
                    "confidence": v.confidence,
                }
                for v in self.critical_violations
            ],
            "warnings": [
                {
                    "field": v.field_name,
                    "message": v.message,
                    "found_value": v.extracted_value,
                    "confidence": v.confidence,
                }
                for v in self.warnings
            ],
            "needs_manual_review": self.needs_manual_review,
            "checked_at": self.checked_at,
            "extracted_fields": self.extracted_fields.as_dict(),
        }


# ── Rule Helpers ──────────────────────────────────────────────────────────────
LOW_CONF = 0.45  # Below this → downgrade violation to WARNING

def _field_violation(
    extracted: ExtractedField,
    critical_msg: str,
    rule_ref: str,
    missing_msg: str | None = None,
) -> Violation | None:
    """
    Helper: create a Violation for a missing or low-confidence field.
    Returns None if the field is found with adequate confidence.
    """
    if not extracted.is_found:
        return Violation(
            field_name=extracted.field_name,
            severity=Severity.CRITICAL,
            message=missing_msg or critical_msg,
            rule_reference=rule_ref,
            extracted_value=None,
            confidence=0.0,
        )
    if extracted.confidence < LOW_CONF:
        return Violation(
            field_name=extracted.field_name,
            severity=Severity.WARNING,
            message=f"Low OCR confidence ({extracted.confidence:.0%}) on '{extracted.field_name}' — "
                    f"detected value: '{extracted.value}'. Manual verification recommended.",
            rule_reference=rule_ref,
            extracted_value=extracted.value,
            confidence=extracted.confidence,
        )
    return None  # No violation


# ── Rule Engine ───────────────────────────────────────────────────────────────
class RuleEngine:
    """
    Runs all mandatory compliance checks against extracted label fields.

    Each check_* method returns 0, 1, or 2 Violations.
    The run() method aggregates all violations and issues the final verdict.
    """

    def run(self, fields: ExtractedFields, ocr_needs_review: bool = False) -> ComplianceReport:
        """
        Run all compliance rules against extracted fields.

        Args:
            fields: ExtractedFields from the FieldExtractor.
            ocr_needs_review: Whether OCR flagged this scan for manual review.

        Returns:
            ComplianceReport with verdict, violations, and warnings.
        """
        violations: list[Violation] = []

        violations += self.check_mrp(fields.mrp)
        violations += self.check_net_quantity(fields.net_quantity)
        violations += self.check_mfg_date(fields.mfg_date)
        violations += self.check_best_before(fields.best_before_date)
        violations += self.check_date_consistency(fields.mfg_date, fields.best_before_date)
        violations += self.check_manufacturer(fields.manufacturer)
        violations += self.check_consumer_care(fields.consumer_phone, fields.consumer_email)
        violations += self.check_batch_number(fields.batch_number)

        # Determine verdict
        critical_count = sum(1 for v in violations if v.severity == Severity.CRITICAL)
        warning_count = sum(1 for v in violations if v.severity == Severity.WARNING)

        if critical_count > 0:
            verdict = Verdict.NON_COMPLIANT
        elif warning_count > 0 or ocr_needs_review:
            verdict = Verdict.NEEDS_VERIFICATION
        else:
            verdict = Verdict.COMPLIANT

        return ComplianceReport(
            verdict=verdict,
            violations=violations,
            extracted_fields=fields,
            needs_manual_review=ocr_needs_review or warning_count > 0,
        )

    # ── Individual Rule Checkers ──────────────────────────────────────────────

    def check_mrp(self, mrp: ExtractedField) -> list[Violation]:
        """Rule 6(1)(f): MRP must be declared, inclusive of all taxes."""
        violations = []
        v = _field_violation(
            mrp,
            critical_msg="MRP not declared on label",
            rule_ref="Rule 6(1)(f), LM(PC) Rules 2011",
            missing_msg="MISSING: Maximum Retail Price (MRP) not found on label. "
                        "Required: 'MRP Rs. XX (inclusive of all taxes)'",
        )
        if v:
            violations.append(v)
        elif mrp.is_found:
            # Cross-check: MRP value must be a positive number
            cleaned = mrp.value.replace(",", "").strip()
            try:
                is_negative = cleaned.startswith("-")
                digits_only = re.sub(r"[^\d.]", "", cleaned)
                if not digits_only:
                    raise ValueError("No digits found")
                val = -float(digits_only) if is_negative else float(digits_only)
                if val <= 0:
                    violations.append(Violation(
                        field_name="mrp",
                        severity=Severity.CRITICAL,
                        message=f"MRP value '{mrp.value}' is zero or negative — invalid declaration",
                        rule_reference="Rule 6(1)(f), LM(PC) Rules 2011",
                        extracted_value=mrp.value,
                        confidence=mrp.confidence,
                    ))
            except (ValueError, TypeError):
                violations.append(Violation(
                    field_name="mrp",
                    severity=Severity.WARNING,
                    message=f"MRP value '{mrp.value}' could not be parsed as a number — verify manually",
                    rule_reference="Rule 6(1)(f), LM(PC) Rules 2011",
                    extracted_value=mrp.value,
                    confidence=mrp.confidence,
                ))
        return violations

    def check_net_quantity(self, net_qty: ExtractedField) -> list[Violation]:
        """Rule 6(1)(b): Net quantity must be declared in standard units."""
        violations = []
        v = _field_violation(
            net_qty,
            critical_msg="Net quantity not declared on label",
            rule_ref="Rule 6(1)(b), LM(PC) Rules 2011",
            missing_msg="MISSING: Net Quantity not found on label. "
                        "Required: weight (g/kg), volume (ml/L), or count (nos/pcs)",
        )
        if v:
            violations.append(v)
        return violations

    def check_mfg_date(self, mfg_date: ExtractedField) -> list[Violation]:
        """Rule 6(1)(e): Month and year of manufacture/packing must be declared."""
        v = _field_violation(
            mfg_date,
            critical_msg="Date of manufacture/packing not declared",
            rule_ref="Rule 6(1)(e), LM(PC) Rules 2011",
            missing_msg="MISSING: Date of Manufacture/Packing not found on label.",
        )
        return [v] if v else []

    def check_best_before(self, bbd: ExtractedField) -> list[Violation]:
        """
        Rule 6(1)(g): Best before date required for perishable goods.
        If not found, issue a warning (it may be non-perishable).
        """
        if not bbd.is_found:
            return [Violation(
                field_name="best_before_date",
                severity=Severity.WARNING,
                message="Best Before / Expiry date not detected. "
                        "Required for perishable goods per Rule 6(1)(g). "
                        "If product is non-perishable, this may be acceptable.",
                rule_reference="Rule 6(1)(g), LM(PC) Rules 2011",
                extracted_value=None,
                confidence=0.0,
            )]
        if bbd.confidence < LOW_CONF:
            return [Violation(
                field_name="best_before_date",
                severity=Severity.WARNING,
                message=f"Best Before date detected with low confidence ({bbd.confidence:.0%}): "
                        f"'{bbd.value}'. Please verify manually.",
                rule_reference="Rule 6(1)(g), LM(PC) Rules 2011",
                extracted_value=bbd.value,
                confidence=bbd.confidence,
            )]
        return []

    def check_date_consistency(
        self, mfg_date: ExtractedField, bbd: ExtractedField
    ) -> list[Violation]:
        """
        Cross-field check: Best Before date must be AFTER Manufacture date.
        This is our signature "Marie Gold" check from the pitch.
        """
        if not mfg_date.is_found or not bbd.is_found:
            return []  # Can't compare if either is missing

        if mfg_date.confidence < LOW_CONF or bbd.confidence < LOW_CONF:
            return []  # Too uncertain to make a cross-field judgment

        # Relative durations ("6 months from packaging") are not absolute
        # dates — dateutil's fuzzy parsing would invent a date from them.
        for field in (mfg_date, bbd):
            if any(w in field.value.lower() for w in ("month", "week", "year", "day", "from")):
                return []

        try:
            mfg_dt = dateutil_parser.parse(mfg_date.value, dayfirst=False, fuzzy=True)
            bbd_dt = dateutil_parser.parse(bbd.value, dayfirst=False, fuzzy=True)

            if bbd_dt <= mfg_dt:
                return [Violation(
                    field_name="date_consistency",
                    severity=Severity.CRITICAL,
                    message=f"DATE INCONSISTENCY: Best Before date '{bbd.value}' "
                            f"is not after Manufacture date '{mfg_date.value}'. "
                            f"Product may be expired or label is incorrect.",
                    rule_reference="Rule 6(1)(g), LM(PC) Rules 2011",
                    extracted_value=f"MFG: {mfg_date.value}, BBD: {bbd.value}",
                    confidence=min(mfg_date.confidence, bbd.confidence),
                )]
        except (ValueError, OverflowError) as e:
            logger.debug("Could not parse dates for cross-check: %s", e)

        return []

    def check_manufacturer(self, manufacturer: ExtractedField) -> list[Violation]:
        """Rule 6(1)(a): Name and address of manufacturer/packer/importer required."""
        v = _field_violation(
            manufacturer,
            critical_msg="Manufacturer/Packer/Importer name and address not found",
            rule_ref="Rule 6(1)(a), LM(PC) Rules 2011",
            missing_msg="MISSING: Manufacturer or Packer name/address not found on label.",
        )
        return [v] if v else []

    def check_consumer_care(
        self, phone: ExtractedField, email: ExtractedField
    ) -> list[Violation]:
        """Rule 6(1)(k): Consumer care name, address, phone, email required."""
        violations = []
        if not phone.is_found:
            violations.append(Violation(
                field_name="consumer_phone",
                severity=Severity.CRITICAL,
                message="MISSING: Consumer Care phone number not found. "
                        "A contact number must be declared per Rule 6(1)(k).",
                rule_reference="Rule 6(1)(k), LM(PC) Rules 2011",
                extracted_value=None,
                confidence=0.0,
            ))
        elif phone.confidence < LOW_CONF:
            violations.append(Violation(
                field_name="consumer_phone",
                severity=Severity.WARNING,
                message=f"Consumer Care phone detected with low confidence: '{phone.value}'",
                rule_reference="Rule 6(1)(k), LM(PC) Rules 2011",
                extracted_value=phone.value,
                confidence=phone.confidence,
            ))

        if not email.is_found:
            violations.append(Violation(
                field_name="consumer_email",
                severity=Severity.WARNING,  # Phone is enough; email is best practice
                message="Consumer Care email not detected. Recommended per Rule 6(1)(k).",
                rule_reference="Rule 6(1)(k), LM(PC) Rules 2011",
                extracted_value=None,
                confidence=0.0,
            ))
        return violations

    def check_batch_number(self, batch: ExtractedField) -> list[Violation]:
        """Batch/lot number for traceability."""
        if not batch.is_found:
            return [Violation(
                field_name="batch_number",
                severity=Severity.WARNING,
                message="Batch/Lot number not detected. Required for product traceability.",
                rule_reference="Rule 6(1)(d), LM(PC) Rules 2011",
                extracted_value=None,
                confidence=0.0,
            )]
        return []


# ── Singleton ─────────────────────────────────────────────────────────────────
_rule_engine = RuleEngine()


def check_compliance(
    fields: ExtractedFields, ocr_needs_review: bool = False
) -> ComplianceReport:
    """Module-level convenience function."""
    return _rule_engine.run(fields, ocr_needs_review)
