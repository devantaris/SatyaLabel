"""
Celery scan tasks — run the OCR pipeline off the request path.

Worker: celery -A app.core.celery_app worker --loglevel=info

NOTE on async handling: Celery tasks are synchronous. Each task creates
its OWN SQLAlchemy async engine + session inside a single asyncio.run()
call. The module-level engine in app.core.database binds its pool to
the first event loop it touches, so reusing it across separate
asyncio.run() calls raises "Future attached to a different loop".
"""
from __future__ import annotations

import asyncio
import logging

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.celery_app import celery_app
from app.core.config import settings
from app.services.scan_pipeline import run_scan_pipeline
from app.services.scan_repository import complete_scan, fail_scan, mark_scan_processing
from app.services.storage import get_storage

logger = logging.getLogger(__name__)


async def _task_session():
    """Create a per-task engine + session (context manager)."""
    engine = create_async_engine(settings.DATABASE_URL, pool_pre_ping=True)

    class _SessionCtx:
        async def __aenter__(self):
            self.session = async_sessionmaker(
                engine, expire_on_commit=False
            )()
            return self.session

        async def __aexit__(self, *exc):
            try:
                if exc[0] is None:
                    await self.session.commit()
                else:
                    await self.session.rollback()
            finally:
                await self.session.close()
                await engine.dispose()
            return False

    return _SessionCtx()


def _run_pipeline_and_persist(scan_id: str, image_path: str) -> dict:
    """Run pipeline and persist results in one loop, one session."""
    image_bytes = get_storage().read(image_path)

    result = run_scan_pipeline(image_bytes, scan_id=scan_id)
    report = result.compliance_report

    async def _persist():
        async with await _task_session() as session:
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
                    "perspective_corrected": result.preprocess_result.perspective_corrected,
                    "warnings": result.preprocess_result.warnings,
                },
                needs_review=report.needs_manual_review,
            )

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
    try:
        asyncio.run(_mark_processing(scan_id))
    except Exception:
        logger.exception("Could not mark scan %s as PROCESSING", scan_id)

    try:
        response = _run_pipeline_and_persist(scan_id, image_path)
        logger.info("Async scan %s completed: %s", scan_id, response.get("verdict"))
        return response
    except Exception as exc:
        logger.exception("Async scan %s failed", scan_id)
        error_msg = str(exc)
        try:
            asyncio.run(_mark_failed(scan_id, error_msg))
        except Exception:
            logger.exception("Could not mark scan %s as FAILED", scan_id)
        raise


async def _mark_processing(scan_id: str) -> None:
    async with await _task_session() as session:
        await mark_scan_processing(session, scan_id)


async def _mark_failed(scan_id: str, error_msg: str) -> None:
    async with await _task_session() as session:
        await fail_scan(session, scan_id, error_msg)
