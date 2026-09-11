"""
Scan API Routes
================
POST /api/v1/scans/          — Submit image for compliance scan (persisted)
POST /api/v1/scans/report    — Scan + return court-ready PDF report (persisted)
GET  /api/v1/scans/{id}      — Retrieve a persisted scan result by ID
GET  /api/v1/scans/          — List scans (paginated, filterable)
"""
from __future__ import annotations

import logging
import os
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.security import get_optional_user
from app.services.report_generator import generate_inspection_pdf
from app.services.scan_pipeline import run_scan_pipeline
from app.services.scan_repository import (
    complete_scan,
    create_pending_scan,
    get_scan,
    list_scans,
    save_scan,
    scan_to_dict,
)

logger = logging.getLogger(__name__)

router = APIRouter()

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_BYTES = settings.MAX_IMAGE_SIZE_MB * 1024 * 1024

MIME_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
}


def _validate_image(image: UploadFile, image_bytes: bytes) -> None:
    """Shared validation for scan endpoints. Raises HTTPException on failure."""
    if image.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported image format '{image.content_type}'. "
                   f"Accepted: JPEG, PNG, WebP.",
        )
    if len(image_bytes) > MAX_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image too large ({len(image_bytes) / 1024 / 1024:.1f} MB). "
                   f"Maximum: {settings.MAX_IMAGE_SIZE_MB} MB.",
        )
    if len(image_bytes) < 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image appears to be corrupt or empty (< 1 KB).",
        )


def _save_image_file(scan_id: str, image_bytes: bytes, content_type: str) -> str:
    """Store the uploaded image under UPLOAD_DIR/{scan_id}{ext}. Returns filename."""
    upload_dir = settings.UPLOAD_DIR
    os.makedirs(upload_dir, exist_ok=True)
    ext = MIME_EXTENSIONS.get(content_type, ".jpg")
    filename = f"{scan_id}{ext}"
    path = os.path.join(upload_dir, filename)
    with open(path, "wb") as f:
        f.write(image_bytes)
    return filename


async def _persist_scan(
    db: AsyncSession,
    scan_id: str,
    result,
    image_bytes: bytes,
    content_type: str,
    latitude: float | None,
    longitude: float | None,
    session_id: str | None,
    report_generated: bool,
    user_id=None,
) -> dict:
    """Save image + ScanRecord, return the persisted scan dict."""
    filename = _save_image_file(scan_id, image_bytes, content_type)

    report = result.compliance_report
    record = await save_scan(
        db,
        scan_id=scan_id,
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
        image_path=filename,
        session_id=session_id,
        user_id=user_id,
        latitude=latitude,
        longitude=longitude,
        needs_review=report.needs_manual_review,
        report_generated=report_generated,
    )
    return scan_to_dict(record)


@router.post(
    "/",
    summary="Submit product label image for compliance scan",
    status_code=status.HTTP_200_OK,
)
async def create_scan(
    image: UploadFile = File(..., description="Product label photo (JPEG/PNG/WebP)"),
    latitude: float | None = Form(None, description="GPS latitude of scan location"),
    longitude: float | None = Form(None, description="GPS longitude of scan location"),
    session_id: str | None = Form(None, description="Inspector batch session ID"),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_optional_user),
):
    """
    Run the full compliance scan pipeline on an uploaded product label image.

    Returns the compliance verdict, extracted fields, violations, and diagnostics.
    The result is persisted and retrievable via GET /scans/{scan_id}.
    If a valid Bearer token is supplied, the scan is bound to that user.
    """
    _validate_image(image, image_bytes := await image.read())

    # Run pipeline
    try:
        scan_id = str(uuid.uuid4())
        result = run_scan_pipeline(image_bytes, scan_id=scan_id)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image processing failed: {e}",
        )
    except Exception:
        logger.exception("Unexpected error in scan pipeline")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal scan error. Please try again.",
        )

    response = result.to_api_response()

    # Persist (best-effort: scan result still returned if persistence fails)
    try:
        record_dict = await _persist_scan(
            db, scan_id, result, image_bytes, image.content_type,
            latitude, longitude, session_id, report_generated=False,
            user_id=user.id if user else None,
        )
        response["status"] = "COMPLETED"
        response["created_at"] = record_dict["created_at"]
        response["image_url"] = record_dict["image_url"]
    except Exception:
        logger.exception("Failed to persist scan record")

    # Attach geo data if provided
    if latitude is not None and longitude is not None:
        response["location"] = {"latitude": latitude, "longitude": longitude}

    if session_id:
        response["session_id"] = session_id

    return JSONResponse(content=response)


