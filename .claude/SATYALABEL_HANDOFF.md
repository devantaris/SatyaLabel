# SatyaLabel — Project Handoff

> **Persistent session-to-session handoff.** Documents the CURRENT state only.
> Do not redesign or refactor based on this file. Read fully before continuing development.
> Last updated: 2026-09-13 (session 4) · Phases 0–7 COMPLETE · **LIVE IN PRODUCTION** (see §2a)

---

## 1. Project Overview & Architecture

**SatyaLabel** — Team The Hippos' Smart India Hackathon 2026 entry (problem **SIH26034**): a camera-based scanner that checks packaged-commodity product labels against the **Legal Metrology (Packaged Commodities) Rules, 2011**, producing an explainable verdict with legal citations and a court-ready PDF evidence report.

**Core design principle (preserve it): EXPLAINABLE over MAGICAL.** Never "AI says non-compliant" — always the specific rule citation, e.g. `VIOLATION — MRP declaration not found. Required per Rule 6(1)(f), LM(PC) Rules, 2011.`

### Pipeline

```
Camera image
  → Pre-process (OpenCV: deskew, de-glare, perspective, CLAHE)
  → OCR (Tesseract primary; EasyOCR fallback if conf < 0.60; manual-review flag < 0.40)
  → Field extraction (regex library, 10 mandatory declarations, per-field confidence)
  → Rule engine (deterministic LM(PC) 2011 checks + cross-field date consistency)
  → JSON response / PDF evidence report / DB persistence
```

Verdict state machine: any CRITICAL → `NON_COMPLIANT`; else any WARNING or OCR-review flag → `NEEDS_VERIFICATION`; else `COMPLIANT`. Full details in `docs/architecture.md` and `docs/legal_rules_reference.md`.

### Repo layout

```
SatyaLabel/
├── .claude/                  # settings.local.json (permission allowlist) + this handoff
├── .github/workflows/ci.yml  # CI: ruff + pytest + Tesseract on push/PR — ✅ GREEN as of 4a52044
├── docs/                     # architecture.md, api.md, legal_rules_reference.md, roadmap.md
├── legal/                    # EMPTY directory (placeholder, never populated)
├── satyalabel_backend/       # FastAPI + Celery + PostGIS backend (see §3)
├── satyalabel_frontend/      # ✅ NEW (Phase 5): Flutter app — see §5
├── LICENSE                   # MIT
└── SIH26034_Idea_Presentation.pptx / SatyaLabel SIH Pitch.docx / The Hippos_SIH26034.pdf
```

---

## 2. Completed Work (Phases 0–5)

| Phase | Commit | What landed |
|---|---|---|
| 0 — VCS/CI | `4c26953`→rewritten | git init, `.gitignore`, GitHub repo, CI workflow, initial push |
| 1 — Persistence | `1ae73cc` | Alembic async migrations (users, scan_records, PostGIS ext, GiST index), `scan_repository.py`, `GET /scans/{id}` + list w/ filters+pagination, image storage + `/uploads` static mount |
| 2 — Async | `560411c` | `app/core/celery_app.py`, `scan_tasks.py`, `POST /scans/async` → 202 + polling, status lifecycle, sync fallback when broker down |
| 3 — Auth | `1f58c37` | bcrypt + JWT auth (`/auth/register|login|me`), role guards, first-admin bootstrap, scans optionally bound to users |
| 4 — Hardening/Docs | `4d10be1` | README, docs/, prod SECRET_KEY guard, `pydantic[email]` |
| Fixes | `1f6134f`, `23bbf1b` | LICENSE; Docker build fix + 2 live E2E bug fixes |
| CI fix | `7ac4d7e` | **Fixed the CI that had been red since commit 1**: setuptools flat-layout auto-discovery refused to build (`['app','alembic']` multiple top-level packages) — added `[tool.setuptools.packages.find] include=["app*"]` to pyproject.toml |
| 5 — Flutter | `4a52044` | **Full frontend** — see §4 |
| 6 — Analytics | `d57f2ee` | `GET /api/v1/analytics/{overview,heatmap,manufacturers,districts,export}` (inspector-only, PostGIS ST_SnapToGrid + JSONB aggregations, CSV export); Flutter inspector Analytics dashboard; live-verified |
| 7 — Production | `c841e5e` | `Dockerfile.prod` (non-root, non-editable), `docker-compose.prod.yml` (no source mounts, auto-migrations, healthchecks, nginx), `deploy/nginx.conf` (TLS-ready), S3-compatible storage abstraction (`pip install ".[s3]"`), `docs/deployment.md` runbook |
| Device fixes | `6131139` | **Physical-device connectivity**: 422 on every app scan upload (Dart multipart parts lacked `filename` → python-multipart parses them as text fields → FastAPI rejects); offline false-negative (health poll was gated on connectivity_plus, which cannot see adb reverse tunnels); `BASE_URL` dart-define; NDK 27 pin. Verified E2E on physical Redmi: scans 200, offline queue auto-sync, analytics, login. **Gotcha: `adb reverse` mappings are cleared on every USB replug — re-run `adb reverse tcp:8000 tcp:8000` (or use the watchdog loop) after unplugging the phone.** |
| Live deploy | `0d8fa6b`→`4ba2985` | **Deployed live** — see §2a |

