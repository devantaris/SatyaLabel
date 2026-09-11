"""
Analytics repository — aggregation queries for the enforcement dashboard.

All queries run against completed scan_records using PostGIS geography
functions and JSONB field extraction. Raw SQL (text()) is used because the
aggregations lean on PostGIS/JSONB operators that are awkward to express in
the ORM layer.
"""
from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

_HEATMAP_SQL = (
    """
    SELECT
        ST_Y(grid_point)  AS latitude,
        ST_X(grid_point)  AS longitude,
        COUNT(*)                                              AS total_scans,
        COUNT(*) FILTER (WHERE verdict = 'NON_COMPLIANT')     AS violations,
        COUNT(*) FILTER (WHERE verdict = 'NEEDS_VERIFICATION') AS needs_verification
    FROM (
        SELECT ST_SnapToGrid(location::geometry, :grid_size) AS grid_point, verdict
        FROM scan_records
        WHERE location IS NOT NULL
          AND status = 'COMPLETED'
          AND created_at >= {since}
    ) g
    GROUP BY grid_point
    HAVING COUNT(*) >= :min_scans
    ORDER BY violations DESC, total_scans DESC
    LIMIT :limit
    """
)

_OFFENDERS_SQL = (
    """
    SELECT
        extracted_fields->'manufacturer'->>'value'                    AS manufacturer,
        COUNT(*)                                                       AS total_scans,
        COUNT(*) FILTER (WHERE verdict = 'NON_COMPLIANT')              AS non_compliant,
        COUNT(*) FILTER (WHERE verdict = 'NEEDS_VERIFICATION')         AS needs_verification,
        COUNT(*) FILTER (WHERE verdict = 'COMPLIANT')                  AS compliant,
        MAX(created_at)                                                AS last_seen
    FROM scan_records
    WHERE status = 'COMPLETED'
      AND verdict IS NOT NULL
      AND extracted_fields->'manufacturer'->>'value' IS NOT NULL
      AND created_at >= {since}
    GROUP BY 1
    HAVING COUNT(*) >= :min_scans
    ORDER BY non_compliant DESC, total_scans DESC
    LIMIT :limit
    """
)

_DISTRICT_SQL = (
    """
    SELECT
        u.district                                                      AS district,
        COUNT(*)                                                        AS total_scans,
        COUNT(*) FILTER (WHERE s.verdict = 'NON_COMPLIANT')             AS non_compliant,
        COUNT(*) FILTER (WHERE s.verdict = 'NEEDS_VERIFICATION')        AS needs_verification,
        COUNT(DISTINCT s.user_id)                                       AS contributors
    FROM scan_records s
    JOIN users u ON u.id = s.user_id
    WHERE s.status = 'COMPLETED'
      AND s.verdict IS NOT NULL
      AND u.district IS NOT NULL
      AND s.created_at >= {since}
    GROUP BY u.district
    ORDER BY non_compliant DESC, total_scans DESC
    """
)

_OVERVIEW_SQL = (
    """
    SELECT
        COUNT(*)                                                       AS total_scans,
        COUNT(*) FILTER (WHERE verdict = 'NON_COMPLIANT')              AS non_compliant,
        COUNT(*) FILTER (WHERE verdict = 'NEEDS_VERIFICATION')         AS needs_verification,
        COUNT(*) FILTER (WHERE verdict = 'COMPLIANT')                  AS compliant,
        COUNT(*) FILTER (WHERE needs_review)                           AS needs_review,
        COUNT(DISTINCT session_id) FILTER (WHERE session_id IS NOT NULL) AS sessions,
        COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '24 hours') AS scans_24h
    FROM scan_records
    WHERE status = 'COMPLETED'
      AND created_at >= {since}
    """
)

