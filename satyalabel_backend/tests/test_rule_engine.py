"""
Tests for the Rule Engine — covers all 9 mandatory LM(PC) Rules 2011 fields
and the cross-field date consistency check.
"""
from __future__ import annotations

import pytest

from app.services.field_extractor import ExtractedField, ExtractedFields
from app.services.rule_engine import RuleEngine, Severity, Verdict, check_compliance

# ── Helpers ───────────────────────────────────────────────────────────────────

def _field(name: str, value: str | None, conf: float = 0.85) -> ExtractedField:
    """Quick factory for test ExtractedField instances."""
    return ExtractedField(field_name=name, value=value, confidence=conf)


def _compliant_fields() -> ExtractedFields:
    """A fully compliant set of extracted fields for a hypothetical product."""
    return ExtractedFields(
        mrp=_field("mrp", "50.00"),
        net_quantity=_field("net_quantity", "200g"),
        mfg_date=_field("mfg_date", "Jan 2025"),
        best_before_date=_field("best_before_date", "Jan 2027"),
        manufacturer=_field("manufacturer", "Britannia Industries Ltd, Bengaluru 560001"),
        consumer_phone=_field("consumer_phone", "18001234567"),
        consumer_email=_field("consumer_email", "care@britannia.co.in"),
        batch_number=_field("batch_number", "B-2025-001"),
        country_of_origin=_field("country_of_origin", "India"),
        generic_name=_field("generic_name", "Biscuits"),
    )


# ── Test Fixtures ──────────────────────────────────────────────────────────────

@pytest.fixture
def engine():
    return RuleEngine()


@pytest.fixture
def compliant_fields():
    return _compliant_fields()


# ── Verdict Tests ──────────────────────────────────────────────────────────────

class TestVerdicts:

    def test_fully_compliant_label(self, engine, compliant_fields):
        report = engine.run(compliant_fields)
        assert report.verdict == Verdict.COMPLIANT
        assert report.violation_count == 0

    def test_missing_mrp_is_non_compliant(self, engine, compliant_fields):
        compliant_fields.mrp = _field("mrp", None, 0.0)
        report = engine.run(compliant_fields)
        assert report.verdict == Verdict.NON_COMPLIANT
        assert any(v.field_name == "mrp" for v in report.critical_violations)

    def test_missing_net_quantity_is_non_compliant(self, engine, compliant_fields):
        compliant_fields.net_quantity = _field("net_quantity", None, 0.0)
        report = engine.run(compliant_fields)
        assert report.verdict == Verdict.NON_COMPLIANT

    def test_missing_manufacturer_is_non_compliant(self, engine, compliant_fields):
        compliant_fields.manufacturer = _field("manufacturer", None, 0.0)
        report = engine.run(compliant_fields)
        assert report.verdict == Verdict.NON_COMPLIANT

    def test_missing_consumer_phone_is_non_compliant(self, engine, compliant_fields):
        compliant_fields.consumer_phone = _field("consumer_phone", None, 0.0)
        report = engine.run(compliant_fields)
        assert report.verdict == Verdict.NON_COMPLIANT

    def test_low_confidence_field_gives_needs_verification(self, engine, compliant_fields):
        # Confidence below LOW_CONF (0.45) → WARNING not CRITICAL
        compliant_fields.mrp = _field("mrp", "50.00", conf=0.30)
        report = engine.run(compliant_fields)
        assert report.verdict == Verdict.NEEDS_VERIFICATION
        assert report.violation_count == 0  # No CRITICAL violations
        assert len(report.warnings) > 0


# ── MRP Checks ────────────────────────────────────────────────────────────────

