#!/usr/bin/env python3
"""
Train YOLOv8 model for colony detection on agar plates.

Usage:
    python3 train.py                          # Default config
    python3 train.py --epochs 100 --model m   # Custom config
    python3 train.py --resume                 # Resume training
"""

import argparse
from pathlib import Path
from ultralytics import YOLO


def train(data_yaml, epochs=100, imgsz=640, batch=16, model_size='s',
          device=0, project='models', name='plate_count_reader', resume=False):
    """Train YOLOv8 model."""
    
    # Load model
    if resume:
        model = YOLO(f'{project}/{name}/weights/last.pt')
    else:
        model = YOLO(f'yolov8{model_size}.pt')
    
    # Train
    results = model.train(
        data=data_yaml,
        epochs=epochs,
        imgsz=imgsz,
        batch=batch,
        device=device,
        patience=20,
        project=project,
        name=name,
        exist_ok=True,
        pretrained=True,
        optimizer='AdamW',
        lr0=0.001,
        lrf=0.01,
        warmup_epochs=3,
        cos_lr=True,
        augment=True,
        mosaic=1.0,
        mixup=0.1,
        copy_paste=0.1,
        degrees=15,
        translate=0.1,
        scale=0.5,
        fliplr=0.5,
        flipud=0.1,
        hsv_h=0.015,
        hsv_s=0.7,
        hsv_v=0.4,
        workers=4,
        seed=42,
        verbose=True,
    )
    
    # Validate
    metrics = model.val()
    print(f"\nmAP50: {metrics.box.map50:.4f}")
    print(f"mAP50-95: {metrics.box.map:.4f}")
    print(f"Precision: {metrics.box.mp:.4f}")
    print(f"Recall: {metrics.box.mr:.4f}")
    
    return results, metrics


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Train Plate Count Reader model')
    parser.add_argument('--data', type=str, default='data/yolo_dataset/data.yaml')
    parser.add_argument('--epochs', type=int, default=100)
    parser.add_argument('--batch', type=int, default=16)
    parser.add_argument('--imgsz', type=int, default=640)
    parser.add_argument('--model', type=str, default='s', choices=['n','s','m','l','x'])
    parser.add_argument('--device', type=int, default=0)
    parser.add_argument('--resume', action='store_true')
    
    args = parser.parse_args()
    train(args.data, args.epochs, args.imgsz, args.batch, args.model, args.device, resume=args.resume)
