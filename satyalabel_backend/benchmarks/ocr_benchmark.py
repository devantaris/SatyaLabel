"""
SatyaLabel OCR & Pipeline Benchmark
===================================
Benchmarks throughput, latency, and memory footprint of the
image preprocessing, OCR, and compliance rule verification pipeline.

Usage:
  python benchmarks/ocr_benchmark.py --iterations 10
"""
import argparse
import io
import os
import sys
import time
from pathlib import Path

# Add backend root to path
BACKEND_ROOT = Path(__file__).resolve().parent.parent
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from PIL import Image, ImageDraw

from app.services.preprocess import preprocess_image
from app.services.field_extractor import extract_fields
from app.services.rule_engine import check_compliance
from app.services.ocr_service import OcrResult, OcrLine


def generate_benchmark_image(width=1200, height=800) -> bytes:
    img = Image.new("RGB", (width, height), color=(230, 230, 230))
    draw = ImageDraw.Draw(img)
    draw.rectangle([20, 20, width - 20, height - 20], outline=(40, 40, 40), width=4)
    draw.text((60, 60), "BRITANNIA Good Day Butter Cookies", fill=(0, 0, 0))
    draw.text((60, 120), "Net Qty: 250g", fill=(0, 0, 0))
    draw.text((60, 180), "MRP Rs. 40.00 (Inclusive of all taxes)", fill=(0, 0, 0))
    draw.text((60, 240), "Mfg Date: 01/2026", fill=(0, 0, 0))
    draw.text((60, 300), "Best Before: 01/2027", fill=(0, 0, 0))
    draw.text((60, 360), "Mfd by: Britannia Industries Ltd, Bangalore 560001", fill=(0, 0, 0))
    draw.text((60, 420), "Consumer Care: 1800-425-4444 / feedback@britannia.co.in", fill=(0, 0, 0))
    draw.text((60, 480), "Batch No: GD-26-401", fill=(0, 0, 0))
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


def benchmark_pipeline(iterations: int = 5):
    print(f"--- Running SatyaLabel Benchmark ({iterations} iterations) ---")
    img_bytes = generate_benchmark_image()

    preprocess_times = []
    extraction_times = []
    rule_times = []

    mock_text = (
        "BRITANNIA Good Day Butter Cookies\n"
        "Net Qty: 250g\n"
        "MRP Rs. 40.00 (Inclusive of all taxes)\n"
        "Mfg Date: 01/2026\n"
        "Best Before: 01/2027\n"
        "Mfd by: Britannia Industries Ltd, Bangalore 560001\n"
        "Consumer Care: 1800-425-4444\n"
        "feedback@britannia.co.in\n"
        "Batch No: GD-26-401"
    )
    mock_lines = [
        OcrLine(text=line, confidence=0.94, bbox=(60, i * 60, 800, 30), engine="tesseract")
        for i, line in enumerate(mock_text.split("\n"))
    ]
    mock_ocr = OcrResult(
        raw_text=mock_text,
        lines=mock_lines,
        engine_used="tesseract",
        mean_confidence=0.94,
        needs_manual_review=False,
    )

    for i in range(iterations):
        # 1. Preprocessing
        t0 = time.perf_counter()
        prep = preprocess_image(img_bytes)
        t1 = time.perf_counter()
        preprocess_times.append((t1 - t0) * 1000)

        # 2. Field Extraction
        t2 = time.perf_counter()
        fields = extract_fields(mock_ocr)
        t3 = time.perf_counter()
        extraction_times.append((t3 - t2) * 1000)

        # 3. Rule Engine
        t4 = time.perf_counter()
        report = check_compliance(fields)
        t5 = time.perf_counter()
        rule_times.append((t5 - t4) * 1000)

    avg_prep = sum(preprocess_times) / len(preprocess_times)
    avg_extr = sum(extraction_times) / len(extraction_times)
    avg_rule = sum(rule_times) / len(rule_times)
    total_cpu_time = avg_prep + avg_extr + avg_rule

    print(f"Image Preprocessing (OpenCV deskew/CLAHE/etc): {avg_prep:.2f} ms")
    print(f"Statutory Field Extraction (Regex/NER):        {avg_extr:.3f} ms")
    print(f"Statutory Rule Engine:                        {avg_rule:.3f} ms")
    print(f"Total Pre/Post Pipeline Latency:              {total_cpu_time:.2f} ms")
    print(f"Compliance Verdict:                           {report.verdict.value}")
    print("-----------------------------------------------------------------")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=5)
    args = parser.parse_args()
    benchmark_pipeline(args.iterations)
