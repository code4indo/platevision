#!/usr/bin/env python3
"""
Production Training V4 - GPU 1 Only (Optimized) + MLflow Tracking
=================================================================
Adds MLflow experiment tracking to the optimized training script.

Target: colony mAP50 >= 0.75
"""

import os
import sys
from pathlib import Path
from datetime import datetime
import mlflow
from ultralytics import YOLO

os.chdir('/media/lambda_one/DFSSD04/project/healtcare')

# MLflow setup
MLFLOW_TRACKING_URI = 'http://localhost:5500'
EXPERIMENT_NAME = 'plate_count_reader_v4_production'
RUN_NAME = f'yolov8m_gpu1_{datetime.now().strftime("%Y%m%d_%H%M%S")}'

mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
mlflow.set_experiment(EXPERIMENT_NAME)

print("=" * 70)
print("  PLATE COUNT READER - PRODUCTION TRAINING V4 (MLflow ENABLED)")
print("=" * 70)
print(f"  Model: YOLOv8m")
print(f"  Device: GPU 1")
print(f"  MLflow URI: {MLFLOW_TRACKING_URI}")
print(f"  Experiment: {EXPERIMENT_NAME}")
print(f"  Run Name: {RUN_NAME}")
print("=" * 70)

# Load model
print("\n[1/4] Loading YOLOv8m model...")
model = YOLO('yolov8m.pt')
print(f"  Loaded: {len(model.names)} COCO classes -> will fine-tune to 4 classes")

# Training config
config = {
    'data': 'data/yolo_v3_production/data.yaml',
    'epochs': 150,
    'imgsz': 640,
    'batch': 8,
    'patience': 40,
    'device': 1,
    'workers': 2,
    'project': 'runs',
    'name': 'runs_v4_production',
    'exist_ok': True,
    'pretrained': True,
    'optimizer': 'AdamW',
    'lr0': 0.0008,
    'lrf': 0.008,
    'cos_lr': False,
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
    'augment': False,
    'cache': True,
    'save': True,
    'plots': True,
}

print("\n[2/4] Configuration:")
for k in ['epochs', 'batch', 'workers', 'device', 'cache', 'augment']:
    print(f"  {k}: {config[k]}")

# Start MLflow run
print("\n[3/4] Starting MLflow run...")
with mlflow.start_run(run_name=RUN_NAME):
    # Log config parameters (avoid 'model' conflict with Ultralytics internal callback)
    mlflow.log_params(config)
    mlflow.log_param('model_type', 'yolov8m')
    mlflow.log_param('dataset', 'yolo_v3_production')
    mlflow.log_param('num_classes', 4)
    mlflow.log_param('target_metric', 'colony_mAP50 >= 0.75')
    mlflow.log_param('mlflow_enabled', True)
    
    print("  MLflow params logged")
    
    # Start training
    print("\n[4/4] Starting training...")
    print("  Estimated time: ~6-8 hours")
    print("=" * 70)
    
    try:
        results = model.train(**config)
        
        print("\n" + "=" * 70)
        print("  TRAINING COMPLETE!")
        print("=" * 70)
        
        # Log metrics to MLflow
        if hasattr(results, 'results_dict'):
            metrics = results.results_dict
            mAP50 = metrics.get('metrics/mAP50(B)', 0)
            mAP5095 = metrics.get('metrics/mAP50-95(B)', 0)
            
            print(f"  mAP50: {mAP50}")
            print(f"  mAP50-95: {mAP5095}")
            
            mlflow.log_metrics({
                'mAP50': mAP50,
                'mAP50-95': mAP5095,
            })
        
        # Copy best model
        import shutil
        best_src = Path('runs/detect/runs/runs_v4_production/weights/best.pt')
        best_dst = Path('models/best_v4_production.pt')
        if best_src.exists():
            shutil.copy(best_src, best_dst)
            print(f"  Copied to: {best_dst}")
            mlflow.log_artifact(str(best_src), artifact_path='weights')
        
        print("=" * 70)
        sys.exit(0)
        
    except Exception as e:
        print(f"\n❌ Training failed: {e}")
        import traceback
        traceback.print_exc()
        mlflow.log_param('error', str(e))
        sys.exit(1)
