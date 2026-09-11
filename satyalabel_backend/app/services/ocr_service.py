"""
OCR Service for SatyaLabel
===========================
Dual-engine OCR pipeline:
  1. Tesseract  — fast, lightweight, offline-capable (primary)
  2. EasyOCR    — deep-learning, better on noisy/curved labels (fallback)

Selection logic:
  - Run Tesseract first; compute aggregate confidence score.
  - If confidence < OCR_CONFIDENCE_THRESHOLD → also run EasyOCR.
  - Return result from whichever engine produced higher confidence.
  - If both are below OCR_FALLBACK_THRESHOLD → flag for manual correction.

Output:
  OcrResult dataclass containing:
    - raw_text        : Full OCR text (line-joined)
    - lines           : List of OcrLine (text + bounding box + confidence)
    - engine_used     : "tesseract" | "easyocr" | "combined"
    - mean_confidence : Aggregate confidence (0.0–1.0)
    - needs_manual_review: bool (confidence below fallback threshold)
"""
from __future__ import annotations

import logging
import os
from dataclasses import dataclass, field
from typing import List, Literal, Optional

import numpy as np
import pytesseract
from PIL import Image

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
    engine: str                # "tesseract" | "easyocr"


@dataclass
class OcrResult:
    """Full OCR output for one image."""
    raw_text: str
    lines: List[OcrLine]
    engine_used: Literal["tesseract", "easyocr", "combined"]
    mean_confidence: float
    needs_manual_review: bool
    tesseract_confidence: Optional[float] = None
    easyocr_confidence: Optional[float] = None

    @property
    def high_confidence_lines(self) -> List[OcrLine]:
        """Lines with confidence above the threshold."""
        return [l for l in self.lines if l.confidence >= settings.OCR_CONFIDENCE_THRESHOLD]

    @property
    def low_confidence_lines(self) -> List[OcrLine]:
        """Lines flagged for manual review."""
        return [l for l in self.lines if l.confidence < settings.OCR_FALLBACK_THRESHOLD]


# ── OCR Service ───────────────────────────────────────────────────────────────
class OcrService:
    """
    Manages Tesseract + EasyOCR engines with lazy initialisation.
    EasyOCR is expensive to load (~500 MB model), so it is initialised
    on first use rather than at import time.
    """

    def __init__(self):
        self._easyocr_reader = None

    @property
    def easyocr_reader(self):
        """Lazy-load EasyOCR reader (downloads model on first call)."""
        if self._easyocr_reader is None:
            try:
                import easyocr
                logger.info("Loading EasyOCR model (first time may download ~500 MB)…")
                self._easyocr_reader = easyocr.Reader(
                    ["en"],          # English; add "hi" for Hindi when needed
                    gpu=False,       # CPU mode — change to True if GPU available
                    verbose=False,
                )
                logger.info("EasyOCR model loaded successfully")
            except ImportError:
                logger.error("EasyOCR not installed. Run: pip install easyocr")
                raise
        return self._easyocr_reader

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

        # Otherwise fall back to EasyOCR
        logger.info(
            "Tesseract confidence %.2f below threshold %.2f — running EasyOCR fallback",
            tess_result.mean_confidence,
            settings.OCR_CONFIDENCE_THRESHOLD,
        )
        try:
            easy_result = self._run_easyocr(preprocess_result)
            logger.debug(
                "EasyOCR finished",
                confidence=easy_result.mean_confidence,
                lines=len(easy_result.lines),
            )

            # Pick the better result
            if easy_result.mean_confidence >= tess_result.mean_confidence:
                best = easy_result
            else:
                best = tess_result

            best.tesseract_confidence = tess_result.mean_confidence
            best.easyocr_confidence = easy_result.mean_confidence
            best.needs_manual_review = best.mean_confidence < settings.OCR_FALLBACK_THRESHOLD

            if best.needs_manual_review:
                logger.warning(
                    "OCR confidence %.2f is very low — flagging for manual review",
                    best.mean_confidence,
                )

            return best

        except Exception as exc:
            logger.error("EasyOCR failed: %s — falling back to Tesseract result", exc)
            return tess_result

    # ── Tesseract ─────────────────────────────────────────────────────────────

    def _run_tesseract(self, prep: PreprocessResult) -> OcrResult:
        """Run Tesseract on the binarized image and parse per-word confidence data."""
        pil_img = prep.pil_binarized

        # Get detailed data (word-level bounding boxes + confidence)
        data = pytesseract.image_to_data(
            pil_img,
            config=TESSERACT_CONFIG,
            output_type=pytesseract.Output.DICT,
        )

        lines: List[OcrLine] = []
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

        raw_text = "\n".join(l.text for l in lines)
        mean_conf = float(np.mean([l.confidence for l in lines])) if lines else 0.0

        return OcrResult(
            raw_text=raw_text,
            lines=lines,
            engine_used="tesseract",
            mean_confidence=mean_conf,
            needs_manual_review=mean_conf < settings.OCR_FALLBACK_THRESHOLD,
            tesseract_confidence=mean_conf,
        )

    # ── EasyOCR ───────────────────────────────────────────────────────────────

    def _run_easyocr(self, prep: PreprocessResult) -> OcrResult:
        """Run EasyOCR on the colour-processed image."""
        # EasyOCR works best with a colour or greyscale numpy array
        img_array = prep.processed  # BGR ndarray

        raw_detections = self.easyocr_reader.readtext(
            img_array,
            detail=1,          # Return bounding box + text + confidence
            paragraph=False,   # Keep individual text blocks (easier to parse)
        )

        lines: List[OcrLine] = []
        for detection in raw_detections:
            bbox_pts, text, conf = detection
            text = text.strip()
            if not text:
                continue

            # EasyOCR bboxes: [[x1,y1],[x2,y1],[x2,y2],[x1,y2]]
            xs = [pt[0] for pt in bbox_pts]
            ys = [pt[1] for pt in bbox_pts]
            x, y = int(min(xs)), int(min(ys))
            w = int(max(xs)) - x
            h = int(max(ys)) - y

            lines.append(OcrLine(
                text=text,
                confidence=float(conf),
                bbox=(x, y, w, h),
                engine="easyocr",
            ))

        # Sort lines top-to-bottom, then left-to-right (reading order)
        lines.sort(key=lambda l: (l.bbox[1], l.bbox[0]))

        raw_text = "\n".join(l.text for l in lines)
        mean_conf = float(np.mean([l.confidence for l in lines])) if lines else 0.0

        return OcrResult(
            raw_text=raw_text,
            lines=lines,
            engine_used="easyocr",
            mean_confidence=mean_conf,
            needs_manual_review=mean_conf < settings.OCR_FALLBACK_THRESHOLD,
            easyocr_confidence=mean_conf,
        )


# ── Singleton ─────────────────────────────────────────────────────────────────
_ocr_service: Optional[OcrService] = None


def get_ocr_service() -> OcrService:
    """Return the shared OcrService singleton (FastAPI dependency-injectable)."""
    global _ocr_service
    if _ocr_service is None:
        _ocr_service = OcrService()
    return _ocr_service
