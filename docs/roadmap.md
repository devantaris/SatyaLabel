# Roadmap

Production plan for SatyaLabel (SIH 2026, SIH26034 — Team The Hippos).

## Phase 0 — Version Control & CI ✅ (2026-09-11)

- git + GitHub (`devantaris/SatyaLabel`), `.gitignore`
- GitHub Actions CI: pytest + ruff + Tesseract on every push/PR

## Phase 1 — Persistence ✅ (2026-09-11)

- Alembic async migrations (users, scan_records, PostGIS extension, GiST index)
- Scan repository (save/get/list with filters + pagination)
- `GET /scans/{id}` implemented; `GET /scans/` list added
- Images stored and served via `/uploads`

## Phase 2 — Async Processing ✅ (2026-09-11)

- Celery app + `process_scan_task` (the missing `app/core/celery_app.py` that docker-compose referenced — worker no longer crash-loops)
- `POST /scans/async` → 202 + PENDING record + polling
- `scan_records.status` lifecycle (PENDING → PROCESSING → COMPLETED/FAILED)
- Synchronous fallback when the broker is down

## Phase 3 — Auth & Roles ✅ (2026-09-11)

- bcrypt password hashing, JWT (8 h, inspector-shift aligned)
- `/auth/register`, `/auth/login`, `/auth/me`
- citizen / inspector / admin roles; first-admin bootstrap credentials
- Scans optionally bound to authenticated users

## Phase 4 — Hardening & Docs ✅ (2026-09-11)

- README, architecture/API/legal-reference docs
- Pydantic auth schemas, modern ruff config, lint clean
- `.env.example` maintained

## Phase 5 — Frontend ✅ (2026-09-11)

- `satyalabel_frontend/` Flutter app (Android + iOS): camera capture, verdict display, PDF download
- **Inspector Mode:** raid sessions (batch scans under one session_id), history
- Offline scan queue with background sync (matches the pitch's offline promise)
- Login/role-aware UI; 29 tests; debug APK builds

## Phase 6 — Analytics Dashboard ✅ (2026-09-11)

- `GET /api/v1/analytics/heatmap` — PostGIS `ST_SnapToGrid` violation heatmap (inspector-only)
- `GET /api/v1/analytics/manufacturers` — repeat-offender manufacturer aggregation (JSONB)
- `GET /api/v1/analytics/overview` + `/districts` — headline + district-level stats
- `GET /api/v1/analytics/export` — CSV export for legal action
- Flutter Analytics dashboard (inspector-only): overview cards, hotspots, offenders, CSV share

## Phase 7 — Production Deployment ✅ (2026-09-11, local build verified)

- `Dockerfile.prod` — non-root user, non-editable install, no dev tools, 2 uvicorn workers
- `docker-compose.prod.yml` — no source mounts, auto `alembic upgrade head` on start,
  restart policies, healthchecks, nginx edge proxy
- `deploy/nginx.conf` — reverse proxy (12 MB upload limit, gzip) + commented TLS/certbot blocks
- Optional S3-compatible image storage (`app/services/storage.py`, `pip install ".[s3]"`)
  with local-disk default, public-base or presigned URLs
- `docs/deployment.md` — full runbook: secrets, TLS, first-admin seeding, backups, checklist
- Remaining for a real deployment: a server + domain + DNS (credentials not in this repo)

## Deferred / optional

- Hindi OCR (EasyOCR "hi" model — the loader already anticipates it)
- Refresh tokens, rate limiting, API keys
- E2E tests against live Postgres/Redis (CI services)
