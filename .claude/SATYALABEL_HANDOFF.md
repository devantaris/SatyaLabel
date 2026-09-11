# SatyaLabel — Project Handoff

> **Persistent session-to-session handoff.** Documents the CURRENT state only.
> Do not redesign or refactor based on this file. Read fully before continuing development.
> Last updated: 2026-09-11 · HEAD: `d633e3d` (main, pushed to origin)

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
├── .claude/                  # settings.local.json (permission allowlist only — no CLAUDE.md exists)
├── .github/workflows/ci.yml  # CI: ruff + pytest + Tesseract on push/PR  ⚠ CURRENTLY FAILING (see §6)
├── docs/                     # architecture.md, api.md, legal_rules_reference.md, roadmap.md
├── legal/                    # EMPTY directory (placeholder, never populated)
├── satyalabel_backend/       # the entire application (see §3)
├── LICENSE                   # MIT
└── SIH26034_Idea_Presentation.pptx / SatyaLabel SIH Pitch.docx / The Hippos_SIH26034.pdf  # pitch materials
```

**Note:** There is NO Flutter code, NO frontend, and NO Flutter/Claude project instructions in the repository yet. The only project instruction file is this handoff plus `.claude/settings.local.json` (tool permission allowlist — do not overwrite; append only if needed).

---

## 2. Completed Work (Phases 0–4)

| Phase | Commit | What landed |
|---|---|---|
| 0 — VCS/CI | `4c26953` | git init, `.gitignore`, GitHub repo, GitHub Actions CI workflow, initial push |
| 1 — Persistence | `1ae73cc` | Alembic async migrations (users, scan_records, PostGIS ext, GiST index), `scan_repository.py`, `GET /scans/{id}` (was 501), `GET /scans/` list w/ filters+pagination, image storage + `/uploads` static mount |
| 2 — Async | `560411c` | `app/core/celery_app.py` (previously missing — docker worker crash-looped), `app/core/scan_tasks.py`, `POST /scans/async` → 202 + polling, `scan_records.status` lifecycle (PENDING→PROCESSING→COMPLETED/FAILED), sync fallback when broker down |
| 3 — Auth | `1f58c37` | `app/core/security.py` (bcrypt + JWT), `/auth/register`, `/auth/login`, `/auth/me`, role guards (`get_current_user/inspector/admin`, `get_optional_user`), first-admin bootstrap via `BOOTSTRAP_ADMIN_EMAIL/PASSWORD` env, scans optionally bound to users |
| 4 — Hardening/Docs | `4d10be1` | README.md, all 4 docs/ files, production SECRET_KEY guard in main.py lifespan, `pydantic[email]` |
| Fixes | `1f6134f`, `d633e3d` | LICENSE file; Docker build fix + 2 live E2E bug fixes (see §9) |

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
- `preprocess.py` — OpenCV: 1200px resize, glare inpaint (>3% pixels >240), Hough deskew ≤25°, 4-point homography, CLAHE, Otsu+adaptive binarization
- `ocr_service.py` — Tesseract (`--oem 3 --psm 3 -l eng`) primary; EasyOCR fallback (lazy ~500 MB model, CPU) when conf < 0.60; best engine wins; `needs_manual_review` < 0.40
- `field_extractor.py` — regex patterns for 10 fields (mrp, net_quantity, mfg_date, best_before_date, manufacturer, consumer_phone, consumer_email, batch_number, country_of_origin, generic_name); line-confidence or 0.5 raw-text fallback
- `rule_engine.py` — Rules 6(1)(a)(b)(d)(e)(f)(g)(k) + date-consistency cross-check; `LOW_CONF=0.45` downgrades to WARNING
- `report_generator.py` — PDF; attestation cites Section 36, Legal Metrology Act 2009
- `scan_pipeline.py` — orchestration (stdlib %-format logging — do NOT reintroduce structlog kwargs)
- `scan_repository.py` — save_scan / get_scan / list_scans / create_pending_scan / complete_scan / fail_scan / mark_scan_processing / scan_to_dict

### PostgreSQL + PostGIS
- Models: `users` (email, bcrypt hash, role citizen|inspector|admin, badge_number, district), `scan_records` (UUID, user_id FK nullable, session_id, status, verdict nullable-until-complete, violation_count, ocr_engine/confidence, JSONB ×3, Geography POINT 4326 w/ GiST, image_path, needs_review, created_at)
- Alembic async env; migrations `0001_initial`, `0002_scan_status`
- **Async-engine gotcha (architectural decision):** the module-level engine in `app/core/database.py` binds its pool to the first event loop. Celery tasks must NOT reuse it — `scan_tasks._task_session()` creates a per-task engine. Preserve this pattern.

### Redis + Celery
- `app/core/celery_app.py` (broker/backend from settings, includes `app.core.scan_tasks`), task `satyalabel.process_scan`, JSON-only serialization, soft/hard time limits 300/360 s, retry ×2 on ConnectionError
- Worker: `celery -A app.core.celery_app worker --loglevel=info`

### Auth
- bcrypt direct (12 rounds) — **passlib deliberately NOT used** (unmaintained, broken on py3.14)
- JWT HS256 via python-jose, 8 h expiry (inspector shift); deps in `app/core/security.py`

### Docker Compose (`satyalabel_backend/docker-compose.yml`)
Services: `api` (:8000, --reload, volume-mounted source), `worker` (Celery), `db` (postgis/postgis:16-3.4, healthcheck), `redis` (:6379). Shared `uploads_data` volume. Dev-grade (mounted source, reload) — a production compose is Phase 7 work.
Dockerfile: python:3.11-slim + tesseract-ocr + libgl1 + libglib2.0 + libpq-dev + gdal-bin; **copies `pyproject.toml` AND `README.md` before pip install** (readme is referenced in [project] — do not remove).

---

## 4. Current Verification Status

| Check | Status |
|---|---|
| Local test suite | ✅ **102 passing** (`python -m pytest tests/ -q`, ~7 s, no live DB needed — mocked sessions via `tests/conftest.py`) |
| Ruff | ✅ clean (`python -m ruff check app tests alembic`) |
| Docker build | ✅ both images build (`docker compose build`) |
| Local Docker stack | ✅ verified 2026-09-11: 4/4 containers up, db healthy |
| Migrations live | ✅ `alembic upgrade head` applied; PostGIS active; users/scan_records created |
| Real OCR sync scan | ✅ synthetic Marie-Gold label → NEEDS_VERIFICATION verdict, MRP 25.00 + 200g extracted, persisted with PostGIS `POINT(77.209 28.6139)`, GET-by-id + list verified |
| Async scan flow | ✅ 202 → PENDING → worker → EasyOCR fallback (conf 0.745) → COMPLETED |
| PDF report | ✅ 17 KB valid `%PDF-` with inspector badge |

Stack may still be running: `http://localhost:8000/docs` (Swagger). Stop with `docker compose down` (add `-v` to wipe data).

