"""
OCR Service for SatyaLabel
===========================
Dual-engine OCR pipeline:
  1. Tesseract — fast, lightweight, offline-capable (primary)
  2. RapidOCR  — PaddleOCR models via ONNX Runtime; deep-learning
                 quality at ~100 MB RAM (fallback for hard photos)

Selection logic:
  - Run Tesseract first; compute aggregate confidence score.
  - If confidence < OCR_CONFIDENCE_THRESHOLD → also run RapidOCR.
  - Return result from whichever engine produced higher confidence.
  - If both are below OCR_FALLBACK_THRESHOLD → flag for manual correction.

Output:
  OcrResult dataclass containing:
    - raw_text        : Full OCR text (line-joined)
    - lines           : List of OcrLine (text + bounding box + confidence)
    - engine_used     : "tesseract" | "rapidocr" | "combined"
    - mean_confidence : Aggregate confidence (0.0–1.0)
    - needs_manual_review: bool (confidence below fallback threshold)
"""
from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from typing import Literal

import numpy as np
import pytesseract

from app.core.config import settings
from app.services.preprocess import PreprocessResult

logger = logging.getLogger(__name__)

# ── Tesseract config ──────────────────────────────────────────────────────────
# Set executable path (Windows requires explicit path)
if os.path.exists(settings.TESSERACT_CMD):
    pytesseract.pytesseract.tesseract_cmd = settings.TESSERACT_CMD

# PSM 3: Fully automatic page segmentation (best for labels)
# PSM 6: Assume a single uniform block of text (try if PSM 3 struggles)
TESSERACT_CONFIG = "--oem 3 --psm 3 -l eng"


# ── Data Classes ──────────────────────────────────────────────────────────────
@dataclass
class OcrLine:
    """A single detected text line with position and confidence."""
    text: str
    confidence: float          # 0.0–1.0
    bbox: tuple[int, int, int, int]  # (x, y, w, h)
    engine: str                # "tesseract" | "rapidocr"


@dataclass
class OcrResult:
    """Full OCR output for one image."""
    raw_text: str
    lines: list[OcrLine]
    engine_used: Literal["tesseract", "rapidocr", "combined", "mlkit"]
    mean_confidence: float
    needs_manual_review: bool
    tesseract_confidence: float | None = None
    fallback_confidence: float | None = None

    @classmethod
    def from_client_text(cls, text: str) -> OcrResult:
        """Build an OcrResult from OCR text produced on the client device
        (Google ML Kit on-device recognition in the mobile app). Field
        extraction and the rule engine run unchanged on this text."""
        clean_lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
        return cls(
            raw_text="\n".join(clean_lines),
            lines=[
                OcrLine(text=ln, confidence=0.9, bbox=(0, 0, 0, 0), engine="mlkit")
                for ln in clean_lines
            ],
            engine_used="mlkit",
            mean_confidence=0.9 if clean_lines else 0.0,
            needs_manual_review=False,
        )

    @property
    def high_confidence_lines(self) -> list[OcrLine]:
        """Lines with confidence above the threshold."""
        return [ln for ln in self.lines if ln.confidence >= settings.OCR_CONFIDENCE_THRESHOLD]

    @property
    def low_confidence_lines(self) -> list[OcrLine]:
        """Lines flagged for manual review."""
        return [ln for ln in self.lines if ln.confidence < settings.OCR_FALLBACK_THRESHOLD]


