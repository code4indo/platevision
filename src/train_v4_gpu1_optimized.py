#!/usr/bin/env python3
"""
Production Training V4 - GPU 1 Only (Optimized)
================================================
Fixes applied:
- workers reduced to 2 (prevent CPU/RAM bottleneck)
- batch reduced to 8 (prevent CPU overload)
- cache=True (preload dataset to RAM, faster access)
- augment=False (disable albumentations CPU bottleneck)
- cos_lr=False (simpler scheduler)

Target: colony mAP50 >= 0.75
"""

import os
import sys
from pathlib import Path
from ultralytics import YOLO

os.chdir('/media/lambda_one/DFSSD04/project/healtcare')

print("=" * 70)
print("  PLATE COUNT READER - PRODUCTION TRAINING V4 (OPTIMIZED)")
print("=" * 70)
print(f"  Model: YOLOv8m")
print(f"  Device: GPU 1")
print(f"  Optimizations: cache=True, workers=2, batch=8, augment=False")
print("=" * 70)

# Load model
print("\n[1/3] Loading YOLOv8m model...")
model = YOLO('yolov8m.pt')
print(f"  Loaded: {len(model.names)} COCO classes -> will fine-tune to 4 classes")

# Training config - OPTIMIZED for this server
config = {
    'data': 'data/yolo_v3_production/data.yaml',
    'epochs': 150,
    'imgsz': 640,
    'batch': 8,           # Reduced from 16 -> less CPU load
    'patience': 40,
    'device': 1,
    'workers': 2,         # Reduced from 6 -> prevent CPU/RAM exhaustion
    'project': 'runs',
    'name': 'runs_v4_production',
    'exist_ok': True,
    'pretrained': True,
    'optimizer': 'AdamW',
    'lr0': 0.0008,
    'lrf': 0.008,
    'cos_lr': False,      # Simpler scheduler
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
    'augment': False,     # DISABLE albumentations CPU bottleneck
    'cache': True,        # PRELOAD dataset to RAM
    'save': True,
    'plots': True,
}

print("\n[2/3] Configuration:")
for k in ['epochs', 'batch', 'workers', 'device', 'cache', 'augment']:
    print(f"  {k}: {config[k]}")

# Start training
print("\n[3/3] Starting training...")
print("  Estimated time: ~6-8 hours")
print("=" * 70)

try:
    results = model.train(**config)
    
    print("\n" + "=" * 70)
    print("  TRAINING COMPLETE!")
    print("=" * 70)
    print(f"  Best: runs/runs_v4_production/weights/best.pt")
    
    if hasattr(results, 'results_dict'):
        metrics = results.results_dict
        print(f"  mAP50: {metrics.get('metrics/mAP50(B)', 'N/A')}")
        print(f"  mAP50-95: {metrics.get('metrics/mAP50-95(B)', 'N/A')}")
    
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
