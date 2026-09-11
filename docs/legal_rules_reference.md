# Legal Metrology Rules Reference

Engineering reference for the compliance checks SatyaLabel performs, mapped to code. Derived from the rule engine implementation (`satyalabel_backend/app/services/rule_engine.py`).

> **Disclaimer:** This is engineering documentation describing what the software checks. It is not legal advice. The Legal Metrology (Packaged Commodities) Rules, 2011 should be consulted in full for authoritative requirements.

## Checks Implemented

| # | Rule Citation | Requirement (plain language) | What SatyaLabel looks for | Severity when missing | Code |
|---|---|---|---|---|---|
| 1 | Rule 6(1)(a) | Name and address of manufacturer/packer/importer must be declared | Section header ("Manufactured by", "Marketed by", "Packed by", "Imported by") followed by name/address text | CRITICAL | `check_manufacturer` |
| 2 | Rule 6(1)(b) | Net quantity in standard units (g/kg, ml/L, nos/pcs) | "Net Qty/Weight/Content/Vol" + number + unit; fallback: any quantity+unit pattern | CRITICAL | `check_net_quantity` |
| 3 | Rule 6(1)(d) | Batch or lot number for traceability | "Batch/Lot/B.No" + alphanumeric | WARNING | `check_batch_number` |
| 4 | Rule 6(1)(e) | Month/year of manufacture or packing | "Mfg/Mfd/Date of Mfg/Packing" + date (month-name or numeric) | CRITICAL | `check_mfg_date` |
| 5 | Rule 6(1)(f) | MRP inclusive of all taxes | "MRP/M.R.P/Maximum Retail Price" + Rs/₹/INR + amount; value must be positive | CRITICAL | `check_mrp` |
| 6 | Rule 6(1)(g) | Best-before / expiry date | "Best Before/BB/BBD/Exp/Use By" + date | WARNING (may be non-perishable) | `check_best_before` |
| 7 | Rule 6(1)(k) | Consumer care details (name, address, phone) | Indian mobile (10-digit), toll-free (1800-…), or STD landline; email is best-practice | CRITICAL (phone), WARNING (email) | `check_consumer_care` |

## Cross-Field Check: Date Consistency

The signature "Marie Gold" check from the team's pitch (`check_date_consistency`):

- Requires both manufacture date and best-before date found with confidence ≥ 0.45
- Parses both dates (day-first fuzzy parsing)
- If **best-before ≤ manufacture date** → CRITICAL violation: *"DATE INCONSISTENCY: Best Before date … is not after Manufacture date … Product may be expired or label is incorrect."* (Rule 6(1)(g))

## Severity Model

| Severity | Trigger | Effect on verdict |
|---|---|---|
| CRITICAL | Mandatory field missing, invalid (e.g. zero MRP), or date inconsistency | Any CRITICAL → `NON_COMPLIANT` |
| WARNING | Low OCR confidence (<0.45) on a found field, or best-before/batch not detected | Only warnings → `NEEDS_VERIFICATION` |
| — | All mandatory fields found with adequate confidence | `COMPLIANT` |

## Explainability Contract

Every violation the API returns carries:

- `field` — which declaration failed
- `message` — human-readable description of exactly what is wrong
- `rule` — the specific rule citation (e.g. "Rule 6(1)(f), LM(PC) Rules 2011")
- `found_value` — what was actually read from the label (or null)
- `confidence` — OCR confidence for that field

This makes every verdict auditable: an inspector (or a court) can trace *why* the system flagged a product, down to the printed text that was or wasn't found.

## Extraction Details

The field extractor (`app/services/field_extractor.py`) recognizes the 10 declaration fields: `mrp`, `net_quantity`, `mfg_date`, `best_before_date`, `manufacturer`, `consumer_phone`, `consumer_email`, `batch_number`, `country_of_origin`, `generic_name`. Each has multiple regex variants tuned for real Indian label typography (₹/Rs., "/-" suffixes, month abbreviations, Indian phone formats).
