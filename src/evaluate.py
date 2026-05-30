#!/usr/bin/env python3
"""
Evaluate trained YOLOv8 model for colony detection.

Usage:
    python3 evaluate.py
    python3 evaluate.py --model models/best_plate_count_reader.pt
    python3 evaluate.py --model models/best_plate_count_reader.pt --split test
"""

import argparse
from pathlib import Path
from ultralytics import YOLO


def evaluate(model_path, data_yaml=None, split='val'):
    """Evaluate model and print metrics."""
    
    model = YOLO(model_path)
    print(f"Model: {model_path}")
    print(f"Task: {model.task}")
    print(f"Names: {model.names}")
    
    if data_yaml:
        metrics = model.val(data=data_yaml, split=split)
    else:
        metrics = model.val()
    
    print(f"\n{'='*50}")
    print(f"  EVALUATION RESULTS")
    print(f"{'='*50}")
    print(f"  mAP50:     {metrics.box.map50:.4f}")
    print(f"  mAP50-95:  {metrics.box.map:.4f}")
    print(f"  Precision:  {metrics.box.mp:.4f}")
    print(f"  Recall:     {metrics.box.mr:.4f}")
    print(f"{'='*50}")
    
    return metrics


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Evaluate Plate Count Reader model')
    parser.add_argument('--model', type=str, default='models/best_plate_count_reader.pt')
    parser.add_argument('--data', type=str, default='data/yolo_dataset/data.yaml')
    parser.add_argument('--split', type=str, default='val', choices=['val', 'test'])
    
    args = parser.parse_args()
    evaluate(args.model, args.data, args.split)
