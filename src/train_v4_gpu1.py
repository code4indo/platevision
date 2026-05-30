#!/usr/bin/env python3
"""
Production Training V4 - GPU 1 Only
====================================
YOLOv8m training on single GPU to avoid DDP issues.
Target: colony mAP50 >= 0.75
"""

import os
import sys
from pathlib import Path
from ultralytics import YOLO

os.chdir('/media/lambda_one/DFSSD04/project/healtcare')

print("=" * 70)
print("  PLATE COUNT READER - PRODUCTION TRAINING V4 (GPU 1)")
print("=" * 70)
print(f"  Model: YOLOv8m")
print(f"  Device: GPU 1")
print(f"  Dataset: data/yolo_v3_production/data.yaml")
print(f"  Target: colony mAP50 >= 0.75")
print("=" * 70)

# Load model
print("\n[1/4] Loading YOLOv8m model...")
model = YOLO('yolov8m.pt')
print(f"  Original classes: {len(model.names)}")
print(f"  Will be fine-tuned to 4 classes")

# Training config
config = {
    'data': 'data/yolo_v3_production/data.yaml',
    'epochs': 150,
    'imgsz': 640,
    'batch': 16,
    'patience': 40,
    'device': 1,
    'workers': 6,
    'project': 'runs',
    'name': 'runs_v4_production',
    'exist_ok': True,
    'pretrained': True,
    'optimizer': 'AdamW',
    'lr0': 0.0008,
    'lrf': 0.008,
    'cos_lr': True,
    'momentum': 0.9,
    'weight_decay': 0.0005,
    'warmup_epochs': 5,
    'warmup_momentum': 0.8,
    'warmup_bias_lr': 0.05,
    'box': 7.5,
    'cls': 3.5,
    'dfl': 1.5,
    'hsv_h': 0.015,
    'hsv_s': 0.6,
    'hsv_v': 0.4,
    'degrees': 8,
    'translate': 0.08,
    'scale': 0.4,
    'shear': 0,
    'perspective': 0.0,
    'flipud': 0.3,
    'fliplr': 0.5,
    'mosaic': 0.3,
    'mixup': 0.05,
    'copy_paste': 0.2,
    'erasing': 0.2,
    'label_smoothing': 0.05,
    'close_mosaic': 15,
    'save': True,
    'plots': True,
}

print("\n[2/4] Training configuration:")
for k, v in sorted(config.items()):
    print(f"  {k}: {v}")

# Start training
print("\n[3/4] Starting training...")
print("  This will take approximately 6-10 hours")
print("=" * 70)

try:
    results = model.train(**config)
    
    print("\n" + "=" * 70)
    print("  TRAINING COMPLETE!")
    print("=" * 70)
    print(f"  Best model: runs/runs_v4_production/weights/best.pt")
    
    # Print metrics if available
    if hasattr(results, 'results_dict'):
        metrics = results.results_dict
        print(f"  mAP50: {metrics.get('metrics/mAP50(B)', 'N/A')}")
        print(f"  mAP50-95: {metrics.get('metrics/mAP50-95(B)', 'N/A')}")
        print(f"  Precision: {metrics.get('metrics/precision(B)', 'N/A')}")
        print(f"  Recall: {metrics.get('metrics/recall(B)', 'N/A')}")
    
    # Copy best model to models/
    import shutil
    best_src = Path('runs/runs_v4_production/weights/best.pt')
    best_dst = Path('models/best_v4_production.pt')
    if best_src.exists():
        shutil.copy(best_src, best_dst)
        print(f"  Copied to: {best_dst}")
    
    print("=" * 70)
    sys.exit(0)
    
except Exception as e:
    print(f"\n❌ Training failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
