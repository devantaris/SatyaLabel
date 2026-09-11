# Architecture

SatyaLabel is a FastAPI service that turns a photo of a packaged-commodity label into an explainable Legal Metrology compliance verdict with a court-ready PDF evidence report.

## Pipeline Stages

```
image bytes
   │
   1. PRE-PROCESS (app/services/preprocess.py)
   │    OpenCV: decode, deskew (detected angle), glare detection,
   │    perspective correction, contrast normalization.
   │    Emits PreprocessResult + diagnostics (skew angle, warnings).
   │
   2. OCR (app/services/ocr_service.py)
   │    Tesseract (PSM 3, eng) → per-line confidence.
   │    If mean confidence < 0.60 (OCR_CONFIDENCE_THRESHOLD)
   │    → also run EasyOCR (deep-learning, lazy-loaded ~500 MB model).
   │    Return whichever engine scored higher.
   │    If best < 0.40 (OCR_FALLBACK_THRESHOLD) → needs_manual_review=True.
   │
   3. FIELD EXTRACTION (app/services/field_extractor.py)
   │    Regex pattern library per mandatory declaration (multiple
   │    variants each: "MRP Rs. 50", "M.R.P: ₹50.00", "₹50/-" …).
   │    Confidence = OCR line confidence when matched on a line,
   │    0.5 fallback for raw-text-only matches.
   │
   4. RULE ENGINE (app/services/rule_engine.py)
   │    Deterministic checks per LM(PC) Rules 2011 declaration.
   │    Missing field → CRITICAL violation. Low confidence (<0.45)
   │    → WARNING. Cross-field checks (date consistency).
   │    → ComplianceReport: verdict + violations + citations.
   │
   5. OUTPUT
        ├─ JSON API response (ScanPipelineResult.to_api_response)
        ├─ ScanRecord persisted (PostgreSQL + PostGIS)
        └─ PDF evidence report (report_generator.py, ReportLab)
```

## Confidence Model

Three thresholds govern certainty throughout the system:

| Threshold | Value | Meaning |
|---|---|---|
| `OCR_CONFIDENCE_THRESHOLD` | 0.60 | Below → also try EasyOCR, use the better engine |
| `OCR_FALLBACK_THRESHOLD` | 0.40 | Below → flag scan for manual review |
| `LOW_CONF` (rule engine) | 0.45 | Below → violation downgraded to WARNING, not CRITICAL |

## Verdict State Machine

```
                 ┌────────────────┐
                 │ any CRITICAL   │
                 │ violation      │──▶ NON_COMPLIANT
                 └────────────────┘
                 ┌────────────────┐
   scan fields ─▶│ warnings > 0   │──▶ NEEDS_VERIFICATION
                 │ or OCR flagged │
                 └────────────────┘
                 │ otherwise      │
                 ▼
             COMPLIANT
```

## Async Processing (Celery)

```
POST /scans/async ──▶ save image + PENDING record ──▶ task queue (Redis)
                                                            │
client polls ◀── GET /scans/{id} ◀── DB ◀── Celery worker ──┘
                                      (process_scan_task:
                                       PROCESSING → pipeline → COMPLETED/FAILED)
```

- The API **falls back to synchronous processing** if the broker is unreachable, so demos never break.
- Worker and API share the `uploads/` volume (docker-compose `uploads_data`).

## Data Model

**users** — email (unique), bcrypt password hash, role (`citizen|inspector|admin`), badge_number (unique), district, is_active, created_at.

**scan_records** — id (UUID), user_id (FK, nullable — anonymous citizen scans), session_id (inspector raid batch), status (`PENDING|PROCESSING|COMPLETED|FAILED`), verdict, violation_count, ocr_engine, ocr_confidence, extracted_fields (JSONB), compliance_data (JSONB), preprocess_diagnostics (JSONB), location (PostGIS Geography POINT 4326, GiST index), image_path, needs_review, created_at.

## Security

- JWT bearer tokens (HS256, 8 h expiry matching an inspector shift), `python-jose`.
- bcrypt password hashing (12 rounds).
- Roles: `citizen` (self-register), `inspector`, `admin` (bootstrap-seeded).
- Scan endpoints accept optional auth: anonymous scans allowed, authenticated scans bound to the user.
