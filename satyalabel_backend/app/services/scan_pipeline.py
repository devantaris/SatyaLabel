"""
Scan Pipeline — orchestrates the full camera→OCR→rules→report flow.
"""
from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass

from app.services.field_extractor import ExtractedFields, extract_fields
from app.services.ocr_service import OcrResult, get_ocr_service
from app.services.preprocess import PreprocessResult, preprocess_image
from app.services.rule_engine import ComplianceReport, check_compliance

logger = logging.getLogger(__name__)


@dataclass
class ScanPipelineResult:
    """Full result from a single scan run."""
    scan_id: str
    preprocess_result: PreprocessResult
    ocr_result: OcrResult
    extracted_fields: ExtractedFields
    compliance_report: ComplianceReport

    def to_api_response(self) -> dict:
        return {
            "scan_id": self.scan_id,
            "verdict": self.compliance_report.verdict.value,
            "summary": self.compliance_report.summary_text(),
            "needs_manual_review": self.compliance_report.needs_manual_review,
            "ocr": {
                "engine_used": self.ocr_result.engine_used,
                "mean_confidence": round(self.ocr_result.mean_confidence, 3),
                "raw_text": self.ocr_result.raw_text,
            },
            "extracted_fields": self.extracted_fields.as_dict(),
            "compliance": self.compliance_report.as_dict(),
            "preprocess_diagnostics": {
                "skew_angle": round(self.preprocess_result.skew_angle, 2),
                "glare_detected": self.preprocess_result.glare_detected,
                "perspective_corrected": self.preprocess_result.perspective_corrected,
                "warnings": self.preprocess_result.warnings,
            },
        }


class ScanPipeline:
    """
    Orchestrates the end-to-end scan pipeline:
      Image bytes → Pre-process → OCR → Field Extraction → Compliance Check
    """

    def run(self, image_bytes: bytes, scan_id: str | None = None) -> ScanPipelineResult:
        """
        Run the full pipeline on raw image bytes.

        Args:
            image_bytes: Raw image data from camera or upload.
            scan_id: Optional pre-assigned scan ID (generated if not provided).

        Returns:
            ScanPipelineResult with all intermediate and final results.
        """
        if scan_id is None:
            scan_id = str(uuid.uuid4())

        logger.info("Starting scan pipeline scan_id=%s image_size=%d", scan_id, len(image_bytes))

        # Step 1: Pre-process
        prep = preprocess_image(image_bytes)
        logger.debug("Pre-processing done scan_id=%s skew=%.2f", scan_id, prep.skew_angle)

        # Step 2: OCR
        ocr_svc = get_ocr_service()
        ocr_result = ocr_svc.run(prep)
        logger.debug(
            "OCR done scan_id=%s engine=%s conf=%.3f",
            scan_id, ocr_result.engine_used, ocr_result.mean_confidence,
        )

        # Step 3: Field extraction
        fields = extract_fields(ocr_result)
        logger.debug("Fields extracted scan_id=%s", scan_id)

        # Step 4: Compliance check
        report = check_compliance(fields, ocr_needs_review=ocr_result.needs_manual_review)
        logger.info(
            "Scan complete scan_id=%s verdict=%s violations=%d",
            scan_id, report.verdict.value, report.violation_count,
        )

        return ScanPipelineResult(
            scan_id=scan_id,
            preprocess_result=prep,
            ocr_result=ocr_result,
            extracted_fields=fields,
            compliance_report=report,
        )


_pipeline = ScanPipeline()


def run_scan_pipeline(image_bytes: bytes, scan_id: str | None = None) -> ScanPipelineResult:
    """Module-level convenience function."""
    return _pipeline.run(image_bytes, scan_id)
