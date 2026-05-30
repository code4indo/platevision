#!/usr/bin/env python3
"""
Inference utility for Plate Count Reader.

Usage:
    python3 inference.py --image test.jpg
    python3 inference.py --image test.jpg --conf 0.3
    python3 inference.py --dir samples/ --output results/
"""

import argparse
import os
from pathlib import Path
from ultralytics import YOLO


def run_inference(image_path, model_path='models/best_plate_count_reader.pt',
                  conf=0.25, iou=0.45, output_dir='results/'):
    """Run inference on a single image."""
    
    model = YOLO(model_path)
    results = model(image_path, conf=conf, iou=iou, verbose=False)
    
    # Print results
    count = len(results[0].boxes)
    print(f"Image: {image_path}")
    print(f"Colonies detected: {count}")
    
    if count > 0:
        confs = results[0].boxes.conf.cpu().numpy()
        print(f"Avg confidence: {confs.mean():.3f}")
    
    # Save annotated image
    os.makedirs(output_dir, exist_ok=True)
    out_path = os.path.join(output_dir, f"result_{Path(image_path).name}")
    results[0].save(out_path)
    print(f"Saved: {out_path}")
    
    return results


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run inference on images')
    parser.add_argument('--image', type=str, help='Single image path')
    parser.add_argument('--dir', type=str, help='Directory of images')
    parser.add_argument('--model', type=str, default='models/best_plate_count_reader.pt')
    parser.add_argument('--conf', type=float, default=0.25)
    parser.add_argument('--iou', type=float, default=0.45)
    parser.add_argument('--output', type=str, default='results/')
    
    args = parser.parse_args()
    
    if args.image:
        run_inference(args.image, args.model, args.conf, args.iou, args.output)
    elif args.dir:
        for f in Path(args.dir).iterdir():
            if f.suffix.lower() in ('.jpg', '.jpeg', '.png', '.bmp'):
                run_inference(str(f), args.model, args.conf, args.iou, args.output)
    else:
        print("Please provide --image or --dir")
