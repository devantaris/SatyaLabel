"""
Analytics API Routes (inspector/admin only)
============================================
GET /api/v1/analytics/overview       — dashboard headline numbers
GET /api/v1/analytics/heatmap        — PostGIS violation heatmap (grid-binned)
GET /api/v1/analytics/manufacturers  — repeat-offender manufacturer aggregation
GET /api/v1/analytics/districts      — district-level scan statistics
GET /api/v1/analytics/export         — CSV export of scan evidence (legal action)
"""
from __future__ import annotations

import csv
import io
import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_inspector
from app.services import analytics_repository as analytics

logger = logging.getLogger(__name__)

router = APIRouter(dependencies=[Depends(get_current_inspector)])


def _validate_days(days: int | None) -> None:
    if days is not None and days < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="days must be >= 1.",
        )


@router.get("/overview", summary="Dashboard headline statistics")
async def analytics_overview(
    days: int | None = Query(None, description="Lookback window in days (all time if omitted)"),
    db: AsyncSession = Depends(get_db),
):
    """Totals: scans by verdict, needs-review count, active sessions, 24 h volume."""
    _validate_days(days)
    return await analytics.get_overview(db, days=days)


@router.get("/heatmap", summary="Violation heatmap (PostGIS grid-binned)")
async def analytics_heatmap(
    grid_size: float = Query(0.05, gt=0, le=5, description="Grid cell size in degrees (~0.05 = 5 km)"),
    min_scans: int = Query(1, ge=1, description="Minimum scans per cell to include"),
    days: int | None = Query(None, description="Lookback window in days"),
    limit: int = Query(500, ge=1, le=2000),
    db: AsyncSession = Depends(get_db),
):
    """Geo-tagged scan counts binned to a lat/lon grid, worst cells first.

    Only scans with GPS coordinates are included; cells with fewer than
    min_scans are dropped.
    """
    _validate_days(days)
    points = await analytics.get_heatmap(
        db, grid_size=grid_size, min_scans=min_scans, days=days, limit=limit
    )
    return {"points": points, "grid_size": grid_size, "count": len(points)}


@router.get("/manufacturers", summary="Repeat-offender manufacturer aggregation")
async def analytics_manufacturers(
    min_scans: int = Query(2, ge=1, description="Minimum scans to be listed"),
    days: int | None = Query(None, description="Lookback window in days"),
    limit: int = Query(50, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
):
    """Manufacturers ranked by non-compliant scan counts (legal follow-up list)."""
    _validate_days(days)
    items = await analytics.get_repeat_offenders(
        db, min_scans=min_scans, days=days, limit=limit
    )
    return {"items": items, "count": len(items)}


@router.get("/districts", summary="District-level scan statistics")
async def analytics_districts(
    days: int | None = Query(None, description="Lookback window in days"),
    db: AsyncSession = Depends(get_db),
):
    """Scans aggregated by the recording user's district."""
    _validate_days(days)
    items = await analytics.get_district_stats(db, days=days)
    return {"items": items, "count": len(items)}


@router.get("/export", summary="CSV export of scan evidence")
async def analytics_export_csv(
    days: int | None = Query(None, description="Lookback window in days"),
    limit: int = Query(10000, ge=1, le=100000),
    db: AsyncSession = Depends(get_db),
):
    """Flat CSV of completed scans for legal-action evidence bundles."""
    _validate_days(days)
    rows = await analytics.get_export_rows(db, days=days, limit=limit)

    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow([
        "scan_id", "created_at", "verdict", "violation_count", "session_id",
        "needs_review", "manufacturer", "mrp", "net_quantity",
        "country_of_origin", "latitude", "longitude", "district",
    ])
    for row in rows:
        writer.writerow([
            row["scan_id"],
            row["created_at"].isoformat() if isinstance(row["created_at"], datetime) else row["created_at"],
            row["verdict"],
            row["violation_count"],
            row["session_id"] or "",
            bool(row["needs_review"]),
            row["manufacturer"] or "",
            row["mrp"] or "",
            row["net_quantity"] or "",
            row["country_of_origin"] or "",
            f"{row['latitude']:.6f}" if row["latitude"] is not None else "",
            f"{row['longitude']:.6f}" if row["longitude"] is not None else "",
            row["district"] or "",
        ])

    stamp = datetime.now(UTC).strftime("%Y%m%d")
    return Response(
        content=buffer.getvalue(),
        media_type="text/csv",
        headers={
            "Content-Disposition": f'attachment; filename="satyalabel_evidence_{stamp}.csv"'
        },
    )
