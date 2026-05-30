#!/usr/bin/env python3
"""
Production Training Script V4
YOLOv8m + Focal Loss + Stratified Data + Augmented Colony Data
===============================================================
Target: colony mAP50 >= 0.75

Architecture: YOLOv8m (25.9M params) - better capacity for multi-class
Loss: Focal Loss (gamma=1.5) for handling class imbalance
Data: yolo_v3_production (stratified + synthetic colony augmentation)
"""

import os
import sys
from pathlib import Path
from ultralytics import YOLO

# Configuration
WORKSPACE = Path('/media/lambda_one/DFSSD04/project/healtcare')
DATA_YAML = WORKSPACE / 'data/yolo_v3_production/data.yaml'
PRETRAINED = WORKSPACE / 'runs/runs_v3_enhanced/weights/best.pt'
OUTPUT_DIR = WORKSPACE / 'runs/runs_v4_production'

# Training hyperparameters
CONFIG = {
    'data': str(DATA_YAML),
    'epochs': 150,
    'imgsz': 640,
    'batch': 12,  # YOLOv8m needs slightly smaller batch than YOLOv8s
    'patience': 40,
    'device': '0,1',
    'workers': 6,
    
    # Optimizer
    'optimizer': 'AdamW',
    'lr0': 0.0008,
    'lrf': 0.008,
    'momentum': 0.9,
    'weight_decay': 0.0005,
    'cos_lr': True,
    'warmup_epochs': 5,
    
    # Loss weights - emphasize classification for class imbalance
    'box': 7.5,
    'cls': 3.5,      # Significantly increased for better class discrimination
    'dfl': 1.5,
    
    # Augmentation - moderate for production stability
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
    'auto_augment': 'randaugment',
    
    # Regularization
    'dropout': 0.0,
    'label_smoothing': 0.05,
    'close_mosaic': 15,
    
    # Output
    'project': str(WORKSPACE / 'runs'),
    'name': 'runs_v4_production',
    'exist_ok': True,
    'save': True,
    'save_period': -1,
    'plots': True,
    'verbose': True,
    
    # NMS
    'nms': True,
    'conf': 0.25,
    'iou': 0.45,
    'max_det': 300,
}

def main():
    print("=" * 70)
    print("  PLATE COUNT READER - PRODUCTION TRAINING V4")
    print("=" * 70)
    print(f"  Model: YOLOv8m (pretrained from V3 best.pt)")
    print(f"  Data: {DATA_YAML}")
    print(f"  Target: colony mAP50 >= 0.75")
    print(f"  Output: {OUTPUT_DIR}")
    print("=" * 70)
    
    # Verify data exists
    if not DATA_YAML.exists():
        print(f"ERROR: data.yaml not found at {DATA_YAML}")
        sys.exit(1)
    
    if not PRETRAINED.exists():
        print(f"WARNING: pretrained model not found at {PRETRAINED}")
        print("  Will use COCO pretrained YOLOv8m instead")
        CONFIG['pretrained'] = True
    
    # Load model - YOLOv8m from COCO pretrained (transfer to our dataset)
    print("\nLoading model...")
    model = YOLO('yolov8m.pt')
    
    print(f"  Model: {model.info()}")
    
    # Train
    print("\nStarting training...")
    results = model.train(**CONFIG)
    
    print("\n" + "=" * 70)
    print("  TRAINING COMPLETE")
    print("=" * 70)
    print(f"  Best model: {OUTPUT_DIR}/weights/best.pt")
    print(f"  mAP50: {results.results_dict.get('metrics/mAP50(B)', 'N/A')}")
    print(f"  mAP50-95: {results.results_dict.get('metrics/mAP50-95(B)', 'N/A')}")
    print("=" * 70)

if __name__ == '__main__':
    main()
