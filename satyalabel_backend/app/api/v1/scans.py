"""
Scan API Routes
================
POST /api/v1/scans/          — Submit image for compliance scan
GET  /api/v1/scans/{id}      — Retrieve a scan result by ID
GET  /api/v1/scans/          — List scans (paginated; inspector-only filters)
"""
from __future__ import annotations

import io
import logging
import uuid
from typing import Optional

from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse, Response

from app.core.config import settings
from app.services.scan_pipeline import run_scan_pipeline
from app.services.report_generator import generate_inspection_pdf

logger = logging.getLogger(__name__)

router = APIRouter()

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_BYTES = settings.MAX_IMAGE_SIZE_MB * 1024 * 1024


@router.post(
    "/",
    summary="Submit product label image for compliance scan",
    status_code=status.HTTP_200_OK,
)
async def create_scan(
    image: UploadFile = File(..., description="Product label photo (JPEG/PNG/WebP)"),
    latitude: Optional[float] = Form(None, description="GPS latitude of scan location"),
    longitude: Optional[float] = Form(None, description="GPS longitude of scan location"),
    session_id: Optional[str] = Form(None, description="Inspector batch session ID"),
):
    """
    Run the full compliance scan pipeline on an uploaded product label image.

    Returns the compliance verdict, extracted fields, violations, and diagnostics.
    """
    # Validate file type
    if image.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported image format '{image.content_type}'. "
                   f"Accepted: JPEG, PNG, WebP.",
        )

    # Read and size-check
    image_bytes = await image.read()
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

    # Run pipeline
    try:
        scan_id = str(uuid.uuid4())
        result = run_scan_pipeline(image_bytes, scan_id=scan_id)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image processing failed: {e}",
        )
    except Exception as e:
        logger.exception("Unexpected error in scan pipeline")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal scan error. Please try again.",
        )

    response = result.to_api_response()

    # Attach geo data if provided
    if latitude is not None and longitude is not None:
        response["location"] = {"latitude": latitude, "longitude": longitude}

    if session_id:
        response["session_id"] = session_id

    return JSONResponse(content=response)


@router.post(
    "/report",
    summary="Scan label and return court-ready PDF report",
    response_class=Response,
)
async def generate_scan_pdf_report(
    image: UploadFile = File(..., description="Product label photo"),
    inspector_badge: Optional[str] = Form("INSP-DL-2026-084"),
    inspector_name: Optional[str] = Form("Legal Metrology Inspector"),
    location_hint: Optional[str] = Form(None),
):
    """
    Process image and directly return the downloadable official PDF Inspection Report.
    """
    image_bytes = await image.read()
    if len(image_bytes) > MAX_BYTES or len(image_bytes) < 1024:
        raise HTTPException(status_code=400, detail="Invalid image payload.")

    scan_id = str(uuid.uuid4())
    pipeline_result = run_scan_pipeline(image_bytes, scan_id=scan_id)

    pdf_bytes = generate_inspection_pdf(
        compliance_report=pipeline_result.compliance_report,
        scan_id=scan_id,
        image_bytes=image_bytes,
        inspector_badge=inspector_badge,
        inspector_name=inspector_name,
        location_hint=location_hint,
    )

    filename = f"SatyaLabel_Evidence_{scan_id[:8]}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get(
    "/{scan_id}",
    summary="Retrieve a scan result by ID",
)
async def get_scan(scan_id: str):
    """
    Retrieve a previously completed scan result.
    (In Phase 3, this will query the database. For now returns a placeholder.)
    """
    # TODO Phase 3: query ScanRecord from DB
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Database persistence coming in Phase 3. "
               "Scan results are available immediately in the POST /scans response.",
    )