---

## 5. Git / GitHub State

- Remote: `https://github.com/devantaris/SatyaLabel.git` (branch `main`, in sync at `d633e3d`)
- 7 commits, clean conventional-ish messages, all pushed
- Uncommitted: `.claude/settings.local.json` (permission allowlist — expected to churn; currently modified locally)
- Git identity: Devansh Kumar / wanhedareborn3 (noreply). `gh` CLI NOT installed — GitHub API/status checks require installing gh or using the web UI
- 26 MB pptx in repo root (pushed as-is; under GitHub's 100 MB limit)

---

## 6. ⚠️ KNOWN ISSUE: GitHub Actions CI Is FAILING

**GitHub Actions CI is currently RED even though all 102 local tests pass and ruff is clean locally.** The failure has NOT been diagnosed — the next session MUST:

1. Open `https://github.com/devantaris/SatyaLabel/actions` (or install `gh` CLI and `gh run list --limit 5` / `gh run view <id> --log-failed`) and **inspect the ACTUAL failure logs** — do not assume, do not guess.
2. Likely suspects (unverified hypotheses only — confirm from logs):
   - CI installs `pip install -e ".[dev]"` on Python 3.12 ubuntu — dependency resolution differences (e.g., `opencv-python-headless`, `easyocr`/`torch` wheels)
   - Tesseract presence/path (`TESSERACT_CMD=/usr/bin/tesseract` is set in ci.yml)
   - Tests that depend on behavior which differs on Linux/py3.12 vs local Windows/py3.14
3. Fix the workflow or code accordingly, push, and confirm CI goes green before starting Phase 5.

**Do NOT mark CI as fixed without evidence from the Actions logs.**

---

## 7. Phase 5 Requirements — Flutter Frontend

Build a Flutter mobile app consuming the existing backend. Requirements:

- **Citizen Mode:** anonymous scanning — camera capture → verdict display (COMPLIANT / NON_COMPLIANT / NEEDS_VERIFICATION) with violation list + rule citations; PDF report download; scan history optional
- **Inspector Mode:** login (JWT) → raid **batch scanning** under one `session_id` (the API already accepts `session_id` + binds scans to authenticated users via Bearer token); session history via `GET /scans/?session_id=...`; PDF reports with badge
- **Camera scanning:** image capture → `multipart/form-data` POST to `/api/v1/scans/` (fields: `image`, optional `latitude`, `longitude`, `session_id`) — see `docs/api.md` for exact request/response shapes
- **Offline queue:** queue scans locally when offline, sync on reconnect (the pitch explicitly promises offline capability). Use the sync `POST /scans/` (not `/async`) for queued syncs
- **Integration:** base URL configurable (dev: `http://<host>:8000` — Android emulator needs `10.0.2.2` instead of localhost); Bearer token from `/auth/login`; poll `GET /scans/{id}` if using the async endpoint
- Use `GET /health` for connectivity checks
- No Flutter code, tooling config, or instructions exist in the repo yet — a new `satyalabel_frontend/` (or `flutter_app/`) directory at repo root is the expected location. Check whether the user has Flutter installed before scaffolding (`flutter --version`)

---

## 8. Existing Project / Claude / Flutter Instructions in Repo

- `.claude/settings.local.json` — tool permission allowlist (pytest/ruff/docker/pip/git commands). **Do not overwrite; append only.**
- `.claude/SATYALABEL_HANDOFF.md` — this file
- `.github/workflows/ci.yml` — CI definition
- `docs/roadmap.md` — canonical phase plan; `docs/architecture.md`, `docs/api.md`, `docs/legal_rules_reference.md` — technical references
- `satyalabel_backend/README.md` — project README
- **No CLAUDE.md, no Flutter instructions, no other agent/project instruction files exist.** `legal/` directory is empty.

---

## 9. Commands, Environment, Decisions, Constraints, Known Issues

### Commands (run from `satyalabel_backend/` unless noted)

```bash
# Tests / lint (no live DB needed)
python -m pytest tests/ -q
python -m ruff check app tests alembic

# Local dev server
uvicorn main:app --reload                     # http://localhost:8000/docs

# Celery worker (local)
celery -A app.core.celery_app worker --loglevel=info

# Docker stack
docker compose build
docker compose up -d
docker compose exec api python -m alembic upgrade head
docker compose logs worker -f
docker compose down                           # add -v to wipe volumes

# Migrations (offline SQL preview — no DB)
python -m alembic upgrade head --sql
```

### Environment requirements
- Python ≥3.11; Tesseract OCR binary (`TESSERACT_CMD` — Windows default `C:\Program Files\Tesseract-OCR\tesseract.exe`, Linux `/usr/bin/tesseract`)
- Postgres 16 + PostGIS 3.4, Redis 7 (or the docker stack)
- EasyOCR downloads ~500 MB models on first fallback use (inside worker container too — first async scan is slow, subsequent fast)
- `.env` from `.env.example`; prod requires strong `SECRET_KEY` (startup guard enforces it when `ENV=production`)

### Architectural decisions & constraints
1. Explainable rule engine with legal citations — preserve, never replace with opaque ML verdicts
2. bcrypt directly, NOT passlib (passlib breaks on py3.14)
3. Per-task SQLAlchemy engine in Celery tasks (`scan_tasks._task_session`) — module-level engine is loop-bound
4. Stdlib %-format logging only in services (structlog kwargs crashed the worker once already)
5. Tests run DB-free (mocked sessions in `tests/conftest.py`) — keep new tests DB-free or gate behind live-DB markers
6. Persistence is best-effort in sync scan endpoints (result returned even if DB write fails)
7. Valid `build-backend` is `setuptools.build_meta` (was a bogus legacy path — broke all isolated installs)
8. Scans are anonymous-friendly: auth optional on scan endpoints

### Known issues / gotchas
- **CI failing (see §6) — top priority**
- `gh` CLI not installed; Docker Desktop daemon must be started manually
- `.claude/settings.local.json` shows as modified (uncommitted) — expected
- First EasyOCR use downloads models (slow first async scan)
- Tesseract default path in config is Windows-specific; docker/CI override it
- Ruff `--fix` once mangled an exception variable — review diffs after autofix
- Background Claude subagents in this environment get tool-permission auto-denials — run implementation in the foreground

---

## 10. Recommended Next Steps (in order)

1. **Fix CI (blocking):** read the actual GitHub Actions failure logs (web UI or `gh run view --log-failed`), fix, push, verify green. See §6.
2. **Commit/clean `.claude/settings.local.json`** churn (add to .gitignore or commit as-is).
3. **Phase 5 kickoff:** confirm `flutter --version` is installed; scaffold Flutter app at repo root; implement Citizen Mode (camera → scan → verdict UI) first, then Inspector Mode (login + batch sessions), then offline queue; integrate per `docs/api.md`.
4. **Phase 6:** analytics dashboard (PostGIS heatmap — data model is ready; endpoint planned in `docs/api.md` §Planned).
5. **Phase 7:** production deployment (prod compose without mounted source, nginx/TLS, strong SECRET_KEY, S3 image storage).
6. Optional: populate `legal/` with the full LM(PC) Rules 2011 text if the team wants it in-repo.

---

*End of handoff. Keep this file updated as phases complete.*
