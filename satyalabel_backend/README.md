# SatyaLabel

**Camera-scan compliance checker for packaged-commodity labels under the Legal Metrology (Packaged Commodities) Rules, 2011.**

Smart India Hackathon 2026 · Problem Statement SIH26034 · Team The Hippos

![CI](https://github.com/devantaris/SatyaLabel/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-blue)
![Python](https://img.shields.io/badge/python-3.11%2B-blue)
![Tests](https://img.shields.io/badge/tests-102%20passing-brightgreen)

## The Problem

Every packaged product in India must legally declare MRP, net quantity, manufacture date, expiry, manufacturer details, consumer-care contacts and more. Inspectors verify these by reading each label manually — minutes per product, hundreds of products per raid. SatyaLabel turns that into a camera scan that takes seconds, produces an explainable verdict with legal citations, and generates a court-ready PDF evidence report.

## How It Works

```
Camera image
     │
     ▼
┌──────────────┐   ┌───────────────────┐   ┌──────────────────┐
│  Pre-process │──▶│        OCR        │──▶│  Field Extractor │
│ (OpenCV:     │   │ Tesseract primary │   │ (regex patterns  │
│  deskew,     │   │ EasyOCR fallback  │   │  for 10 mandatory│
│  de-glare,   │   │ confidence-based  │   │  declarations)   │
│  perspective)│   │  engine choice    │   │                  │
└──────────────┘   └───────────────────┘   └────────┬─────────┘
                                                     │
                     ┌───────────────────┐           ▼
                     │   PDF Evidence    │◀──┌──────────────────┐
                     │     Report        │   │   Rule Engine    │
                     │  (ReportLab,      │   │ LM(PC) Rules '11 │
                     │   photo embedded) │   │ explainable      │
                     └───────────────────┘   │ verdict + cites  │
                                             └──────────────────┘
```

**Design principle: EXPLAINABLE over MAGICAL.** No "AI says non-compliant" — the engine says: `VIOLATION — MRP declaration not found on label. Required per Rule 6(1)(f) of LM(PC) Rules, 2011.`

## Features

- **Dual-engine OCR** — Tesseract first; falls back to EasyOCR when confidence < 0.60; flags manual review below 0.40
- **10 mandatory declarations** extracted with per-field confidence scores
- **Explainable rule engine** — every violation cites the specific Legal Metrology rule
- **Cross-field checks** — e.g. Best-Before must be after Manufacture date (the "Marie Gold" check)
- **Court-ready PDF reports** with embedded photo evidence
- **Async processing** — Celery + Redis, 202-accepted + polling flow
- **PostgreSQL + PostGIS** — geo-tagged scans, GiST-indexed for heatmaps
- **JWT auth** — citizen / inspector / admin roles

## Tech Stack

| Layer | Technology |
|---|---|
| API | FastAPI, Uvicorn |
| OCR | Tesseract, EasyOCR |
| Imaging | OpenCV, Pillow, scikit-image |
| Async jobs | Celery, Redis |
| Database | PostgreSQL 16 + PostGIS (SQLAlchemy 2 async, Alembic) |
| Reports | ReportLab, Jinja2 |
| Auth | python-jose (JWT), bcrypt |
| Tests | pytest (102 tests) |

## Quickstart (local)

Prerequisites: Python 3.11+, [Tesseract OCR](https://github.com/UB-Mannheim/tesseract/wiki) installed, PostgreSQL with PostGIS, Redis.

```bash
cd satyalabel_backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -e ".[dev]"

cp .env.example .env        # then edit TESSERACT_CMD and DB URLs

# DB migrations
python -m alembic upgrade head

# Start API
uvicorn main:app --reload   # http://localhost:8000/docs

# Start Celery worker (separate terminal, for async scans)
celery -A app.core.celery_app worker --loglevel=info
```

## Quickstart (Docker)

```bash
cd satyalabel_backend
docker compose up            # API :8000, worker, Postgres/PostGIS :5432, Redis :6379
docker compose exec api python -m alembic upgrade head
```

## API Overview

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/scans/` | Scan a label image → verdict + violations (sync) |
| POST | `/api/v1/scans/async` | Submit for background processing → 202 + polling |
| GET | `/api/v1/scans/{id}` | Retrieve a persisted scan result |
| GET | `/api/v1/scans/` | List scans (paginated, filterable) |
| POST | `/api/v1/scans/report` | Scan + download court-ready PDF report |
| POST | `/api/v1/auth/register` | Create account (citizen) |
| POST | `/api/v1/auth/login` | Get JWT bearer token |
| GET | `/api/v1/auth/me` | Current user profile |
| GET | `/health` | Service health check |

Full request/response examples: [docs/api.md](../docs/api.md) · Interactive docs: `/docs` (Swagger UI)

```bash
curl -X POST http://localhost:8000/api/v1/scans/ \
  -F "image=@label.jpg" \
  -F "latitude=28.6139" -F "longitude=77.2090"
```

## Testing & Lint

```bash
python -m pytest tests/ -q        # 102 tests, no live DB needed
python -m ruff check app tests alembic
```

## Project Structure

```
satyalabel_backend/
├── alembic/                  # migrations (users, scan_records, PostGIS)
├── app/
│   ├── api/v1/               # routes: scans, auth
│   ├── core/                 # config, database, security, celery, tasks
│   ├── models/               # SQLAlchemy: User, ScanRecord
│   ├── schemas/              # Pydantic request/response models
│   └── services/             # pipeline: preprocess, ocr, field_extractor,
│                             #   rule_engine, report_generator, repository
├── benchmarks/               # OCR accuracy benchmarking harness
├── tests/                    # 102 tests (unit + API, mocked DB)
├── docker-compose.yml        # api + worker + postgres/postgis + redis
└── Dockerfile
```

## Roadmap

- [x] Core pipeline (preprocess → OCR → extract → rules → PDF)
- [x] Persistence + Alembic + GET endpoints
- [x] Async Celery processing (202 + polling)
- [x] JWT auth with roles
- [ ] Rate limiting, API keys for production
- [ ] Mobile frontend (Inspector Mode, offline scan queue)
- [ ] Admin analytics dashboard (violation heatmaps on PostGIS)
- [ ] Production deployment (nginx, TLS, S3 image storage)

## License

MIT
