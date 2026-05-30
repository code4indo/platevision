#!/usr/bin/env python3
"""
Production Training V4 - YOLOv8m
Validated parameters for Ultralytics 8.4.48
============================================
Target: colony mAP50 >= 0.75
Data: yolo_v3_production (stratified + 2000 synthetic colonies)
"""
import sys
from pathlib import Path
from ultralytics import YOLO

WORKSPACE = Path('/media/lambda_one/DFSSD04/project/healtcare')
DATA_YAML = WORKSPACE / 'data/yolo_v3_production/data.yaml'

print("=" * 70)
print("  PRODUCTION TRAINING V4 - YOLOv8m")
print("=" * 70)
print(f"  Data: {DATA_YAML}")
print(f"  Images: {len(list((DATA_YAML.parent / 'train/images').glob('*')))} train")
print(f"  Images: {len(list((DATA_YAML.parent / 'val/images').glob('*')))} val")
print(f"  Target: colony mAP50 >= 0.75")
print("=" * 70)

if not DATA_YAML.exists():
    print(f"ERROR: {DATA_YAML} not found")
    sys.exit(1)

model = YOLO('yolov8m.pt')

results = model.train(
    data=str(DATA_YAML),
    epochs=150,
    imgsz=640,
    batch=12,
    patience=40,
    device='0,1',
    workers=6,
    project=str(WORKSPACE / 'runs'),
    name='runs_v4_production',
    exist_ok=True,
    pretrained=True,
    optimizer='AdamW',
    lr0=0.0008,
    lrf=0.008,
    cos_lr=True,
    momentum=0.9,
    weight_decay=0.0005,
    warmup_epochs=5,
    warmup_momentum=0.8,
    warmup_bias_lr=0.05,
    box=7.5,
    cls=3.5,
    dfl=1.5,
    hsv_h=0.015,
    hsv_s=0.6,
    hsv_v=0.4,
    degrees=8,
    translate=0.08,
    scale=0.4,
    shear=0,
    perspective=0.0,
    flipud=0.3,
    fliplr=0.5,
    mosaic=0.3,
    mixup=0.05,
    copy_paste=0.2,
    erasing=0.2,
    label_smoothing=0.05,
    close_mosaic=15,
    save=True,
    plots=True,
)

print("\nTRAINING COMPLETE")
print(f"Best: {WORKSPACE}/runs/runs_v4_production/weights/best.pt")
