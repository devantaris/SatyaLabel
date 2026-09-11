"""
API v1 router — aggregates all route modules.
"""
from fastapi import APIRouter

from app.api.v1.scans import router as scans_router

router = APIRouter()
router.include_router(scans_router, prefix="/scans", tags=["Scans"])