# ── OCR Service ───────────────────────────────────────────────────────────────
class OcrService:
    """
    Manages Tesseract + RapidOCR engines with lazy initialisation.
    RapidOCR loads its ONNX models on first use rather than at import time.
    """

    def __init__(self):
        self._rapidocr = None

    @property
    def rapidocr(self):
        """Lazy-load RapidOCR engine (PaddleOCR detection+recognition via ONNX)."""
        if self._rapidocr is None:
            try:
                from rapidocr_onnxruntime import RapidOCR
                logger.info("Loading RapidOCR (ONNX models, first use)…")
                self._rapidocr = RapidOCR()
                logger.info("RapidOCR loaded successfully")
            except ImportError:
                logger.error("RapidOCR not installed. Run: pip install rapidocr-onnxruntime")
                raise
        return self._rapidocr

    # ── Public API ─────────────────────────────────────────────────────────────

    def run(self, preprocess_result: PreprocessResult) -> OcrResult:
        """
        Run the OCR pipeline on a pre-processed image.

        Args:
            preprocess_result: Output from the ImagePreprocessor.

        Returns:
            OcrResult with extracted text, per-line data, and confidence scores.
        """
        # Always run Tesseract first (fast)
        tess_result = self._run_tesseract(preprocess_result)
        logger.debug(
            "Tesseract finished",
            confidence=tess_result.mean_confidence,
            lines=len(tess_result.lines),
        )

        # If Tesseract is confident enough, return it directly
        if tess_result.mean_confidence >= settings.OCR_CONFIDENCE_THRESHOLD:
            return tess_result

        # Deep-learning fallback — can be disabled via config
        if not settings.RAPIDOCR_ENABLED:
            return tess_result

        logger.info(
            "Tesseract confidence %.2f below threshold %.2f — running RapidOCR fallback",
            tess_result.mean_confidence,
            settings.OCR_CONFIDENCE_THRESHOLD,
        )
        try:
            fallback_result = self._run_rapidocr(preprocess_result)
            logger.debug(
                "RapidOCR finished",
                confidence=fallback_result.mean_confidence,
                lines=len(fallback_result.lines),
            )

            # Pick the better result
            if fallback_result.mean_confidence >= tess_result.mean_confidence:
                best = fallback_result
            else:
                best = tess_result

            best.tesseract_confidence = tess_result.mean_confidence
            best.fallback_confidence = fallback_result.mean_confidence
            best.needs_manual_review = best.mean_confidence < settings.OCR_FALLBACK_THRESHOLD

            if best.needs_manual_review:
                logger.warning(
                    "OCR confidence %.2f is very low — flagging for manual review",
                    best.mean_confidence,
                )

            return best

        except Exception as exc:
            logger.error("RapidOCR failed: %s — falling back to Tesseract result", exc)
            return tess_result

    # ── Tesseract ─────────────────────────────────────────────────────────────

    def _run_tesseract(self, prep: PreprocessResult) -> OcrResult:
        """Run Tesseract on the contrast-enhanced grayscale image and parse per-word confidence data."""
        pil_img = prep.pil_ocr_gray

        # Get detailed data (word-level bounding boxes + confidence)
        data = pytesseract.image_to_data(
            pil_img,
            config=TESSERACT_CONFIG,
            output_type=pytesseract.Output.DICT,
        )

        lines: list[OcrLine] = []
        line_buffer: dict[int, dict] = {}  # key: line_num

        for i in range(len(data["text"])):
            text = data["text"][i].strip()
            conf_raw = int(data["conf"][i])
            if conf_raw < 0 or not text:
                continue

            conf = conf_raw / 100.0
            x, y, w, h = data["left"][i], data["top"][i], data["width"][i], data["height"][i]
            line_num = data["line_num"][i]
            block_num = data["block_num"][i]

            key = (block_num, line_num)
            if key not in line_buffer:
                line_buffer[key] = {"words": [], "confs": [], "x": x, "y": y, "w": w, "h": h}

            buf = line_buffer[key]
            buf["words"].append(text)
            buf["confs"].append(conf)
            # Expand bounding box
            buf["w"] = max(buf["x"] + buf["w"], x + w) - buf["x"]
            buf["h"] = max(buf["y"] + buf["h"], y + h) - buf["y"]

        for buf in line_buffer.values():
            if not buf["words"]:
                continue
            line_text = " ".join(buf["words"])
            mean_conf = float(np.mean(buf["confs"]))
            lines.append(OcrLine(
                text=line_text,
                confidence=mean_conf,
                bbox=(buf["x"], buf["y"], buf["w"], buf["h"]),
                engine="tesseract",
            ))

        raw_text = "\n".join(ln.text for ln in lines)
        mean_conf = float(np.mean([ln.confidence for ln in lines])) if lines else 0.0

        return OcrResult(
            raw_text=raw_text,
            lines=lines,
            engine_used="tesseract",
            mean_confidence=mean_conf,
            needs_manual_review=mean_conf < settings.OCR_FALLBACK_THRESHOLD,
            tesseract_confidence=mean_conf,
        )

    # ── RapidOCR ───────────────────────────────────────────────────────────────

    def _run_rapidocr(self, prep: PreprocessResult) -> OcrResult:
        """Run RapidOCR (PaddleOCR ONNX models) on the colour-processed image."""
        img_array = prep.processed  # BGR ndarray

        raw_detections, _ = self.rapidocr(img_array)
        if raw_detections is None:
            raw_detections = []

        lines: list[OcrLine] = []
        for detection in raw_detections:
            bbox_pts, text, conf = detection
            text = text.strip()
            if not text:
                continue

            # RapidOCR bboxes: [[x1,y1],[x2,y1],[x2,y2],[x1,y2]]
            xs = [pt[0] for pt in bbox_pts]
            ys = [pt[1] for pt in bbox_pts]
            x, y = int(min(xs)), int(min(ys))
            w = int(max(xs)) - x
            h = int(max(ys)) - y

            lines.append(OcrLine(
                text=text,
                confidence=float(conf),
                bbox=(x, y, w, h),
                engine="rapidocr",
            ))

        # Sort lines top-to-bottom, then left-to-right (reading order)
        lines.sort(key=lambda ln: (ln.bbox[1], ln.bbox[0]))

        # Merge detections on the same visual row (two-column labels put
        # the field name on the left and the value on the right, detected
        # as separate boxes). Center-distance tolerance of 0.7 × line
        # height absorbs mild tilt without collapsing distinct rows.
        lines = self._merge_same_row(lines)

        raw_text = "\n".join(ln.text for ln in lines)
        mean_conf = float(np.mean([ln.confidence for ln in lines])) if lines else 0.0

        return OcrResult(
            raw_text=raw_text,
            lines=lines,
            engine_used="rapidocr",
            mean_confidence=mean_conf,
            needs_manual_review=mean_conf < settings.OCR_FALLBACK_THRESHOLD,
            fallback_confidence=mean_conf,
        )

    @staticmethod
    def _merge_same_row(lines: list[OcrLine]) -> list[OcrLine]:
        """Merge vertically-aligned detections into single left-to-right lines."""
        rows: list[dict] = []
        for ln in lines:
            x, y, w, h = ln.bbox
            cy = y + h / 2
            if rows and abs(cy - rows[-1]["cy"]) <= 0.7 * max(h, rows[-1]["h"]):
                rows[-1]["cy"] = (rows[-1]["cy"] + cy) / 2
                rows[-1]["h"] = max(h, rows[-1]["h"])
                rows[-1]["lines"].append(ln)
            else:
                rows.append({"cy": cy, "h": h, "lines": [ln]})

        merged: list[OcrLine] = []
        for row in rows:
            group = sorted(row["lines"], key=lambda ln: ln.bbox[0])
            x0 = min(ln.bbox[0] for ln in group)
            y0 = min(ln.bbox[1] for ln in group)
            x1 = max(ln.bbox[0] + ln.bbox[2] for ln in group)
            y1 = max(ln.bbox[1] + ln.bbox[3] for ln in group)
            merged.append(OcrLine(
                text=" ".join(ln.text for ln in group),
                confidence=float(np.mean([ln.confidence for ln in group])),
                bbox=(x0, y0, x1 - x0, y1 - y0),
                engine="rapidocr",
            ))
        return merged


# ── Singleton ─────────────────────────────────────────────────────────────────
_ocr_service: OcrService | None = None


def get_ocr_service() -> OcrService:
    """Return the shared OcrService singleton (FastAPI dependency-injectable)."""
    global _ocr_service
    if _ocr_service is None:
        _ocr_service = OcrService()
    return _ocr_service
