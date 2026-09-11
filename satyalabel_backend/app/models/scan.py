"""
SQLAlchemy model for a product label scan record.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from geoalchemy2 import Geography
from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User


class ScanRecord(Base):
    """
    Stores every product label scan result.

    Columns:
        id              : UUID primary key
        user_id         : FK to User (inspector or citizen)
        image_path      : Relative path to saved image file
        verdict         : COMPLIANT / NON_COMPLIANT / NEEDS_VERIFICATION
        violation_count : Number of critical violations
        ocr_engine      : "tesseract" | "easyocr" | "combined"
        ocr_confidence  : Mean OCR confidence (0.0–1.0)
        extracted_fields: JSONB — all 10 extracted field values
        compliance_data : JSONB — full ComplianceReport.as_dict()
        location        : PostGIS Geography point (longitude, latitude)
        address_hint    : Optional reverse-geocoded address string
        needs_review    : True if flagged for manual correction
        created_at      : Timestamp
    """
    __tablename__ = "scan_records"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True
    )
    session_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)

    # Image storage
    image_path: Mapped[str | None] = mapped_column(String(512), nullable=True)

    # Processing status: PENDING | PROCESSING | COMPLETED | FAILED
    status: Mapped[str] = mapped_column(
        String(32), nullable=False, default="COMPLETED", index=True
    )

    # Results (verdict is NULL until the async pipeline completes)
    verdict: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    violation_count: Mapped[int] = mapped_column(Integer, default=0)
    ocr_engine: Mapped[str | None] = mapped_column(String(32))
    ocr_confidence: Mapped[float | None] = mapped_column(Float)

    # JSON payloads
    extracted_fields: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    compliance_data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    preprocess_diagnostics: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    # Geo-tagging (PostGIS) — nullable for offline/no-GPS scans
    location: Mapped[object | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326), nullable=True
    )
    address_hint: Mapped[str | None] = mapped_column(String(512), nullable=True)

    # Status flags
    needs_review: Mapped[bool] = mapped_column(Boolean, default=False)
    report_generated: Mapped[bool] = mapped_column(Boolean, default=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )

    # Relationships
    user: Mapped[User | None] = relationship("User", back_populates="scans", lazy="joined")
