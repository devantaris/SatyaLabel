"""
SatyaLabel Backend — Main FastAPI Application Entry Point
SIH 2026 | Problem Statement SIH26034 | Team: The Hippos
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import router as api_v1_router
from app.core.config import settings

logger = logging.getLogger("satyalabel")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown lifecycle events."""
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


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "ok", "service": "SatyaLabel", "version": settings.VERSION}
