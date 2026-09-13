"""
SatyaLabel Backend — Main FastAPI Application Entry Point
SIH 2026 | Problem Statement SIH26034 | Team: The Hippos
"""
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.api.v1 import router as api_v1_router
from app.core.config import settings

logger = logging.getLogger("satyalabel")

UPLOAD_DIR = settings.UPLOAD_DIR
STATIC_DIR = Path(__file__).parent / "app" / "static"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown lifecycle events."""
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    if settings.ENV == "production" and settings.SECRET_KEY.startswith("change-me"):
        raise RuntimeError(
            "SECRET_KEY must be set to a strong random value in production "
            "(generate with: openssl rand -hex 32)."
        )
    logger.info("SatyaLabel backend starting up - version %s", settings.VERSION)
    yield
    logger.info("SatyaLabel backend shutting down")


app = FastAPI(
    title="SatyaLabel API",
    description=(
        "Legal Metrology Packaged Commodity Compliance Scanner — "
        "SIH 2026 | SIH26034 | Team: The Hippos"
    ),
    version=settings.VERSION,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_v1_router, prefix="/api/v1")

# Images are served directly by FastAPI only for the local-storage backend;
# S3 storage serves them from the bucket (public base or presigned URLs).
if settings.STORAGE_BACKEND == "local":
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    app.mount(
        "/uploads",
        StaticFiles(directory=UPLOAD_DIR),
        name="uploads",
    )


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "ok", "service": "SatyaLabel", "version": settings.VERSION}


@app.get("/dashboard", include_in_schema=False)
async def enforcement_dashboard():
    """Interactive Consumer Affairs dashboard (heatmap, offenders, districts)."""
    return FileResponse(STATIC_DIR / "dashboard.html")
