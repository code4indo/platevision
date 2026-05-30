#!/usr/bin/env python3
"""
Simplified Colony Augmentation - Direct approach
Extract colony crops and paste onto clean backgrounds.
"""
import os
import cv2
import random
import numpy as np
from pathlib import Path
from collections import Counter

def parse_labels(label_path):
    boxes = []
    try:
        with open(label_path) as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) == 5:
                    boxes.append([int(parts[0])] + [float(x) for x in parts[1:]])
    except:
        pass
    return boxes

def main():
    WORKSPACE = Path('/media/lambda_one/DFSSD04/project/healtcare')
    DATA = WORKSPACE / 'data/yolo_v3_production'
    IMG_DIR = DATA / 'train/images'
    LBL_DIR = DATA / 'train/labels'
    
    print("Step 1: Extracting colony crops...")
    crops = []
    for lbl_path in sorted(LBL_DIR.glob('*.txt')):
        stem = lbl_path.stem
        img_path = IMG_DIR / (stem + '.jpg')
        if not img_path.exists():
            img_path = IMG_DIR / (stem + '.png')
        if not img_path.exists():
            continue
        
        img = cv2.imread(str(img_path))
        if img is None:
            continue
        h, w = img.shape[:2]
        
        for box in parse_labels(lbl_path):
            if box[0] == 0:  # colony
                x, y, bw, bh = box[1], box[2], box[3], box[4]
                x1 = max(0, int((x - bw/2) * w))
                y1 = max(0, int((y - bh/2) * h))
                x2 = min(w, int((x + bw/2) * w))
                y2 = min(h, int((y + bh/2) * h))
                if x2 > x1 and y2 > y1 and (x2-x1) >= 15 and (y2-y1) >= 15:
                    crops.append(img[y1:y2, x1:x2].copy())
    
    print(f"  Extracted {len(crops)} colony crops")
    if len(crops) < 50:
        print("  ERROR: Too few crops. Aborting.")
        return
    
    print("Step 2: Finding clean background images...")
    backgrounds = []
    for img_path in sorted(IMG_DIR.glob('*'))[:500]:
        stem = img_path.stem
        lbl_path = LBL_DIR / (stem + '.txt')
        if lbl_path.exists():
            boxes = parse_labels(lbl_path)
            colony_count = sum(1 for b in boxes if b[0] == 0)
            if colony_count <= 2:
                bg = cv2.imread(str(img_path))
                if bg is not None:
                    backgrounds.append(bg)
    
    if not backgrounds:
        print("  Using random images as backgrounds")
        for img_path in sorted(IMG_DIR.glob('*'))[:200]:
            bg = cv2.imread(str(img_path))
            if bg is not None:
                backgrounds.append(bg)
    
    print(f"  Found {len(backgrounds)} background images")
    
    print("Step 3: Generating synthetic images...")
    random.seed(42)
    target = 2000  # Generate 2000 synthetic images
    
    for i in range(target):
        bg = random.choice(backgrounds).copy()
        bh, bw = bg.shape[:2]
        labels = []
        n_colonies = random.randint(3, 20)
        
        for _ in range(n_colonies):
            crop = random.choice(crops)
            ch, cw = crop.shape[:2]
            scale = random.uniform(0.6, 1.3)
            new_w = max(8, int(cw * scale))
            new_h = max(8, int(ch * scale))
            resized = cv2.resize(crop, (new_w, new_h))
            
            x = random.randint(0, max(0, bw - new_w))
            y = random.randint(0, max(0, bh - new_h))
            
            # Simple paste with slight alpha blend
            roi = bg[y:y+new_h, x:x+new_w]
            if roi.shape == resized.shape:
                blended = cv2.addWeighted(roi, 0.15, resized, 0.85, 0)
                bg[y:y+new_h, x:x+new_w] = blended
                
                nx = (x + new_w/2) / bw
                ny = (y + new_h/2) / bh
                nw = new_w / bw
                nh = new_h / bh
                labels.append(f"0 {nx:.6f} {ny:.6f} {nw:.6f} {nh:.6f}")
        
        img_name = f"syn_col_{i:05d}.jpg"
        lbl_name = f"syn_col_{i:05d}.txt"
        cv2.imwrite(str(IMG_DIR / img_name), bg)
        with open(LBL_DIR / lbl_name, 'w') as f:
            f.write('\n'.join(labels) + '\n')
        
        if (i+1) % 500 == 0:
            print(f"  Generated {i+1}/{target}")
    
    print(f"\nDone! Generated {target} synthetic images.")
    print(f"New train size: {len(list(IMG_DIR.glob('*')))} images")

if __name__ == '__main__':
    main()
