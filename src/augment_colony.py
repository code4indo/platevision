#!/usr/bin/env python3
"""
Colony Augmentation Pipeline - Generate synthetic colony instances
via copy-paste augmentation to boost colony class performance.
"""
import os
import cv2
import random
import numpy as np
from pathlib import Path
from collections import defaultdict

def parse_yolo_label(label_path):
    """Parse YOLO format labels."""
    boxes = []
    try:
        with open(label_path, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) == 5:
                    cls_id = int(parts[0])
                    x, y, w, h = map(float, parts[1:])
                    boxes.append((cls_id, x, y, w, h))
    except:
        pass
    return boxes

def yolo_to_pixel(x, y, w, h, img_w, img_h):
    """Convert YOLO normalized to pixel coordinates."""
    x1 = int((x - w/2) * img_w)
    y1 = int((y - h/2) * img_h)
    x2 = int((x + w/2) * img_w)
    y2 = int((y + h/2) * img_h)
    return max(0, x1), max(0, y1), min(img_w, x2), min(img_h, y2)

def pixel_to_yolo(x1, y1, x2, y2, img_w, img_h):
    """Convert pixel to YOLO normalized."""
    w = x2 - x1
    h = y2 - y1
    x = (x1 + w/2) / img_w
    y = (y1 + h/2) / img_h
    return x, y, w / img_w, h / img_h

def extract_colony_crops(data_dir, min_size=20):
    """Extract colony crops from training images."""
    data_dir = Path(data_dir)
    img_dir = data_dir / 'train' / 'images'
    lbl_dir = data_dir / 'train' / 'labels'
    
    crops = []
    print("Extracting colony crops...")
    
    for lbl_path in sorted(lbl_dir.glob('*.txt')):
        stem = lbl_path.stem
        img_path = img_dir / f"{stem}.jpg"
        if not img_path.exists():
            img_path = img_dir / f"{stem}.png"
        if not img_path.exists():
            continue
        
        img = cv2.imread(str(img_path))
        if img is None:
            continue
        h, w = img.shape[:2]
        
        boxes = parse_yolo_label(lbl_path)
        for cls_id, x, y, bw, bh in boxes:
            if cls_id == 0:  # colony class
                x1, y1, x2, y2 = yolo_to_pixel(x, y, bw, bh, w, h)
                cw, ch = x2 - x1, y2 - y1
                if cw >= min_size and ch >= min_size:
                    crop = img[y1:y2, x1:x2].copy()
                    if crop.size > 0:
                        crops.append(crop)
    
    print(f"Extracted {len(crops)} colony crops")
    return crops

def paste_colony(background, colony_crop, x, y, alpha=0.9):
    """Paste colony crop onto background with slight blending."""
    h, w = colony_crop.shape[:2]
    bh, bw = background.shape[:2]
    
    # Ensure within bounds
    if y + h > bh:
        h = bh - y
    if x + w > bw:
        w = bw - x
    if h <= 0 or w <= 0:
        return None, None, None, None
    
    crop = colony_crop[:h, :w]
    
    # Simple paste (colonies are opaque on agar)
    roi = background[y:y+h, x:x+w]
    blended = cv2.addWeighted(roi, 1-alpha, crop, alpha, 0)
    background[y:y+h, x:x+w] = blended
    
    return background, x, y, x+w, y+h

def generate_synthetic_images(data_dir, output_dir, n_target=3000):
    """Generate synthetic images with pasted colonies."""
    data_dir = Path(data_dir)
    output_dir = Path(output_dir)
    
    out_img = output_dir / 'train' / 'images'
    out_lbl = output_dir / 'train' / 'labels'
    out_img.mkdir(parents=True, exist_ok=True)
    out_lbl.mkdir(parents=True, exist_ok=True)
    
    # Extract crops
    crops = extract_colony_crops(data_dir)
    if len(crops) < 100:
        print("WARNING: Too few colony crops found!")
        return
    
    # Get background images (images with few or no colonies)
    img_dir = data_dir / 'train' / 'images'
    lbl_dir = data_dir / 'train' / 'labels'
    
    backgrounds = []
    for img_path in sorted(img_dir.glob('*')):
        stem = img_path.stem
        lbl_path = lbl_dir / f"{stem}.txt"
        boxes = parse_yolo_label(lbl_path)
        # Use images with < 3 colonies as background candidates
        colony_count = sum(1 for b in boxes if b[0] == 0)
        if colony_count < 3:
            bg = cv2.imread(str(img_path))
            if bg is not None:
                backgrounds.append(bg)
    
    if not backgrounds:
        print("WARNING: No suitable backgrounds found, using all images")
        for img_path in sorted(img_dir.glob('*'))[:100]:
            bg = cv2.imread(str(img_path))
            if bg is not None:
                backgrounds.append(bg)
    
    print(f"Found {len(backgrounds)} background images")
    
    generated = 0
    target_total = n_target
    
    while generated < target_total:
        bg = random.choice(backgrounds).copy()
        bh, bw = bg.shape[:2]
        
        labels = []
        n_paste = random.randint(5, 25)  # 5-25 colonies per image
        
        for _ in range(n_paste):
            crop = random.choice(crops)
            ch, cw = crop.shape[:2]
            
            # Random scale
            scale = random.uniform(0.5, 1.5)
            new_w = max(10, int(cw * scale))
            new_h = max(10, int(ch * scale))
            crop_resized = cv2.resize(crop, (new_w, new_h))
            
            # Random position
            x = random.randint(0, max(0, bw - new_w))
            y = random.randint(0, max(0, bh - new_h))
            
            # Paste
            result, x1, y1, x2, y2 = paste_colony(bg, crop_resized, x, y)
            if result is not None:
                bg = result
                nx, ny, nw, nh = pixel_to_yolo(x1, y1, x2, y2, bw, bh)
                labels.append(f"0 {nx:.6f} {ny:.6f} {nw:.6f} {nh:.6f}")
        
        # Save
        img_name = f"syn_colony_{generated:04d}.jpg"
        lbl_name = f"syn_colony_{generated:04d}.txt"
        
        cv2.imwrite(str(out_img / img_name), bg)
        with open(out_lbl / lbl_name, 'w') as f:
            f.write('\n'.join(labels))
        
        generated += 1
        if generated % 500 == 0:
            print(f"  Generated {generated}/{target_total}")
    
    print(f"\nGenerated {generated} synthetic images in {out_img}")
    return generated

if __name__ == '__main__':
    SOURCE = '/media/lambda_one/DFSSD04/project/healtcare/data/yolo_v3_enhanced'
    OUTPUT = '/media/lambda_one/DFSSD04/project/healtcare/data/yolo_v3_production'
    
    generate_synthetic_images(SOURCE, OUTPUT, n_target=3000)