_EXPORT_SQL = (
    """
    SELECT
        s.id                                                    AS scan_id,
        s.created_at                                            AS created_at,
        s.verdict                                               AS verdict,
        s.violation_count                                       AS violation_count,
        s.session_id                                            AS session_id,
        s.needs_review                                          AS needs_review,
        s.extracted_fields->'manufacturer'->>'value'            AS manufacturer,
        s.extracted_fields->'mrp'->>'value'                     AS mrp,
        s.extracted_fields->'net_quantity'->>'value'            AS net_quantity,
        s.extracted_fields->'country_of_origin'->>'value'       AS country_of_origin,
        ST_Y(s.location::geometry)                              AS latitude,
        ST_X(s.location::geometry)                              AS longitude,
        u.district                                              AS district
    FROM scan_records s
    LEFT JOIN users u ON u.id = s.user_id
    WHERE s.status = 'COMPLETED'
      AND s.created_at >= {since}
    ORDER BY s.created_at DESC
    LIMIT :limit
    """
)


def _row_to_dict(row) -> dict:
    """Convert an asyncpg RowMapping to a plain dict."""
    return dict(row._mapping) if hasattr(row, "_mapping") else dict(row)


async def get_heatmap(
    session: AsyncSession,
    *,
    grid_size: float = 0.05,
    min_scans: int = 1,
    days: int | None = None,
    limit: int = 500,
) -> list[dict]:
    """Violation heatmap: scan counts binned to a lat/lon grid.

    grid_size is in degrees (0.05 ≈ 5 km at the equator).
    """
    result = await session.execute(
        text(_HEATMAP_SQL.format(since=_since_clause(days))),
        {
            "grid_size": grid_size,
            "min_scans": min_scans,
            "limit": limit,
        },
    )
    rows = result.mappings().all()
    return [
        {
            "latitude": round(float(r["latitude"]), 6),
            "longitude": round(float(r["longitude"]), 6),
            "total_scans": r["total_scans"],
            "violations": r["violations"],
            "needs_verification": r["needs_verification"],
            "violation_rate": (
                round(r["violations"] / r["total_scans"], 3)
                if r["total_scans"]
                else 0.0
            ),
        }
        for r in rows
    ]


async def get_repeat_offenders(
    session: AsyncSession,
    *,
    min_scans: int = 2,
    days: int | None = None,
    limit: int = 50,
) -> list[dict]:
    """Manufacturers aggregated across all scans, worst offenders first."""
    result = await session.execute(
        text(_OFFENDERS_SQL.format(since=_since_clause(days))),
        {"min_scans": min_scans, "limit": limit},
    )
    rows = result.mappings().all()
    return [
        {
            "manufacturer": r["manufacturer"],
            "total_scans": r["total_scans"],
            "non_compliant": r["non_compliant"],
            "needs_verification": r["needs_verification"],
            "compliant": r["compliant"],
            "last_seen": r["last_seen"].isoformat() if r["last_seen"] else None,
        }
        for r in rows
    ]


async def get_district_stats(
    session: AsyncSession,
    *,
    days: int | None = None,
) -> list[dict]:
    """Scan activity grouped by the scanning user's district."""
    result = await session.execute(text(_DISTRICT_SQL.format(since=_since_clause(days))))
    return [_row_to_dict(r) for r in result.mappings().all()]


async def get_overview(session: AsyncSession, *, days: int | None = None) -> dict:
    """Dashboard headline numbers."""
    result = await session.execute(text(_OVERVIEW_SQL.format(since=_since_clause(days))))
    row = result.mappings().first()
    return _row_to_dict(row) if row else {
        "total_scans": 0,
        "non_compliant": 0,
        "needs_verification": 0,
        "compliant": 0,
        "needs_review": 0,
        "sessions": 0,
        "scans_24h": 0,
    }


async def get_export_rows(
    session: AsyncSession,
    *,
    days: int | None = None,
    limit: int = 10000,
) -> list[dict]:
    """Flat scan rows for CSV export (legal-action evidence bundles)."""
    result = await session.execute(
        text(_EXPORT_SQL.format(since=_since_clause(days))), {"limit": limit}
    )
    return [_row_to_dict(r) for r in result.mappings().all()]


def _since_clause(days: int | None) -> str:
    """SQL timestamp expression for the lookback window.

    days is int-cast before interpolation, so the clause is injection-safe.
    """
    if days is None:
        return "'1970-01-01'::timestamptz"
    return f"NOW() - INTERVAL '{int(days)} days'"