@router.post(
    "/async",
    summary="Submit label image for async processing (202 + polling)",
    status_code=status.HTTP_202_ACCEPTED,
)
async def create_scan_async(
    image: UploadFile = File(..., description="Product label photo (JPEG/PNG/WebP)"),
    latitude: float | None = Form(None, description="GPS latitude of scan location"),
    longitude: float | None = Form(None, description="GPS longitude of scan location"),
    session_id: str | None = Form(None, description="Inspector batch session ID"),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_optional_user),
):
    """
    Submit a scan for background processing by the Celery worker.

    Returns immediately with scan_id + status PENDING. Poll
    GET /scans/{scan_id} until status is COMPLETED or FAILED.
    Falls back to synchronous processing if the task queue is unavailable.
    """
    _validate_image(image, image_bytes := await image.read())

    scan_id = str(uuid.uuid4())
    filename = _save_image_file(scan_id, image_bytes, image.content_type)

    # Create PENDING record so the client can poll immediately
    try:
        record = await create_pending_scan(
            db,
            scan_id=scan_id,
            image_path=filename,
            session_id=session_id,
            latitude=latitude,
            longitude=longitude,
            user_id=user.id if user else None,
        )
        created_at = record.created_at.isoformat() if record.created_at else None
    except Exception:
        logger.exception("Failed to create pending scan record")
        created_at = None

    # Dispatch to Celery; fall back to sync if broker unavailable
    try:
        from app.core.scan_tasks import process_scan_task

        process_scan_task.delay(scan_id, filename)
        dispatched = True
    except Exception:
        logger.exception("Celery dispatch failed — falling back to synchronous scan")
        dispatched = False

    if not dispatched:
        # Synchronous fallback: run inline (blocks this request)
        try:
            result = run_scan_pipeline(image_bytes, scan_id=scan_id)
        except Exception:
            logger.exception("Fallback sync scan failed")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Internal scan error. Please try again.",
            )
        response = result.to_api_response()
        response["status"] = "COMPLETED"
        try:
            report = result.compliance_report
            await complete_scan(
                db,
                scan_id,
                verdict=report.verdict.value,
                violation_count=report.violation_count,
                ocr_engine=result.ocr_result.engine_used,
                ocr_confidence=round(result.ocr_result.mean_confidence, 3),
                extracted_fields=result.extracted_fields.as_dict(),
                compliance_data=report.as_dict(),
                preprocess_diagnostics={},
                needs_review=report.needs_manual_review,
            )
        except Exception:
            logger.exception("Fallback persistence failed")
        return JSONResponse(status_code=status.HTTP_202_ACCEPTED, content=response)

    return JSONResponse(
        status_code=status.HTTP_202_ACCEPTED,
        content={
            "scan_id": scan_id,
            "status": "PENDING",
            "message": "Scan accepted for processing. Poll GET /api/v1/scans/{scan_id}.",
            "session_id": session_id,
            "created_at": created_at,
        },
    )


@router.post(
    "/report",
    summary="Scan label and return court-ready PDF report",
    response_class=Response,
)
async def generate_scan_pdf_report(
    image: UploadFile = File(..., description="Product label photo"),
    inspector_badge: str | None = Form("INSP-DL-2026-084"),
    inspector_name: str | None = Form("Legal Metrology Inspector"),
    location_hint: str | None = Form(None),
    db: AsyncSession = Depends(get_db),
):
    """
    Process image and directly return the downloadable official PDF Inspection Report.
    """
    image_bytes = await image.read()
    _validate_image(image, image_bytes)

    try:
        scan_id = str(uuid.uuid4())
        pipeline_result = run_scan_pipeline(image_bytes, scan_id=scan_id)
    except Exception:
        logger.exception("Unexpected error in scan pipeline (report)")
        raise HTTPException(status_code=500, detail="Internal scan error. Please try again.")

    pdf_bytes = generate_inspection_pdf(
        compliance_report=pipeline_result.compliance_report,
        scan_id=scan_id,
        image_bytes=image_bytes,
        inspector_badge=inspector_badge,
        inspector_name=inspector_name,
        location_hint=location_hint,
    )

    # Persist (best-effort)
    try:
        await _persist_scan(
            db, scan_id, pipeline_result, image_bytes, image.content_type,
            None, None, None, report_generated=True,
        )
    except Exception:
        logger.exception("Failed to persist scan record (report)")

    filename = f"SatyaLabel_Evidence_{scan_id[:8]}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get(
    "/",
    summary="List scans (paginated, filterable)",
)
async def list_scans_endpoint(
    limit: int = 50,
    offset: int = 0,
    verdict: str | None = None,
    session_id: str | None = None,
    needs_review: bool | None = None,
    created_after: datetime | None = None,
    created_before: datetime | None = None,
    db: AsyncSession = Depends(get_db),
):
    """
    List persisted scans, newest first.

    Filters: verdict, session_id, needs_review, created_after/created_before (ISO datetime).
    Pagination: limit (max 100), offset.
    """
    if verdict is not None and verdict not in {"COMPLIANT", "NON_COMPLIANT", "NEEDS_VERIFICATION"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verdict filter. Must be COMPLIANT, NON_COMPLIANT, or NEEDS_VERIFICATION.",
        )
    if limit < 1 or offset < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="limit must be >= 1 and offset must be >= 0.",
        )

    records, total = await list_scans(
        db,
        limit=limit,
        offset=offset,
        verdict=verdict,
        session_id=session_id,
        needs_review=needs_review,
        created_after=created_after,
        created_before=created_before,
    )
    return {
        "items": [scan_to_dict(r) for r in records],
        "total": total,
        "limit": min(limit, 100),
        "offset": offset,
    }


@router.get(
    "/{scan_id}",
    summary="Retrieve a scan result by ID",
)
async def get_scan_by_id(scan_id: str, db: AsyncSession = Depends(get_db)):
    """
    Retrieve a previously completed scan result.
    """
    record = await get_scan(db, scan_id)
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Scan '{scan_id}' not found.",
        )
    return scan_to_dict(record)
