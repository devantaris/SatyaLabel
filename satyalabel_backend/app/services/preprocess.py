"""
Image Pre-Processing Pipeline for SatyaLabel
=============================================
Prepares raw product label photographs for OCR.

Real-world packaged labels suffer from:
  - Tilt / rotation (deskew)
  - Perspective distortion (curved/angled camera)
  - Low contrast / washed out print
  - Specular glare (shiny plastic packaging)
  - Wrinkles and creases

This module applies a sequential pipeline to correct all of the above
before handing the image to the OCR engine. Better pre-processing
quality → dramatically higher OCR accuracy.

Pipeline order:
  1. Load & validate
  2. Resize to standard width (1200px) for consistent processing
  3. Glare detection + masking
  4. Deskew (correct rotation)
  5. Perspective correction (4-point homography) — if auto-detectable
  6. CLAHE contrast enhancement
  7. Adaptive thresholding (for binarized path to Tesseract)
  8. Morphological denoising
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

import cv2
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# ── Constants ─────────────────────────────────────────────────────────────────
TARGET_WIDTH = 1200          # Normalize all images to this width before processing
GLARE_THRESHOLD = 240        # Pixel brightness above which we consider glare
GLARE_DILATE_ITER = 3        # Dilation iterations for glare mask
DESKEW_DELTA = 1             # Degrees step for Hough-based deskew scan
DESKEW_LIMIT = 25            # Max degrees of skew to correct (beyond → likely intentional)
CLAHE_CLIP_LIMIT = 3.0
CLAHE_TILE_GRID = (8, 8)


# ── Result Dataclass ──────────────────────────────────────────────────────────
@dataclass
class PreprocessResult:
    """Holds the pre-processed image variants and diagnostics."""
    original: np.ndarray                  # Original loaded image
    processed: np.ndarray                 # Final processed image (colour)
    binarized: np.ndarray                 # Binarized version (for Tesseract)
    skew_angle: float = 0.0              # Detected skew angle in degrees
    glare_detected: bool = False
    perspective_corrected: bool = False
    warnings: list[str] = field(default_factory=list)

    @property
    def pil_processed(self) -> Image.Image:
        """Return the processed image as a PIL Image (for EasyOCR)."""
        return Image.fromarray(cv2.cvtColor(self.processed, cv2.COLOR_BGR2RGB))

    @property
    def pil_binarized(self) -> Image.Image:
        """Return the binarized image as a PIL Image (greyscale for Tesseract)."""
        return Image.fromarray(self.binarized)


# ── Main Pipeline ─────────────────────────────────────────────────────────────
class ImagePreprocessor:
    """
    Stateless image pre-processing pipeline.

    Usage:
        preprocessor = ImagePreprocessor()
        result = preprocessor.process(image_bytes)
        # result.processed  → colour-corrected ndarray
        # result.binarized  → greyscale binarized ndarray
    """

    def process(self, image_bytes: bytes) -> PreprocessResult:
        """
        Full pre-processing pipeline from raw image bytes → PreprocessResult.

        Args:
            image_bytes: Raw image bytes (JPEG, PNG, WebP, etc.)

        Returns:
            PreprocessResult with processed and binarized image arrays.
        """
        # Step 1: Decode
        img = self._decode(image_bytes)
        original = img.copy()
        warnings: list[str] = []

        # Step 2: Resize to standard width
        img = self._resize_to_width(img, TARGET_WIDTH)

        # Step 3: Glare removal
        glare_detected = self._has_glare(img)
        if glare_detected:
            img = self._remove_glare(img)
            logger.debug("Glare detected and suppressed")

        # Step 4: Deskew
        skew_angle = self._detect_skew(img)
        if abs(skew_angle) > 0.5:
            img = self._rotate(img, skew_angle)
            logger.debug("Deskewed image by %.2f°", skew_angle)

        # Step 5: Perspective correction (best-effort)
        perspective_corrected = False
        corrected = self._try_perspective_correct(img)
        if corrected is not None:
            img = self._resize_to_width(corrected, TARGET_WIDTH)
            perspective_corrected = True
            logger.debug("Perspective correction applied")
        else:
            warnings.append("Perspective correction skipped — could not detect label corners")

        # Step 6: CLAHE contrast enhancement
        img = self._apply_clahe(img)

        # Step 7: Binarize (separate copy — keep colour for EasyOCR)
        binarized = self._binarize(img)

        # Step 8: Morphological denoising on binarized
        binarized = self._denoise(binarized)

        return PreprocessResult(
            original=original,
            processed=img,
            binarized=binarized,
            skew_angle=skew_angle,
            glare_detected=glare_detected,
            perspective_corrected=perspective_corrected,
            warnings=warnings,
        )

    # ── Internal steps ────────────────────────────────────────────────────────

    def _decode(self, image_bytes: bytes) -> np.ndarray:
        """Decode image bytes to BGR ndarray."""
        arr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Could not decode image — unsupported format or corrupt file")
        return img

    def _resize_to_width(self, img: np.ndarray, target_width: int) -> np.ndarray:
        """Resize image to target width, preserving aspect ratio."""
        h, w = img.shape[:2]
        if w == target_width:
            return img
        scale = target_width / w
        new_h = int(h * scale)
        return cv2.resize(img, (target_width, new_h), interpolation=cv2.INTER_LANCZOS4)

    def _has_glare(self, img: np.ndarray) -> bool:
        """Detect if the image has significant glare (bright specular highlights)."""
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        glare_pixels = np.sum(gray > GLARE_THRESHOLD)
        total_pixels = gray.size
        return bool((glare_pixels / total_pixels) > 0.03)  # >3% glare pixels

    def _remove_glare(self, img: np.ndarray) -> np.ndarray:
        """
        Suppress glare by inpainting bright regions.
        Replaces glare spots with neighbourhood-interpolated values.
        """
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        _, glare_mask = cv2.threshold(gray, GLARE_THRESHOLD, 255, cv2.THRESH_BINARY)
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
        glare_mask = cv2.dilate(glare_mask, kernel, iterations=GLARE_DILATE_ITER)
        return cv2.inpaint(img, glare_mask, inpaintRadius=7, flags=cv2.INPAINT_TELEA)

    def _detect_skew(self, img: np.ndarray) -> float:
        """
        Detect image skew angle using Hough line transform on edges.
        Returns the estimated skew angle in degrees (positive = clockwise).
        """
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 50, 150, apertureSize=3)
        lines = cv2.HoughLines(edges, 1, np.pi / 180, threshold=100)

        if lines is None:
            return 0.0

        angles = []
        for line in lines[:50]:  # Use top 50 lines
            rho, theta = line[0]
            angle = np.degrees(theta) - 90
            if abs(angle) < DESKEW_LIMIT:
                angles.append(angle)

        if not angles:
            return 0.0

        # Use median to avoid outlier influence
        return float(np.median(angles))

    def _rotate(self, img: np.ndarray, angle: float) -> np.ndarray:
        """Rotate image by given angle, expanding canvas to avoid cropping."""
        h, w = img.shape[:2]
        cx, cy = w // 2, h // 2
        M = cv2.getRotationMatrix2D((cx, cy), angle, 1.0)

        # Compute new bounding dimensions
        cos_a = abs(M[0, 0])
        sin_a = abs(M[0, 1])
        new_w = int(h * sin_a + w * cos_a)
        new_h = int(h * cos_a + w * sin_a)

        M[0, 2] += (new_w / 2) - cx
        M[1, 2] += (new_h / 2) - cy

        return cv2.warpAffine(
            img, M, (new_w, new_h),
            flags=cv2.INTER_CUBIC,
            borderMode=cv2.BORDER_REPLICATE,
        )

    def _try_perspective_correct(self, img: np.ndarray) -> np.ndarray | None:
        """
        Attempt automatic 4-point perspective correction.
        Finds the largest rectangular contour (assumed to be the label boundary)
        and applies a homography to warp it to a flat rectangle.

        Returns corrected image, or None if no clear rectangle was found.
        """
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        edges = cv2.Canny(blurred, 75, 200)

        contours, _ = cv2.findContours(edges, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
        contours = sorted(contours, key=cv2.contourArea, reverse=True)[:5]

        screen_cnt = None
        for c in contours:
            peri = cv2.arcLength(c, True)
            approx = cv2.approxPolyDP(c, 0.02 * peri, True)
            if len(approx) == 4:
                screen_cnt = approx
                break

        if screen_cnt is None:
            return None

        return self._four_point_transform(img, screen_cnt.reshape(4, 2))

    def _four_point_transform(self, img: np.ndarray, pts: np.ndarray) -> np.ndarray:
        """Apply a 4-point perspective transform to warp the label to a flat rectangle."""
        rect = self._order_points(pts)
        tl, tr, br, bl = rect

        width_a = np.linalg.norm(br - bl)
        width_b = np.linalg.norm(tr - tl)
        max_width = max(int(width_a), int(width_b))

        height_a = np.linalg.norm(tr - br)
        height_b = np.linalg.norm(tl - bl)
        max_height = max(int(height_a), int(height_b))

        dst = np.array([
            [0, 0],
            [max_width - 1, 0],
            [max_width - 1, max_height - 1],
            [0, max_height - 1],
        ], dtype=np.float32)

        M = cv2.getPerspectiveTransform(rect, dst)
        return cv2.warpPerspective(img, M, (max_width, max_height))

    def _order_points(self, pts: np.ndarray) -> np.ndarray:
        """Order 4 points as: top-left, top-right, bottom-right, bottom-left."""
        rect = np.zeros((4, 2), dtype=np.float32)
        s = pts.sum(axis=1)
        rect[0] = pts[np.argmin(s)]   # TL: smallest sum
        rect[2] = pts[np.argmax(s)]   # BR: largest sum
        diff = np.diff(pts, axis=1)
        rect[1] = pts[np.argmin(diff)]  # TR: smallest diff
        rect[3] = pts[np.argmax(diff)]  # BL: largest diff
        return rect

    def _apply_clahe(self, img: np.ndarray) -> np.ndarray:
        """
        Apply CLAHE (Contrast-Limited Adaptive Histogram Equalization) in LAB
        colour space to enhance local contrast while preserving colour.
        """
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        l_chan, a_chan, b_chan = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=CLAHE_CLIP_LIMIT, tileGridSize=CLAHE_TILE_GRID)
        l_chan = clahe.apply(l_chan)
        enhanced = cv2.merge([l_chan, a_chan, b_chan])
        return cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)

    def _binarize(self, img: np.ndarray) -> np.ndarray:
        """
        Convert to greyscale and apply adaptive thresholding.
        Produces a clean black-text-on-white-background image
        that Tesseract performs best on.
        """
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        # Otsu's thresholding after Gaussian blur (good for uniform backgrounds)
        blurred = cv2.GaussianBlur(gray, (3, 3), 0)
        _, otsu = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        # Adaptive thresholding (better for uneven lighting)
        adaptive = cv2.adaptiveThreshold(
            gray, 255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY, 31, 10,
        )
        # Blend: prefer adaptive for local clarity, Otsu for global consistency
        blended = cv2.bitwise_and(otsu, adaptive)
        return blended

    def _denoise(self, binary: np.ndarray) -> np.ndarray:
        """Remove small noise blobs using morphological opening."""
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        opened = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel)
        return opened


# ── Convenience function ──────────────────────────────────────────────────────
_preprocessor = ImagePreprocessor()


def preprocess_image(image_bytes: bytes) -> PreprocessResult:
    """
    Module-level convenience function. Uses a shared ImagePreprocessor instance.

    Args:
        image_bytes: Raw image bytes.

    Returns:
        PreprocessResult with all processed variants.
    """
    return _preprocessor.process(image_bytes)
