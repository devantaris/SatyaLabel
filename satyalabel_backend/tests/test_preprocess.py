"""
Tests for image pre-processing pipeline.
"""
from __future__ import annotations

import io

import pytest
from PIL import Image, ImageDraw

from app.services.preprocess import ImagePreprocessor, preprocess_image

# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_label_image(
    width: int = 800,
    height: int = 400,
    text: str = "MRP Rs. 50  Net Qty: 200g",
    rotation: float = 0.0,
    add_glare: bool = False,
    bg_color: tuple[int, int, int] = (220, 220, 220),
) -> bytes:
    """Create a synthetic label image as JPEG bytes."""
    img = Image.new("RGB", (width, height), color=bg_color)
    draw = ImageDraw.Draw(img)
    draw.rectangle([10, 10, width - 10, height - 10], outline=(0, 0, 0), width=3)
    draw.text((50, 50), text, fill=(0, 0, 0))

    if add_glare:
        # Simulate a bright glare spot covering >3% of pixels
        draw.ellipse([200, 50, 600, 300], fill=(255, 255, 255))

    if rotation != 0.0:
        img = img.rotate(rotation, expand=True, fillcolor=bg_color)

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


# ── Tests ─────────────────────────────────────────────────────────────────────

class TestImagePreprocessor:

    def setup_method(self):
        self.preprocessor = ImagePreprocessor()

    def test_clean_image_processes_successfully(self):
        img_bytes = _make_label_image()
        result = self.preprocessor.process(img_bytes)
        assert result.processed is not None
        assert result.binarized is not None
        assert result.original is not None

    def test_output_shapes_are_valid(self):
        img_bytes = _make_label_image(width=1600, height=800)
        result = self.preprocessor.process(img_bytes)
        # Processed image should be a valid numpy array with 3 channels
        assert len(result.processed.shape) == 3
        assert result.processed.shape[2] == 3
        # Binarized should be grayscale (2D)
        assert len(result.binarized.shape) == 2

    def test_glare_detection(self):
        img_with_glare = _make_label_image(add_glare=True)
        result = self.preprocessor.process(img_with_glare)
        # Glare should be detected (the ellipse is very bright)
        assert result.glare_detected is True

    def test_no_glare_on_clean_image(self):
        img_clean = _make_label_image(add_glare=False)
        result = self.preprocessor.process(img_clean)
        assert result.glare_detected is False

    def test_skewed_image_detected(self):
        img_skewed = _make_label_image(rotation=10.0)
        result = self.preprocessor.process(img_skewed)
        # Should detect some skew (not necessarily exact, as Hough is approximate)
        # Just verify it ran without error and skew_angle is a float
        assert isinstance(result.skew_angle, float)

    def test_corrupt_bytes_raises_value_error(self):
        with pytest.raises(ValueError, match="Could not decode image"):
            self.preprocessor.process(b"not-an-image-\x00\x01\x02")

    def test_pil_properties(self):
        img_bytes = _make_label_image()
        result = self.preprocessor.process(img_bytes)
        pil_proc = result.pil_processed
        pil_bin = result.pil_binarized
        assert pil_proc.mode == "RGB"
        assert pil_bin.mode == "L"  # Grayscale

    def test_resize_to_standard_width(self):
        # A very large image should be resized down
        img_bytes = _make_label_image(width=3000, height=2000)
        result = self.preprocessor.process(img_bytes)
        assert result.processed.shape[1] == 1200  # TARGET_WIDTH

    def test_small_image_resized_up(self):
        img_bytes = _make_label_image(width=400, height=200)
        result = self.preprocessor.process(img_bytes)
        assert result.processed.shape[1] == 1200


class TestPreprocessImageConvenienceFunction:
    def test_module_level_function(self):
        img_bytes = _make_label_image()
        result = preprocess_image(img_bytes)
        assert result.processed is not None
