"""
Celery scan tasks — run the OCR pipeline off the request path.

Worker: celery -A app.core.celery_app worker --loglevel=info
"""
from __future__ import annotations

import logging
import os

from app.core.celery_app import celery_app
from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.services.scan_pipeline import run_scan_pipeline
from app.services.scan_repository import complete_scan, fail_scan, mark_scan_processing

logger = logging.getLogger(__name__)


def _run_pipeline_and_persist(scan_id: str, image_path: str) -> dict:
    """Shared logic: run pipeline, persist results, return API response dict."""
    with open(os.path.join(settings.UPLOAD_DIR, image_path), "rb") as f:
        image_bytes = f.read()

    result = run_scan_pipeline(image_bytes, scan_id=scan_id)

    report = result.compliance_report
    import asyncio

    async def _persist():
        async with AsyncSessionLocal() as session:
            try:
                await complete_scan(
                    session,
                    scan_id,
                    verdict=report.verdict.value,
                    violation_count=report.violation_count,
                    ocr_engine=result.ocr_result.engine_used,
                    ocr_confidence=round(result.ocr_result.mean_confidence, 3),
                    extracted_fields=result.extracted_fields.as_dict(),
                    compliance_data=report.as_dict(),
                    preprocess_diagnostics={
                        "skew_angle": round(result.preprocess_result.skew_angle, 2),
                        "glare_detected": result.preprocess_result.glare_detected,
                        "perspective_corrected": (
                            result.preprocess_result.perspective_corrected
                        ),
                        "warnings": result.preprocess_result.warnings,
                    },
                    needs_review=report.needs_manual_review,
                )
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    asyncio.run(_persist())
    return result.to_api_response()


@celery_app.task(
    bind=True,
    name="satyalabel.process_scan",
    autoretry_for=(ConnectionError,),
    retry_kwargs={"max_retries": 2, "countdown": 5},
)
def process_scan_task(self, scan_id: str, image_path: str) -> dict:
    """
    Process a submitted label image: mark PROCESSING, run the pipeline,
    persist results. On failure the scan is marked FAILED.
    """
    import asyncio

    # Mark PROCESSING (best-effort)
    async def _mark():
        async with AsyncSessionLocal() as session:
            try:
                await mark_scan_processing(session, scan_id)
                await session.commit()
            except Exception:
                await session.rollback()

    try:
        asyncio.run(_mark())
        response = _run_pipeline_and_persist(scan_id, image_path)
        logger.info("Async scan %s completed: %s", scan_id, response.get("verdict"))
        return response
    except Exception as exc:
        logger.exception("Async scan %s failed", scan_id)
        error_msg = str(exc)

        async def _fail():
            async with AsyncSessionLocal() as session:
                try:
                    await fail_scan(session, scan_id, error_msg)
                    await session.commit()
                except Exception:
                    await session.rollback()

        try:
            asyncio.run(_fail())
        except Exception:
            logger.exception("Could not mark scan %s as FAILED", scan_id)
        raise
