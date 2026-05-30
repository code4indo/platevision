#!/usr/bin/env python3
"""
Create stratified validation split for production-ready model training.
Ensures minimum representation per class in validation set.
"""
import os
import shutil
import random
from pathlib import Path
from collections import defaultdict, Counter

def parse_label(label_path):
    """Parse YOLO label file and return list of class IDs."""
    classes = []
    try:
        with open(label_path, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if parts:
                    classes.append(int(parts[0]))
    except:
        pass
    return classes

def create_stratified_split(source_dir, output_dir, val_size=800, min_per_class=150, seed=42):
    """
    Create stratified train/val split.
    
    Args:
        source_dir: Source yolo_v3_enhanced directory
        output_dir: Output directory
        val_size: Total validation images
        min_per_class: Minimum images per class in validation
        seed: Random seed
    """
    random.seed(seed)
    source_dir = Path(source_dir)
    output_dir = Path(output_dir)
    
    train_img_dir = source_dir / 'train' / 'images'
    train_lbl_dir = source_dir / 'train' / 'labels'
    val_img_dir = source_dir / 'val' / 'images'
    val_lbl_dir = source_dir / 'val' / 'labels'
    
    # Output dirs
    out_train_img = output_dir / 'train' / 'images'
    out_train_lbl = output_dir / 'train' / 'labels'
    out_val_img = output_dir / 'val' / 'images'
    out_val_lbl = output_dir / 'val' / 'labels'
    
    for d in [out_train_img, out_train_lbl, out_val_img, out_val_lbl]:
        d.mkdir(parents=True, exist_ok=True)
    
    # Collect all images and their class distributions
    print("Scanning training images...")
    all_train_images = sorted(train_img_dir.glob('*'))
    
    # Categorize by dominant class
    class_to_images = defaultdict(list)
    multi_class_images = []
    
    for img_path in all_train_images:
        stem = img_path.stem
        lbl_path = train_lbl_dir / f"{stem}.txt"
        classes = parse_label(lbl_path)
        
        if not classes:
            continue
            
        # Find dominant class
        class_counts = Counter(classes)
        dominant = class_counts.most_common(1)[0][0]
        
        if len(set(classes)) > 1:
            multi_class_images.append((img_path, classes))
        
        class_to_images[dominant].append((img_path, classes))
    
    # Print distribution
    print("\nTraining set class distribution (by dominant class):")
    for cls_id in sorted(class_to_images.keys()):
        print(f"  Class {cls_id}: {len(class_to_images[cls_id])} images")
    print(f"  Multi-class images: {len(multi_class_images)}")
    
    # Stratified sampling for validation
    val_images = set()
    
    # First, ensure minimum per class
    for cls_id, images in sorted(class_to_images.items()):
        random.shuffle(images)
        n_sample = min(min_per_class, len(images))
        selected = images[:n_sample]
        for img_path, _ in selected:
            val_images.add(img_path.name)
    
    # Fill remaining with random samples, prioritizing underrepresented
    remaining = val_size - len(val_images)
    if remaining > 0:
        # Collect all images not yet in val
        available = []
        for cls_id, images in class_to_images.items():
            for img_path, classes in images:
                if img_path.name not in val_images:
                    available.append((img_path, classes))
        
        # Add multi-class images too
        for img_path, classes in multi_class_images:
            if img_path.name not in val_images:
                available.append((img_path, classes))
        
        random.shuffle(available)
        for img_path, _ in available[:remaining]:
            val_images.add(img_path.name)
    
    print(f"\nValidation set size: {len(val_images)}")
    
    # Copy files
    train_copied = 0
    val_copied = 0
    val_class_counts = Counter()
    
    # Process training images
    for img_path in all_train_images:
        stem = img_path.stem
        lbl_path = train_lbl_dir / f"{stem}.txt"
        
        if img_path.name in val_images:
            dst_img = out_val_img / img_path.name
            dst_lbl = out_val_lbl / f"{stem}.txt"
            val_copied += 1
            # Count classes in validation
            if lbl_path.exists():
                classes = parse_label(lbl_path)
                for c in classes:
                    val_class_counts[c] += 1
        else:
            dst_img = out_train_img / img_path.name
            dst_lbl = out_train_lbl / f"{stem}.txt"
            train_copied += 1
        
        shutil.copy2(img_path, dst_img)
        if lbl_path.exists():
            shutil.copy2(lbl_path, dst_lbl)
    
    # Also copy original val set to training (since we're creating new val)
    print("\nAdding original validation set to new training set...")
    for img_path in sorted(val_img_dir.glob('*')):
        stem = img_path.stem
        lbl_path = val_lbl_dir / f"{stem}.txt"
        dst_img = out_train_img / img_path.name
        dst_lbl = out_train_lbl / f"{stem}.txt"
        
        # Avoid duplicates
        if not dst_img.exists():
            shutil.copy2(img_path, dst_img)
            if lbl_path.exists():
                shutil.copy2(lbl_path, dst_lbl)
            train_copied += 1
    
    # Copy test if exists
    test_img_dir = source_dir / 'test' / 'images'
    if test_img_dir.exists():
        out_test_img = output_dir / 'test' / 'images'
        out_test_lbl = output_dir / 'test' / 'labels'
        out_test_img.mkdir(parents=True, exist_ok=True)
        out_test_lbl.mkdir(parents=True, exist_ok=True)
        for img_path in sorted(test_img_dir.glob('*')):
            stem = img_path.stem
            lbl_path = source_dir / 'test' / 'labels' / f"{stem}.txt"
            shutil.copy2(img_path, out_test_img / img_path.name)
            if lbl_path.exists():
                shutil.copy2(lbl_path, out_test_lbl / f"{stem}.txt")
    
    # Write data.yaml
    yaml_content = f"""path: {output_dir}
train: train/images
val: val/images
test: test/images
nc: 4
names: ['colony', 'bubble', 'dust', 'crack']
"""
    with open(output_dir / 'data.yaml', 'w') as f:
        f.write(yaml_content)
    
    print(f"\n{'='*60}")
    print("STRATIFIED SPLIT COMPLETE")
    print(f"{'='*60}")
    print(f"New training images: {train_copied}")
    print(f"New validation images: {val_copied}")
    print(f"\nValidation class instance counts:")
    for cls_id in sorted(val_class_counts.keys()):
        cls_name = ['colony', 'bubble', 'dust', 'crack'][cls_id]
        print(f"  {cls_name:>10}: {val_class_counts[cls_id]} instances")
    print(f"\nOutput: {output_dir}")

if __name__ == '__main__':
    SOURCE = '/media/lambda_one/DFSSD04/project/healtcare/data/yolo_v3_enhanced'
    OUTPUT = '/media/lambda_one/DFSSD04/project/healtcare/data/yolo_v3_production'
    
    create_stratified_split(SOURCE, OUTPUT, val_size=800, min_per_class=150)