class TestMrpRule:

    def test_valid_mrp_passes(self, engine, compliant_fields):
        violations = engine.check_mrp(compliant_fields.mrp)
        assert violations == []

    def test_zero_mrp_is_violation(self, engine):
        field = _field("mrp", "0.00")
        violations = engine.check_mrp(field)
        assert any(v.severity == Severity.CRITICAL for v in violations)

    def test_negative_mrp_is_violation(self, engine):
        field = _field("mrp", "-10")
        violations = engine.check_mrp(field)
        assert any(v.severity == Severity.CRITICAL for v in violations)

    def test_unparseable_mrp_is_warning(self, engine):
        field = _field("mrp", "fifty rupees")  # Can't parse as number
        violations = engine.check_mrp(field)
        assert any(v.severity == Severity.WARNING for v in violations)

    def test_missing_mrp_message_is_descriptive(self, engine):
        field = _field("mrp", None, 0.0)
        violations = engine.check_mrp(field)
        assert violations[0].rule_reference == "Rule 6(1)(f), LM(PC) Rules 2011"
        assert "MRP" in violations[0].message


# ── Date Consistency ──────────────────────────────────────────────────────────

class TestDateConsistency:
    """The signature cross-field check — the Marie Gold test."""

    def test_valid_dates_pass(self, engine):
        mfg = _field("mfg_date", "Jan 2025")
        bbd = _field("best_before_date", "Jan 2027")
        violations = engine.check_date_consistency(mfg, bbd)
        assert violations == []

    def test_expired_product_is_critical(self, engine):
        mfg = _field("mfg_date", "Jan 2025")
        bbd = _field("best_before_date", "Dec 2024")  # Before MFG!
        violations = engine.check_date_consistency(mfg, bbd)
        assert any(v.severity == Severity.CRITICAL for v in violations)
        assert "DATE INCONSISTENCY" in violations[0].message

    def test_same_date_is_critical(self, engine):
        mfg = _field("mfg_date", "Jan 2025")
        bbd = _field("best_before_date", "Jan 2025")  # Same month
        violations = engine.check_date_consistency(mfg, bbd)
        assert any(v.severity == Severity.CRITICAL for v in violations)

    def test_missing_either_date_skips_check(self, engine):
        mfg = _field("mfg_date", None, 0.0)
        bbd = _field("best_before_date", "Jan 2027")
        violations = engine.check_date_consistency(mfg, bbd)
        assert violations == []

    def test_low_confidence_dates_skip_check(self, engine):
        # If OCR is unsure, don't make cross-field assertions
        mfg = _field("mfg_date", "Jan 2025", conf=0.30)
        bbd = _field("best_before_date", "Dec 2024", conf=0.30)
        violations = engine.check_date_consistency(mfg, bbd)
        assert violations == []


# ── Consumer Care ─────────────────────────────────────────────────────────────

class TestConsumerCare:

    def test_valid_phone_and_email_passes(self, engine):
        phone = _field("consumer_phone", "18001234567")
        email = _field("consumer_email", "care@brand.com")
        violations = engine.check_consumer_care(phone, email)
        assert violations == []

    def test_missing_phone_is_critical(self, engine):
        phone = _field("consumer_phone", None, 0.0)
        email = _field("consumer_email", "care@brand.com")
        violations = engine.check_consumer_care(phone, email)
        assert any(v.severity == Severity.CRITICAL for v in violations)

    def test_missing_email_is_warning_only(self, engine):
        phone = _field("consumer_phone", "18001234567")
        email = _field("consumer_email", None, 0.0)
        violations = engine.check_consumer_care(phone, email)
        # Email missing should be WARNING, not CRITICAL
        assert all(v.severity == Severity.WARNING for v in violations)


# ── Summary text ──────────────────────────────────────────────────────────────

class TestSummaryText:

    def test_compliant_summary(self, engine, compliant_fields):
        report = engine.run(compliant_fields)
        assert "COMPLIANT" in report.summary_text()

    def test_non_compliant_summary_includes_violation(self, engine, compliant_fields):
        compliant_fields.mrp = _field("mrp", None, 0.0)
        report = engine.run(compliant_fields)
        assert "NON-COMPLIANT" in report.summary_text()

    def test_needs_verification_summary(self, engine, compliant_fields):
        compliant_fields.mrp = _field("mrp", "50.00", conf=0.30)
        report = engine.run(compliant_fields)
        assert "VERIFICATION" in report.summary_text()


# ── Convenience function ──────────────────────────────────────────────────────

def test_module_level_check_compliance(compliant_fields):
    report = check_compliance(compliant_fields)
    assert report.verdict == Verdict.COMPLIANT
