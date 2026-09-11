# API Reference

Base URL: `http://localhost:8000` — interactive docs at `/docs` (Swagger UI).

All scan endpoints accept `multipart/form-data`. Auth endpoints use JSON.

---

## Health

### `GET /health`

```json
{"status": "ok", "service": "SatyaLabel", "version": "0.1.0"}
```

---

## Scans

### `POST /api/v1/scans/` — Scan a label (synchronous)

**Request** (multipart): `image` (JPEG/PNG/WebP/HEIC, ≤10 MB, required), `latitude`, `longitude`, `session_id` (all optional).

```bash
curl -X POST http://localhost:8000/api/v1/scans/ \
  -F "image=@label.jpg" \
  -F "latitude=28.6139" \
  -F "longitude=77.2090" \
  -F "session_id=raid-2026-09-11-01"
```

**Response 200:**

```json
{
  "scan_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "verdict": "NON_COMPLIANT",
  "summary": "❌ NON-COMPLIANT — MISSING: Best Before... ; ...",
  "needs_manual_review": false,
  "status": "COMPLETED",
  "ocr": {
    "engine_used": "tesseract",
    "mean_confidence": 0.92,
    "raw_text": "BRITANNIA Marie Gold Biscuits\nNet Qty: 200g\nMRP Rs. 25.00 ..."
  },
  "extracted_fields": {
    "mrp": {"found": true, "value": "25.00", "confidence": 0.92, "snippet": "MRP Rs. 25.00"},
    "net_quantity": {"found": true, "value": "200g", "confidence": 0.92, "snippet": "Net Qty: 200g"}
  },
  "compliance": {
    "verdict": "NON_COMPLIANT",
    "critical_violations": [
      {
        "field": "best_before_date",
        "severity": "CRITICAL",
        "message": "MISSING: Best Before / Expiry date not found on label.",
        "rule": "Rule 6(1)(g), LM(PC) Rules 2011",
        "found_value": null,
        "confidence": 0.0
      }
    ],
    "warnings": [],
    "needs_manual_review": false,
    "checked_at": "2026-09-11T12:00:00+00:00",
    "extracted_fields": {"...": "..."}
  },
  "preprocess_diagnostics": {
    "skew_angle": -1.25,
    "glare_detected": false,
    "perspective_corrected": false,
    "warnings": []
  },
  "location": {"latitude": 28.6139, "longitude": 77.2090},
  "session_id": "raid-2026-09-11-01",
  "image_url": "/uploads/7c9e6679-7425-40de-944b-e07fc1f90ae7.jpg",
  "created_at": "2026-09-11T12:00:00+00:00"
}
```

**Errors:** `415` unsupported format · `413` too large · `400` corrupt/empty or processing failure · `500` internal error.

> A valid `Authorization: Bearer <token>` header binds the scan to your account.

### `POST /api/v1/scans/async` — Submit for background processing

Same request as above. **Response 202:**

```json
{
  "scan_id": "7c9e6679-...",
  "status": "PENDING",
  "message": "Scan accepted for processing. Poll GET /api/v1/scans/{scan_id}.",
  "session_id": null,
  "created_at": "2026-09-11T12:00:00+00:00"
}
```

Poll `GET /api/v1/scans/{scan_id}` until `status` is `COMPLETED` or `FAILED`. Falls back to synchronous processing (response contains full result) if the task queue is unavailable.

### `GET /api/v1/scans/{scan_id}` — Retrieve a scan

**Response 200** (shape as persisted):

```json
{
  "scan_id": "7c9e6679-...",
  "status": "COMPLETED",
  "verdict": "NON_COMPLIANT",
  "violation_count": 2,
  "ocr_engine": "tesseract",
  "ocr_confidence": 0.92,
  "extracted_fields": {"mrp": {"found": true, "value": "25.00", "...": "..."}},
  "compliance": {"verdict": "NON_COMPLIANT", "critical_violations": ["..."], "...": "..."},
  "preprocess_diagnostics": {"skew_angle": -1.25, "...": "..."},
  "session_id": "raid-01",
  "needs_review": false,
  "report_generated": false,
  "image_url": "/uploads/7c9e6679-....jpg",
  "created_at": "2026-09-11T12:00:00+00:00"
}
```

**Errors:** `404` scan not found.

### `GET /api/v1/scans/` — List scans

Query params: `limit` (≤100, default 50), `offset`, `verdict` (`COMPLIANT|NON_COMPLIANT|NEEDS_VERIFICATION`), `session_id`, `needs_review`, `created_after`, `created_before` (ISO datetimes).

```json
{
  "items": [ {"scan_id": "...", "...": "..."} ],
  "total": 42,
  "limit": 50,
  "offset": 0
}
```

**Errors:** `400` invalid filter/pagination values.

### `POST /api/v1/scans/report` — Scan + PDF evidence report

**Request** (multipart): `image`, `inspector_badge` (default `INSP-DL-2026-084`), `inspector_name`, `location_hint`.

**Response 200:** `application/pdf` attachment (`SatyaLabel_Evidence_{scan_id8}.pdf`) containing the verdict, violations with rule citations, and the photo evidence.

---

## Auth

### `POST /api/v1/auth/register`

```json
{"email": "inspector@gov.in", "password": "min-8-chars", "full_name": "R. Kumar"}
```

**201** → user profile. **409** duplicate email/badge · **403** privileged role without bootstrap credentials · **422** validation.

Only `citizen` is self-serve. `inspector`/`admin` additionally require `bootstrap_admin_email`/`bootstrap_admin_password` matching the server's `BOOTSTRAP_ADMIN_EMAIL`/`BOOTSTRAP_ADMIN_PASSWORD` env vars (used once to seed the first admin).

### `POST /api/v1/auth/login`

```json
{"email": "inspector@gov.in", "password": "min-8-chars"}
```

```json
{
  "access_token": "eyJhbGciOi...",
  "token_type": "bearer",
  "expires_in": 28800,
  "user": {"id": "…", "email": "…", "role": "inspector", "badge_number": "…", "...": "..."}
}
```

**401** wrong credentials or deactivated account.

### `GET /api/v1/auth/me` (Bearer token required)

Returns the authenticated user's profile. **401** missing/invalid token.

---

## Static Files

`GET /uploads/{filename}` — scan evidence images.

---

## Planned (not yet implemented)

- `GET /api/v1/analytics/heatmap` — PostGIS violation heatmap
- `GET /api/v1/scans/session/{id}` — grouped raid-session reports
- Refresh tokens, rate limiting, API keys
