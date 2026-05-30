#!/usr/bin/env python3
"""
Convert various dataset formats to YOLOv8 format.

Supports:
- AGAR (segmentation masks → bounding boxes)
- Microbial Colony Recognition (JSON → YOLO)
- COCO format (JSON → YOLO)
- Pascal VOC (XML → YOLO)

Usage:
    python3 convert_dataset.py --source agar --input /path/to/agar --output /path/to/yolo
    python3 convert_dataset.py --source all --input /path/to/datasets --output /path/to/yolo
"""

import os
import json
import argparse
from pathlib import Path
from PIL import Image
import numpy as np


def convert_agar(input_dir, output_dir):
    """Convert AGAR segmentation masks to YOLO bounding boxes."""
    import scipy.ndimage as ndi
    
    print(f"Converting AGAR from {input_dir}...")
    # Find mask files
    mask_files = list(Path(input_dir).rglob("*.png")) + list(Path(input_dir).rglob("*.jpg"))
    converted = 0
    
    for mask_path in mask_files:
        mask = np.array(Image.open(mask_path))
        if mask.ndim == 3:
            mask = mask[:, :, 0]  # Use first channel
        
        # Label connected components
        labeled, num_features = ndi.label(mask > 127)
        
        if num_features == 0:
            continue
        
        h, w = mask.shape
        lines = []
        for i in range(1, num_features + 1):
            ys, xs = np.where(labeled == i)
            if len(xs) < 5:  # Skip tiny noise
                continue
            x1, x2 = xs.min(), xs.max()
            y1, y2 = ys.min(), ys.max()
            cx = ((x1 + x2) / 2) / w
            cy = ((y1 + y2) / 2) / h
            bw = (x2 - x1) / w
            bh = (y2 - y1) / h
            if bw > 0.001 and bh > 0.001:
                lines.append(f"0 {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}")
        
        if lines:
            label_path = Path(output_dir) / f"{mask_path.stem}.txt"
            label_path.parent.mkdir(parents=True, exist_ok=True)
            with open(label_path, 'w') as f:
                f.write('\n'.join(lines))
            converted += 1
    
    print(f"AGAR: {converted} masks converted")
    return converted


def convert_microbial(input_dir, output_dir):
    """Convert Microbial Colony JSON annotations to YOLO format."""
    converted = 0
    
    for json_file in Path(input_dir).rglob("*.json"):
        img_path = None
        for ext in ['.jpg', '.jpeg', '.png']:
            candidate = str(json_file).replace('.json', ext)
            if Path(candidate).exists():
                img_path = candidate
                break
        
        if not img_path:
            continue
        
        with open(json_file) as f:
            data = json.load(f)
        
        img = Image.open(img_path)
        w, h = img.size
        
        labels = data.get('labels', data.get('annotations', data.get('shapes', data.get('regions', []))))
        lines = []
        
        for label in labels:
            if isinstance(label, dict):
                x = float(label.get('x', label.get('xmin', 0)))
                y = float(label.get('y', label.get('ymin', 0)))
                bw = float(label.get('width', label.get('w', 0)))
                bh = float(label.get('height', label.get('h', 0)))
                
                cx = max(0, min(1, (x + bw/2) / w))
                cy = max(0, min(1, (y + bh/2) / h))
                nw = max(0.001, min(1, bw / w))
                nh = max(0.001, min(1, bh / h))
                lines.append(f"0 {cx:.6f} {cy:.6f} {nw:.6f} {nh:.6f}")
        
        if lines:
            label_path = Path(output_dir) / f"{json_file.stem}.txt"
            label_path.parent.mkdir(parents=True, exist_ok=True)
            with open(label_path, 'w') as f:
                f.write('\n'.join(lines))
            converted += 1
    
    print(f"Microbial: {converted} images converted")
    return converted


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Convert datasets to YOLO format')
    parser.add_argument('--source', choices=['agar', 'microbial', 'all'], default='all')
    parser.add_argument('--input', type=str, required=True)
    parser.add_argument('--output', type=str, required=True)
    
    args = parser.parse_args()
    
    if args.source in ('agar', 'all'):
        convert_agar(args.input, args.output)
    if args.source in ('microbial', 'all'):
        convert_microbial(args.input, args.output)
