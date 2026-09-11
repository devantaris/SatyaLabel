"""
Scan Repository — DB access layer for ScanRecord persistence.

Kept separate from the API layer so endpoints stay thin and
tests can mock the session. All functions are async and take
an AsyncSession as first argument.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.scan import ScanRecord

logger = logging.getLogger(__name__)


def build_location_column(latitude: float | None, longitude: float | None):
    """Build a PostGIS POINT geography from lat/long, or None."""
    if latitude is None or longitude is None:
        return None
    return func.ST_SetSRID(
        func.ST_MakePoint(longitude, latitude), 4326
    )


async def save_scan(
    session: AsyncSession,
    *,
    scan_id: str,
    verdict: str,
    violation_count: int,
    ocr_engine: str | None,
    ocr_confidence: float | None,
    extracted_fields: dict | None,
    compliance_data: dict | None,
    preprocess_diagnostics: dict | None,
    image_path: str | None = None,
    session_id: str | None = None,
    user_id: uuid.UUID | None = None,
    latitude: float | None = None,
    longitude: float | None = None,
    address_hint: str | None = None,
    needs_review: bool = False,
    report_generated: bool = False,
) -> ScanRecord:
    """Persist a completed scan. Caller manages commit via get_db."""
    record = ScanRecord(
        id=uuid.UUID(scan_id),
        verdict=verdict,
        violation_count=violation_count,
        ocr_engine=ocr_engine,
        ocr_confidence=ocr_confidence,
        extracted_fields=extracted_fields,
        compliance_data=compliance_data,
        preprocess_diagnostics=preprocess_diagnostics,
        image_path=image_path,
        session_id=session_id,
        user_id=user_id,
        address_hint=address_hint,
        needs_review=needs_review,
        report_generated=report_generated,
    )
    if latitude is not None and longitude is not None:
        record.location = build_location_column(latitude, longitude)
    session.add(record)
    await session.flush()
    return record


async def get_scan(session: AsyncSession, scan_id: str) -> ScanRecord | None:
    """Fetch a single scan by ID, or None."""
    try:
        sid = uuid.UUID(scan_id)
    except (ValueError, AttributeError):
        return None
    result = await session.execute(select(ScanRecord).where(ScanRecord.id == sid))
    return result.scalar_one_or_none()


async def list_scans(
    session: AsyncSession,
    *,
    limit: int = 50,
    offset: int = 0,
    verdict: str | None = None,
    session_id: str | None = None,
    needs_review: bool | None = None,
    created_after: datetime | None = None,
    created_before: datetime | None = None,
) -> tuple[list[ScanRecord], int]:
    """
    Paginated scan listing with optional filters.
    Returns (records, total_count_matching_filters).
    """
    query = select(ScanRecord)
    count_query = select(func.count(ScanRecord.id))

    conditions = []
    if verdict is not None:
        conditions.append(ScanRecord.verdict == verdict)
    if session_id is not None:
        conditions.append(ScanRecord.session_id == session_id)
    if needs_review is not None:
        conditions.append(ScanRecord.needs_review == needs_review)
    if created_after is not None:
        conditions.append(ScanRecord.created_at >= created_after)
    if created_before is not None:
        conditions.append(ScanRecord.created_at <= created_before)

    for cond in conditions:
        query = query.where(cond)
        count_query = count_query.where(cond)

    total_result = await session.execute(count_query)
    total = total_result.scalar() or 0

    query = (
        query.order_by(ScanRecord.created_at.desc())
        .limit(min(limit, 100))
        .offset(offset)
    )
    result = await session.execute(query)
    records = list(result.scalars().all())
    return records, total


def scan_to_dict(record: ScanRecord) -> dict:
    """Serialize a ScanRecord to an API-friendly dict."""
    return {
        "scan_id": str(record.id),
        "status": "COMPLETED",
        "verdict": record.verdict,
        "violation_count": record.violation_count,
        "ocr_engine": record.ocr_engine,
        "ocr_confidence": record.ocr_confidence,
        "extracted_fields": record.extracted_fields,
        "compliance": record.compliance_data,
        "preprocess_diagnostics": record.preprocess_diagnostics,
        "session_id": record.session_id,
        "needs_review": record.needs_review,
        "report_generated": record.report_generated,
        "image_url": f"/uploads/{record.image_path.rsplit('/', 1)[-1]}" if record.image_path else None,
        "created_at": record.created_at.isoformat() if record.created_at else None,
    }
