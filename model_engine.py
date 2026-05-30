#!/usr/bin/env python3
"""
Model Engine - Core detection logic for Plate Count Reader
Extracted from gradio_app.py for shared use between Gradio UI and REST API
"""

import os
import time
import numpy as np
from pathlib import Path
from datetime import datetime

BASE_DIR = Path(__file__).parent
MODEL_PATH = BASE_DIR / "models" / "best_v4_production.pt"
SAMPLES_DIR = BASE_DIR / "samples"

print("=" * 60)
print("  Plate Count Reader - Model Engine Loading")
print("  Loading model...")
print("=" * 60)

from ultralytics import YOLO

if MODEL_PATH.exists():
    model = YOLO(str(MODEL_PATH))
    print(f"  Model loaded: {MODEL_PATH}")
    print(f"  Task: {model.task}")
    print(f"  Classes: {model.names}")
else:
    print(f"  WARNING: Model not found at {MODEL_PATH}")
    print(f"  Please place model file in models/")
    model = None


def detect_colonies(image, conf_threshold=0.25, iou_threshold=0.45, max_det=1000):
    """
    Detect colonies in an agar plate image.

    Args:
        image: Input image (numpy array)
        conf_threshold: Confidence threshold (0-1)
        iou_threshold: IoU threshold for NMS (0-1)
        max_det: Maximum detections per image

    Returns:
        annotated_image: Image with bounding boxes
        results_dict: Detection results as dictionary
    """
    if model is None:
        return image, {"error": "Model not loaded! Please place model file in models/"}

    if image is None:
        return None, {"error": "No image provided"}

    start_time = time.time()

    results = model(
        image,
        conf=conf_threshold,
        iou=iou_threshold,
        max_det=max_det,
        verbose=False
    )

    elapsed = time.time() - start_time

    annotated = results[0].plot()

    boxes = results[0].boxes
    num_objects = len(boxes)

    class_names = model.names if model else {}

    colony_info = []
    class_counts = {}
    if num_objects > 0:
        confs = boxes.conf.cpu().numpy()
        xyxy = boxes.xyxy.cpu().numpy()
        clss = boxes.cls.cpu().numpy().astype(int)

        for i in range(num_objects):
            x1, y1, x2, y2 = xyxy[i]
            w = x2 - x1
            h = y2 - y1
            area = w * h
            cls_id = clss[i]
            cls_name = class_names.get(cls_id, f"class_{cls_id}")

            colony_info.append({
                "id": i + 1,
                "class_id": int(cls_id),
                "class": cls_name,
                "confidence": round(float(confs[i]), 3),
                "bbox": [round(float(x1), 1), round(float(y1), 1), round(float(x2), 1), round(float(y2), 1)],
                "width": round(float(w), 1),
                "height": round(float(h), 1),
                "area_px": round(float(area), 1),
            })

            class_counts[cls_name] = class_counts.get(cls_name, 0) + 1

        colony_info.sort(key=lambda x: x["confidence"], reverse=True)

        num_colonies = class_counts.get("colony", 0)

        areas = [c["area_px"] for c in colony_info if c["class"] == "colony"]
        conf_values = [c["confidence"] for c in colony_info if c["class"] == "colony"]

        stats = {
            "total_colonies": num_colonies,
            "total_objects": num_objects,
            "class_breakdown": class_counts,
            "avg_confidence": round(float(np.mean(conf_values)), 3) if conf_values else 0,
            "min_confidence": round(float(np.min(conf_values)), 3) if conf_values else 0,
            "max_confidence": round(float(np.max(conf_values)), 3) if conf_values else 0,
            "avg_area_px": round(float(np.mean(areas)), 1) if areas else 0,
            "median_area_px": round(float(np.median(areas)), 1) if areas else 0,
            "total_area_px": round(float(np.sum(areas)), 1) if areas else 0,
            "inference_time_ms": round(elapsed * 1000, 1),
        }
    else:
        stats = {
            "total_colonies": 0,
            "total_objects": 0,
            "class_breakdown": {},
            "inference_time_ms": round(elapsed * 1000, 1),
        }

    return annotated, {"statistics": stats, "colonies": colony_info}