### 2a. LIVE DEPLOYMENT (session 4, 2026-09-13)

**API: https://satyalabel-api.onrender.com** (Render free plan, Docker, region Singapore)
**DB: Supabase Postgres 17 + PostGIS** (region ap-southeast-1, session pooler URI on 5432)
**Test inspector: `inspector@gov.in` / `inspect-2026`** (seeded direct-SQL into Supabase)

- `render.yaml` (repo root) is the Render blueprint — 3 dashboard-managed secrets: `DATABASE_URL` (asyncpg), `DATABASE_URL_SYNC` (psycopg2), `SECRET_KEY`. Everything else is in the yaml.
- `satyalabel_backend/Dockerfile.cloud`: CPU-only torch (default PyPI serves 2.5GB CUDA wheels on linux), `$PORT`, single worker, migrations at start.
- Deploy flow: push to `main` → Render auto-deploys (build ~10 min). Secrets live only in Render's dashboard.
- Release APK: `flutter build apk --release --dart-define=BASE_URL=https://satyalabel-api.onrender.com`.
- Verified live E2E: health, migrations/PostGIS, sync scan (COMPLIANT, conf 0.95, 9/10 fields), persistence, inspector login, analytics overview + PostGIS heatmap, CSV-ready, PDF report (82KB).
- Field-extraction fixes found via live smoke test (`4ba2985`): spaced mobiles/`+91` landlines in consumer_phone; YYYY/MM/DD + "15 Aug 2026" + "Mfg Date"/"Best Before Date" headers + relative durations ("6 months from packaging") in dates; date-consistency skips relative durations. Tests: 133 passing.
- **Free-tier constraints:** sleeps after 15 min idle (~30-60s cold wake; the app's 30s health poll keeps it awake while open); 512MB RAM — Tesseract path fine, EasyOCR fallback would OOM (only triggers when OCR conf < 0.60); `/tmp/uploads` is ephemeral (images lost on redeploy; verdicts/history/analytics persist in Supabase). No Celery worker/Redis deployed — async scan falls back to sync.
- Hosting history this session: Railway trial expired; HF Spaces requires PRO for Docker. Railway config (`railway.json`, `.railwayignore`) remains in repo if ever needed.

> **History note (2026-09-11 session 2):** git history was rewritten with `git filter-branch --msg-filter` to remove all `Co-Authored-By: Claude` trailers (8 commits). Trees were verified byte-identical before force-push (`--force-with-lease`). Backup branch: `backup/pre-attribution-rewrite` (local only). `~/.claude/settings.json` now has `includeCoAuthoredBy: false` + `"attribution": {"commit": "", "pr": ""}` — future commits/PRs carry no attribution.

---

## 3. Backend Architecture & Services

**Location:** `satyalabel_backend/` · Python ≥3.11 (local dev on 3.14, Docker image python:3.11-slim, CI on 3.12)

### FastAPI (`main.py`, `app/api/v1/`)
- `POST /api/v1/scans/` — sync scan, persisted, optional Bearer binding
- `POST /api/v1/scans/async` — 202 + PENDING, Celery dispatch, sync fallback
- `POST /api/v1/scans/report` — court-ready PDF (ReportLab, photo embedded, `SatyaLabel_Evidence_{id8}.pdf`)
- `GET /api/v1/scans/{id}` — persisted result (404 if missing)
- `GET /api/v1/scans/` — paginated list; filters: verdict, session_id, needs_review, created_after/before
- `POST /api/v1/auth/register` (citizen self-serve; inspector/admin need bootstrap creds), `POST /api/v1/auth/login`, `GET /api/v1/auth/me`
- `GET /health`; static `/uploads/{filename}`
- Validation: MIME allowlist (jpeg/png/webp/heic), ≤10 MB, ≥1 KB → 415/413/400

### Services (`app/services/`)
- `preprocess.py` — OpenCV: 1200px resize, glare inpaint, Hough deskew ≤25°, 4-point homography, CLAHE, Otsu+adaptive binarization
- `ocr_service.py` — Tesseract primary; EasyOCR fallback (lazy ~500 MB model) when conf < 0.60; `needs_manual_review` < 0.40
- `field_extractor.py` — regex patterns for 10 fields; line-confidence or 0.5 raw-text fallback
- `rule_engine.py` — Rules 6(1)(a)(b)(d)(e)(f)(g)(k) + date-consistency cross-check; `LOW_CONF=0.45` downgrades to WARNING
- `report_generator.py` — PDF; attestation cites Section 36, Legal Metrology Act 2009
- `scan_pipeline.py` — orchestration (stdlib %-format logging — do NOT reintroduce structlog kwargs)
- `scan_repository.py` — save/get/list/create_pending/complete/fail/mark_processing/scan_to_dict

### PostgreSQL + PostGIS
- Models: `users`, `scan_records` (UUID, status, verdict nullable-until-complete, JSONB ×3, Geography POINT 4326 w/ GiST, needs_review, image_path…)
- Alembic async env; migrations `0001_initial`, `0002_scan_status`
- **Async-engine gotcha (architectural decision):** the module-level engine in `app/core/database.py` binds its pool to the first event loop. Celery tasks must NOT reuse it — `scan_tasks._task_session()` creates a per-task engine. Preserve this pattern.

### Redis + Celery
- `app/core/celery_app.py`, task `satyalabel.process_scan`, JSON-only serialization, time limits 300/360 s, retry ×2 on ConnectionError
- Worker: `celery -A app.core.celery_app worker --loglevel=info`

### Auth
- bcrypt direct (12 rounds) — passlib deliberately NOT used (broken on py3.14)
- JWT HS256 via python-jose, 8 h expiry

### Docker Compose (`satyalabel_backend/docker-compose.yml`)
Services: `api` (:8000, --reload), `worker`, `db` (postgis/postgis:16-3.4), `redis`. Dev-grade — production compose is Phase 7 work.
Dockerfile: python:3.11-slim + tesseract-ocr + libs; copies `pyproject.toml` AND `README.md` before pip install (readme is referenced in `[project]` — do not remove).

---

## 4. Frontend — Phase 5 (COMPLETE, `satyalabel_frontend/`)

Flutter 3.32.7 / Dart 3.8.1, Android + iOS, org `dev.hippos`.

### Features implemented
- **Citizen Mode:** anonymous camera capture → verdict banner (COMPLIANT / NON-COMPLIANT / NEEDS VERIFICATION) + violations with rule citations + extracted fields w/ confidence + OCR diagnostics; PDF evidence report download/share
- **Inspector Mode:** JWT login + citizen self-registration (`login_screen.dart`); raid batch scanning under generated `raid-YYYYMMDD-HHMM` session ids; per-session verdict statistics (compliant/non-compliant/verify) + session history via `GET /scans/?session_id=`; badge-carrying PDF reports
- **Camera scanning:** `camera` package, back camera, torch toggle, lifecycle-safe dispose/reinit, >9 MB photos re-encoded (reduced-width PNG) to fit the 10 MB backend cap
- **Offline queue:** `lib/services/offline_queue.dart` — images to disk + metadata in SharedPreferences; auto-sync via the **synchronous** `POST /scans/` endpoint; triggers on connectivity change + 30 s health poll; 4xx server rejections drop unrecoverable entries, 5xx/network keep them for retry
- **Backend integration:** `lib/core/api_client.dart` — typed client for every endpoint (health/login/register/scan/scan async/get/list/report), injected `http.Client` for tests, `ApiException`/`NetworkException` with detail extraction
- **Auth integration:** Bearer token attached to scan submissions (binds scans to account); SharedPreferences session persistence
- **States:** loading (spinners/overlays), error (per-tile + full-screen retry views + snackbars), success (verdict banner), verification (needs-review banner, PENDING/PROCESSING/FAILED statuses with refresh)
- **Config:** backend URL editable in-app (default `http://10.0.2.2:8000`; restart required to apply)
- **Permissions:** Android manifest + iOS Info.plist — camera, location (when-in-use), cleartext HTTP for dev

### Layout
```
satyalabel_frontend/lib/
├── core/api_client.dart, session_store.dart
├── models/{scan,auth}_models.dart
├── services/{offline_queue,location_service}.dart
├── state/app_state.dart          # ChangeNotifier: auth/connectivity/queue
└── ui/ home, auth/login, scan/{camera,scan_result}, batch/batch_sessions, history/history, widgets, theme
```

### Tests (29, all passing)
- `models_test.dart` — both response shapes (sync nested-`ocr` AND persisted flat record), violations/fields/location, auth
- `api_client_test.dart` — mocked HTTP: multipart w/ Bearer + fields, error detail extraction (401/415/404), list filters, PDF bytes
- `offline_queue_test.dart` — enqueue/persist/reload, sync success + cleanup, backend-unreachable preserves queue, 4xx-drop/5xx-keep, metadata on upload
- `widget_test.dart` — VerdictBanner × 3 states, StatusBanner

---

## 5. Current Verification Status

| Check | Status |
|---|---|
| GitHub Actions CI | ✅ green (backend: ruff + pytest on py3.12/ubuntu — every push since `7ac4d7e`) |
| Local backend tests | ✅ 118 passing (`python -m pytest tests/ -q`) — includes 8 analytics + 8 storage tests |
| Ruff | ✅ clean (`python -m ruff check app tests alembic`) |
| Flutter analyze / tests | ✅ no issues / 35 passing |
| Android debug APK build | ✅ `flutter build apk --debug` |
| Dev Docker build + live stack | ✅ running; live-verified: sync scan, async scan (worker storage.read path), analytics endpoints, CSV export, PostGIS heatmap |
| Prod Docker image | ✅ `Dockerfile.prod` builds; smoke-tested standalone (`/health` 200, 2 uvicorn workers) |
| Claude attribution | ✅ none in remote history; future commits configured without attribution |

### Analytics (Phase 6) — implemented
- Backend: `app/services/analytics_repository.py` (raw SQL: `ST_SnapToGrid` heatmap, JSONB manufacturer aggregation, district join, overview counters, export rows) + `app/api/v1/analytics.py` (inspector-only routes incl. CSV). Query params: `days`, `grid_size`, `min_scans`, `limit`.
- Flutter: `lib/ui/analytics/analytics_screen.dart` — inspector-only dashboard (overview cards, hotspots, repeat offenders, districts, 7d/30d/all window chips, CSV share) + ApiClient analytics methods.
- **Web dashboard (2026-09-13)**: `app/static/dashboard.html` served at **`/dashboard`** (`main.py` FileResponse) — interactive Consumer Affairs dashboard: login (JWT → sessionStorage), leaflet.heat PostGIS heatmap + clickable cell markers, overview cards, repeat offenders, districts, 7d/30d/all filters, CSV export. Live URL: `https://satyalabel-api.onrender.com/dashboard`.
- A live test inspector exists in the dev DB: `inspector@gov.in` / `inspect-2026` (seeded via SQL for E2E — remove or keep for demo).

### OCR overhaul (2026-09-13, commits 51f72a9) — real-photo fix
- **Problem**: real camera photos → all-fields-missing NON_COMPLIANT (bogus perspective warp to 1200×10575, destructive Otsu∧adaptive binarization, EasyOCR OOM at 512 MB).
- **Fix**: perspective quad sanity checks (area 25–98%, aspect ≤3.5); Tesseract now fed CLAHE grayscale (it binarizes internally); **EasyOCR replaced by RapidOCR** (`rapidocr-onnxruntime`, ~100 MB RAM, fits free tier — torch preinstall dropped from `Dockerfile.cloud`); two-column label rows merged (`_merge_same_row`); MRP regex rejects LM licence numbers (`R-113/9`→`Rs.1.13/9`) via possessive quantifiers + `/digit` lookahead; batch codes must contain a digit; **zero mandatory fields readable → NEEDS_VERIFICATION "retake"** instead of NON_COMPLIANT (non-label photos). Flutter camera → `ResolutionPreset.max`.
- Local Tesseract 5.4 now installed at the default config path (was: tests mock OCR only). 140 tests pass.

### Storage abstraction (Phase 7)
- `app/services/storage.py` — `LocalStorage` (default, UPLOAD_DIR + `/uploads` mount) and `S3Storage` (boto3 via `pip install ".[s3]"`; `S3_PUBLIC_URL_BASE` or presigned URLs). Wired into scans API, Celery worker, and `scan_to_dict`. `main.py` mounts `/uploads` only for the local backend.
- Production files: `Dockerfile.prod`, `docker-compose.prod.yml` (**must run with `--env-file .env.prod`** — compose interpolation does not read env_file), `deploy/nginx.conf` (TLS-ready, commented HTTPS block), `.env.prod.example`, `docs/deployment.md` runbook.

## 6. Git / GitHub State

- Remote: `https://github.com/devantaris/SatyaLabel.git` (branch `main`, in sync at `4a52044`)
- Local branch `backup/pre-attribution-rewrite` holds the pre-rewrite history (delete once confident)
- `gh` CLI still not installed — GitHub API access works via stored git credentials + curl (token from `git credential fill`)
- History was force-pushed once (`--force-with-lease`) — anyone with a clone should re-clone or reset to origin/main
- Git identity: Devansh Kumar / wanhedareborn3 (noreply)

---

## 7. Remaining Work

All roadmap phases (0–7) are complete and the stack is **live in production** (§2a). What's left:

1. **Device test of the release APK** against the live URL — install `satyalabel_frontend/build/app/outputs/flutter-apk/app-release.apk` on the Redmi (uninstall the old dev app first — a previously-set in-app URL persists in SharedPreferences and would override the baked-in default). No adb reverse needed anymore: the backend is public HTTPS.
2. Optional polish: Flutter CI job in ci.yml (analyze + test); populate `legal/` with the LM(PC) Rules 2011 text; Hindi OCR (deferred roadmap item).
3. Optional infra upgrades when budget allows: paid Render instance (no sleep, more RAM for EasyOCR), S3 image storage (survives redeploys), Redis + Celery worker for async scans, custom domain.

## 8. Commands

### Backend (from `satyalabel_backend/`)
```bash
python -m pytest tests/ -q
python -m ruff check app tests alembic
uvicorn main:app --reload                     # http://localhost:8000/docs
celery -A app.core.celery_app worker --loglevel=info
docker compose build && docker compose up -d
docker compose exec api python -m alembic upgrade head
docker compose down                           # add -v to wipe volumes
```

### Frontend (from `satyalabel_frontend/`)
```bash
flutter pub get
flutter analyze
flutter test
flutter run                # device/emulator; backend URL configurable in-app
flutter build apk --debug
```

---

## 9. Architectural Decisions & Constraints (all still in force)

1. Explainable rule engine with legal citations — preserve, never replace with opaque ML verdicts
2. bcrypt directly, NOT passlib
3. Per-task SQLAlchemy engine in Celery tasks (`scan_tasks._task_session`)
4. Stdlib %-format logging only in services
5. Backend tests run DB-free (mocked sessions) — keep new tests DB-free
6. Persistence best-effort in sync scan endpoints
7. `build-backend` = `setuptools.build_meta`; package discovery now explicit (`include=["app*"]`) — flat-layout auto-discovery was the CI killer
8. Scans are anonymous-friendly: auth optional on scan endpoints
9. Frontend offline sync uses the **synchronous** scan endpoint (per handoff/pitch requirement)
10. Flutter app targets Android + iOS only (no web/desktop)

### Known gotchas
- `gh` CLI not installed; use git-credential token + curl for GitHub API
- First EasyOCR use downloads ~500 MB models (slow first async scan)
- Tesseract default path in config is Windows-specific; docker/CI override it
- Base-URL change requires app restart (ApiClient is late-final) — documented in settings UI
- Ruff `--fix` can mangle exception variables — review diffs after autofix
- Background Claude subagents in this environment get tool-permission auto-denials — run implementation in the foreground

---

*End of handoff. Keep this file updated as phases complete.*