def count_colonies_only(image, conf_threshold=0.25, iou_threshold=0.45):
    """Simple colony counting - returns just the colony count."""
    if model is None or image is None:
        return "N/A"

    results = model(image, conf=conf_threshold, iou=iou_threshold, verbose=False)
    boxes = results[0].boxes

    class_names = model.names
    if len(boxes) > 0:
        clss = boxes.cls.cpu().numpy().astype(int)
        count = sum(1 for c in clss if class_names.get(int(c), "") == "colony")
    else:
        count = 0

    if count == 0:
        return "0 koloni terdeteksi"
    elif count <= 30:
        return f"{count} koloni terdeteksi (TFTC - Too Few To Count)"
    elif count <= 300:
        return f"{count} koloni terdeteksi (IDEAL - dalam range hitung)"
    else:
        return f"{count} koloni terdeteksi (TNTC - Too Numerous To Count)"


def format_results_table(results_dict):
    """Format detection results as a readable text table."""
    if "error" in results_dict:
        return f"Error: {results_dict['error']}"

    stats = results_dict.get("statistics", {})
    colonies = results_dict.get("colonies", [])

    lines = []
    lines.append("=" * 60)
    lines.append("  HASIL DETEKSI AGAR PLATE")
    lines.append("=" * 60)
    lines.append("")

    breakdown = stats.get('class_breakdown', {})
    lines.append("  RINGKASAN DETEKSI PER KELAS:")
    for cls_name, cls_count in sorted(breakdown.items()):
        lines.append(f"    - {cls_name:>12}: {cls_count} objek")
    lines.append("")

    lines.append(f"  Total Koloni:     {stats.get('total_colonies', 0)}")
    lines.append(f"  Total Objek:      {stats.get('total_objects', 0)}")
    lines.append(f"  Waktu Inferensi:  {stats.get('inference_time_ms', 0)} ms")

    if stats.get('total_colonies', 0) > 0:
        lines.append(f"  Rata-rata Conf:   {stats.get('avg_confidence', 0):.3f}")
        lines.append(f"  Min Confidence:   {stats.get('min_confidence', 0):.3f}")
        lines.append(f"  Max Confidence:   {stats.get('max_confidence', 0):.3f}")
        lines.append(f"  Rata-rata Area:   {stats.get('avg_area_px', 0):.0f} px")
        lines.append(f"  Median Area:      {stats.get('median_area_px', 0):.0f} px")
        lines.append("")

        count = stats.get('total_colonies', 0)
        if count <= 30:
            lines.append("  Status: TFTC (Too Few To Count)")
            lines.append("  Catatan: Jumlah koloni terlalu sedikit untuk")
            lines.append("           estimasi yang akurat (< 30 CFU)")
        elif count <= 300:
            lines.append("  Status: IDEAL (Dalam Range Hitung)")
            lines.append("  Catatan: Jumlah koloni ideal untuk estimasi")
            lines.append(f"           CFU (30-300 CFU)")
        else:
            lines.append("  Status: TNTC (Too Numerous To Count)")
            lines.append("  Catatan: Jumlah koloni terlalu banyak (> 300)")
            lines.append("           Perlu pengenceran lebih lanjut")

    if colonies:
        lines.append("")
        lines.append("-" * 60)
        lines.append("  DETAIL OBJEK (Top 20 by confidence):")
        lines.append("-" * 60)
        lines.append(f"  {'No':>3}  {'Class':>10}  {'Conf':>6}  {'Area(px)':>9}  {'BBox':>20}")
        lines.append("-" * 60)

        for c in colonies[:20]:
            bbox_str = f"({c['bbox'][0]:.0f},{c['bbox'][1]:.0f},{c['bbox'][2]:.0f},{c['bbox'][3]:.0f})"
            lines.append(f"  {c['id']:>3}  {c['class']:>10}  {c['confidence']:>6.3f}  {c['area_px']:>9.0f}  {bbox_str:>20}")

        if len(colonies) > 20:
            lines.append(f"  ... dan {len(colonies) - 20} objek lainnya")

    lines.append("")
    lines.append("=" * 60)
    lines.append(f"  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("=" * 60)

    return "\n".join(lines)
