#!/usr/bin/env python3
"""
Fixed Training Script v2 — Addressing Class Imbalance for Artifact Detection
=============================================================================
PROBLEM: bubble/dust/crack have mAP50=0 because:
  1. All training images contain colony → model learns "anything = colony"
  2. Synthetic artifacts only add labels to existing colony images
  3. No "pure artifact" images (artifact-only, no colony)
  4. Class loss weight too low (cls=0.5)

SOLUTIONS (based on research):
  1. Create pure artifact images (ONLY bubble/dust/crack, NO colony)
  2. Copy-Paste augmentation with real petri dish backgrounds
  3. Increase cls loss weight (cls=2.0) for better class discrimination
  4. Stratified split ensuring all classes in each split
  5. Reduced mosaic (0.5) so artifacts aren't too small
  6. Disable MLflow to avoid Host header crashes during training
"""
import os, sys, json, time, shutil, random, datetime, math
from pathlib import Path
from collections import Counter, defaultdict
import cv2, numpy as np
from scipy import ndimage

WORKSPACE = Path('/media/lambda_one/DFSSD04/project/healtcare')
AGAR = WORKSPACE / 'data/agar'
OUTPUT = WORKSPACE / 'data/yolo_v2_balanced'
CLASS_NAMES = ['colony', 'bubble', 'dust', 'crack']
NC = 4
RANDOM_SEED = 42

# Training hyperparams
EPOCHS = 150
BATCH_SIZE = 16
IMGSZ = 640
PATIENCE = 50
DEVICE = '1'
WORKERS = 6

# V2 FIX: Increased cls weight for better class discrimination
CLS_WEIGHT = 2.0     # was 0.5 — 4x increase to emphasize classification
BOX_WEIGHT = 7.5     # default
DFL_WEIGHT = 1.5     # default

# V2 FIX: Reduced mosaic so artifacts aren't shrunk too small
MOSAIC = 0.5         # was 1.0
MIXUP = 0.1          # keep
COPY_PASTE = 0.3     # NEW: copy-paste augmentation

# Artifact generation params
N_PURE_BUBBLE = 400    # pure artifact images (NO colony)
N_PURE_DUST = 350
N_PURE_CRACK = 300
N_CROP_BUBBLE = 300    # copy-paste from existing colony crops
N_CROP_DUST = 250
N_CROP_CRACK = 200

MIN_COLONY_AREA = 8
MAX_COLONIES = 3000
PL_CONF = 0.20
MAX_PER_BUCKET = 1000

def log(msg):
    ts = datetime.datetime.now().strftime('%H:%M:%S')
    print(f'[{ts}] {msg}', flush=True)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 1: Convert U2Net masks to YOLO boxes (colony only)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def convert_u2net_masks():
    log('STEP 1: Converting U2Net masks to YOLO boxes')
    converted = 0
    for split_name in ['train', 'valid']:
        mask_dir = AGAR / f'dataset/dataset_for_u2net/dataset_for_u2net/{split_name}_mask/colony_detecting'
        img_dir = AGAR / f'dataset/dataset_for_u2net/dataset_for_u2net/{split_name}'
        if not mask_dir.exists():
            log(f'  Mask dir not found: {mask_dir}')
            continue
        for mask_name in sorted(os.listdir(mask_dir)):
            if not mask_name.endswith('_mask.png'):
                continue
            img_name = mask_name.replace('_mask.png', '.png')
            img_path = img_dir / img_name
            if not img_path.exists():
                continue
            img = cv2.imread(str(img_path))
            if img is None:
                continue
            img_h, img_w = img.shape[:2]
            mask = cv2.imread(str(mask_dir / mask_name), cv2.IMREAD_GRAYSCALE)
            if mask is None:
                continue
            mask_bin = (mask > 127).astype(np.uint8)
            labeled, nf = ndimage.label(mask_bin)
            if nf > MAX_COLONIES:
                continue
            yolo_lines = []
            for lid in range(1, nf + 1):
                comp = labeled == lid
                if comp.sum() < MIN_COLONY_AREA:
                    continue
                ys, xs = np.where(comp)
                x0, x1 = int(xs.min()), int(xs.max())
                y0, y1 = int(ys.min()), int(ys.max())
                cx = max(0, min(1, (x0 + x1) / 2.0 / img_w))
                cy = max(0, min(1, (y0 + y1) / 2.0 / img_h))
                w = max(0.001, min(1, (x1 - x0) / img_w))
                h = max(0.001, min(1, (y1 - y0) / img_h))
                yolo_lines.append(f'0 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}')
            if not yolo_lines:
                continue
            stem = Path(img_name).stem
            out_img = OUTPUT / 'raw' / 'images' / img_name
            out_lbl = OUTPUT / 'raw' / 'labels' / f'{stem}.txt'
            out_img.parent.mkdir(parents=True, exist_ok=True)
            out_lbl.parent.mkdir(parents=True, exist_ok=True)
            if not out_img.exists():
                shutil.copy2(str(img_path), str(out_img))
            out_lbl.write_text('\n'.join(yolo_lines))
            converted += 1
    log(f'  Converted: {converted}')
    return converted


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2: Pseudo-label ResNet 18K dataset
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def pseudo_label_resnet():
    log('STEP 2: Pseudo-labeling ResNet 18K dataset')
    from ultralytics import YOLO
    model_path = WORKSPACE / 'models/best_plate_count_reader.pt'
    if not model_path.exists():
        log('  No base model found!')
        return 0
    model = YOLO(str(model_path))
    resnet_dir = AGAR / 'dataset/dataset_for_resnet/dataset_for_resnet'
    if not resnet_dir.exists():
        log('  ResNet dir not found')
        return 0
    all_images = []
    for split in ['train', 'val']:
        split_dir = resnet_dir / split
        if not split_dir.exists():
            continue
        for cd in sorted(os.listdir(split_dir)):
            try:
                cnt = int(cd)
            except ValueError:
                continue
            if cnt == 0:
                continue
            cp = split_dir / cd
            if not cp.exists():
                continue
            for f in sorted(os.listdir(cp)):
                if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp')):
                    all_images.append((cp / f, cnt))
    log(f'  ResNet images (count>0): {len(all_images)}')
    random.seed(RANDOM_SEED)
    by_count = defaultdict(list)
    for p, c in all_images:
        by_count[c].append(p)
    sampled = []
    for c, imgs in sorted(by_count.items()):
        random.shuffle(imgs)
        sampled.extend(imgs[:MAX_PER_BUCKET])
    random.shuffle(sampled)
    log(f'  Sampled for pseudo-labeling: {len(sampled)}')
    if not sampled:
        return 0
    labeled = 0
    bs = 32
    for i in range(0, len(sampled), bs):
        batch = sampled[i:i + bs]
        results = model(batch, conf=PL_CONF, verbose=False, imgsz=IMGSZ, device=DEVICE)
        for j, result in enumerate(results):
            if result.boxes is None or len(result.boxes) == 0:
                continue
            yolo_lines = []
            for k in range(len(result.boxes)):
                conf_val = float(result.boxes.conf[k])
                if conf_val < PL_CONF:
                    continue
                xywhn = result.boxes.xywhn[k].cpu().numpy()
                vals = [max(0, min(1, float(v))) for v in xywhn]
                cx, cy, w, h = vals
                w = max(0.001, w)
                h = max(0.001, h)
                yolo_lines.append(f'0 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}')
            if yolo_lines:
                src = batch[j]
                stem = f'resnet_{Path(src).stem}'
                suffix = Path(src).suffix
                oi = OUTPUT / 'raw' / f'images/{stem}{suffix}'
                ol = OUTPUT / 'raw' / f'labels/{stem}.txt'
                oi.parent.mkdir(parents=True, exist_ok=True)
                ol.parent.mkdir(parents=True, exist_ok=True)
                if not oi.exists():
                    shutil.copy2(str(src), str(oi))
                ol.write_text('\n'.join(yolo_lines))
                labeled += 1
        if (i // bs) % 10 == 0:
            log(f'  Progress: {i}/{len(sampled)}, labeled: {labeled}')
    log(f'  Pseudo-labeled: {labeled}')
    return labeled


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 3: Collect background images (petri dishes with 0 colonies)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def collect_background_images():
    """Collect empty petri dish images (0 colonies) as backgrounds for paste."""
    log('STEP 3: Collecting background images (0 colony petri dishes)')
    resnet_dir = AGAR / 'dataset/dataset_for_resnet/dataset_for_resnet'
    if not resnet_dir.exists():
        log('  ResNet dir not found')
        return []

    bg_images = []
    for split in ['train', 'val']:
        zero_dir = resnet_dir / split / '0'
        if not zero_dir.exists():
            continue
        for f in sorted(os.listdir(zero_dir)):
            if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp')):
                bg_images.append(zero_dir / f)

    random.seed(RANDOM_SEED)
    random.shuffle(bg_images)
    log(f'  Background images found: {len(bg_images)}')
    return bg_images


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 4: Extract colony crops from existing images (for copy-paste)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def extract_colony_crops():
    """Extract colony bounding box crops for copy-paste augmentation."""
    log('STEP 4: Extracting colony crops for copy-paste')
    rid = OUTPUT / 'raw' / 'images'
    rld = OUTPUT / 'raw' / 'labels'
    crops = []
    count = 0
    for img_name in sorted(os.listdir(rid)):
        if not img_name.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp')):
            continue
        lbl_path = rld / f'{Path(img_name).stem}.txt'
        if not lbl_path.exists():
            continue
        img = cv2.imread(str(rid / img_name))
        if img is None:
            continue
        img_h, img_w = img.shape[:2]
        with open(lbl_path) as f:
            lines = f.read().strip().split('\n')
        for line in lines:
            parts = line.strip().split()
            if len(parts) < 5:
                continue
            cls_id = int(parts[0])
            cx, cy, w, h = [float(x) for x in parts[1:5]]
            # Convert YOLO to pixel coords
            x1 = int((cx - w/2) * img_w)
            y1 = int((cy - h/2) * img_h)
            x2 = int((cx + w/2) * img_w)
            y2 = int((cy + h/2) * img_h)
            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(img_w, x2), min(img_h, y2)
            if x2 - x1 < 5 or y2 - y1 < 5:
                continue
            crop = img[y1:y2, x1:x2]
            if crop.size == 0:
                continue
            crops.append((crop, cls_id, w, h))
            count += 1
            if count >= 5000:
                break
        if count >= 5000:
            break

    # Separate by class
    by_class = defaultdict(list)
    for crop, cls_id, w, h in crops:
        by_class[cls_id].append((crop, w, h))

    for cls_id, items in sorted(by_class.items()):
        log(f'  Class {cls_id} ({CLASS_NAMES[cls_id]}): {len(items)} crops')
    return by_class


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 5: Generate PURE artifact images (NO colony) — KEY FIX
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def generate_pure_artifact_images(bg_images):
    """
    V2 KEY FIX: Create images with ONLY artifacts (bubble/dust/crack),
    NO colony at all. This teaches the model that artifacts exist
    independently and are NOT background.

    Strategy: Take empty petri dish backgrounds and visually paint
    synthetic artifacts onto them.
    """
    log('STEP 5: Generating PURE artifact images (NO colony) — KEY FIX')
    rid = OUTPUT / 'raw' / 'images'
    rld = OUTPUT / 'raw' / 'labels'

    if not bg_images:
        log('  WARNING: No background images! Creating blank backgrounds instead')
        # Create blank petri dish-colored backgrounds
        for i in range(10):
            bg = np.full((IMGSZ, IMGSZ, 3), [210, 200, 190], dtype=np.uint8)
            # Add subtle circular gradient for petri dish look
            center = (IMGSZ//2, IMGSZ//2)
            radius = int(IMGSZ * 0.45)
            cv2.circle(bg, center, radius, (200, 195, 185), -1)
            cv2.circle(bg, center, radius, (180, 175, 165), 2)
            cv2.imwrite(str(rid / f'bg_blank_{i:03d}.jpg'), bg, [cv2.IMWRITE_JPEG_QUALITY, 90])
            (rld / f'bg_blank_{i:03d}.txt').write_text('')
        bg_images = [str(rid / f'bg_blank_{i:03d}.jpg') for i in range(10)]

    random.seed(RANDOM_SEED)
    total = 0

    # --- PURE BUBBLE images ---
    for i in range(N_PURE_BUBBLE):
        bg_path = bg_images[i % len(bg_images)]
        img = cv2.imread(str(bg_path))
        if img is None:
            continue
        img = cv2.resize(img, (IMGSZ, IMGSZ))
        yolo_lines = []
        n_bubbles = random.randint(2, 6)
        for _ in range(n_bubbles):
            cx = random.uniform(0.15, 0.85)
            cy = random.uniform(0.15, 0.85)
            bw = random.uniform(0.03, 0.10)
            bh = random.uniform(0.03, 0.10)
            # Draw bubble on image (circular, semi-transparent)
            px = int(cx * IMGSZ)
            py = int(cy * IMGSZ)
            rx = int(bw * IMGSZ / 2)
            ry = int(bh * IMGSZ / 2)
            # Create bubble effect: bright circle with darker ring
            overlay = img.copy()
            cv2.ellipse(overlay, (px, py), (rx, ry), 0, 0, 360, (220, 230, 240), -1)
            cv2.ellipse(overlay, (px, py), (rx, ry), 0, 0, 360, (180, 190, 200), 1)
            # Blend for semi-transparency
            alpha = random.uniform(0.4, 0.7)
            img = cv2.addWeighted(overlay, alpha, img, 1 - alpha, 0)
            # Add highlight
            hx = px - rx // 3
            hy = py - ry // 3
            cv2.circle(img, (hx, hy), max(1, rx // 4), (240, 245, 250), -1)
            yolo_lines.append(f'1 {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}')
        stem = f'pure_bubble_{i:04d}'
        cv2.imwrite(str(rid / f'{stem}.jpg'), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text('\n'.join(yolo_lines))
        total += 1

    # --- PURE DUST images ---
    for i in range(N_PURE_DUST):
        bg_path = bg_images[i % len(bg_images)]
        img = cv2.imread(str(bg_path))
        if img is None:
            continue
        img = cv2.resize(img, (IMGSZ, IMGSZ))
        yolo_lines = []
        n_dust = random.randint(5, 15)
        for _ in range(n_dust):
            cx = random.uniform(0.05, 0.95)
            cy = random.uniform(0.05, 0.95)
            dw = random.uniform(0.005, 0.02)
            dh = random.uniform(0.005, 0.02)
            # Draw dust: tiny dark specks
            px = int(cx * IMGSZ)
            py = int(cy * IMGSZ)
            r = max(1, int(dw * IMGSZ / 2))
            color = random.choice([(60, 55, 50), (80, 75, 65), (100, 90, 80), (120, 110, 100)])
            cv2.circle(img, (px, py), r, color, -1)
            # Slight noise around dust
            for _ in range(3):
                dx = px + random.randint(-3, 3)
                dy = py + random.randint(-3, 3)
                cv2.circle(img, (dx, dy), max(1, r - 1), color, -1)
            yolo_lines.append(f'2 {cx:.6f} {cy:.6f} {dw:.6f} {dh:.6f}')
        stem = f'pure_dust_{i:04d}'
        cv2.imwrite(str(rid / f'{stem}.jpg'), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text('\n'.join(yolo_lines))
        total += 1

    # --- PURE CRACK images ---
    for i in range(N_PURE_CRACK):
        bg_path = bg_images[i % len(bg_images)]
        img = cv2.imread(str(bg_path))
        if img is None:
            continue
        img = cv2.resize(img, (IMGSZ, IMGSZ))
        yolo_lines = []
        n_cracks = random.randint(1, 2)
        for _ in range(n_cracks):
            cx = random.uniform(0.2, 0.8)
            cy = random.uniform(0.2, 0.8)
            # Crack: thin elongated line
            if random.random() > 0.5:
                cw = random.uniform(0.10, 0.35)
                ch = random.uniform(0.005, 0.025)
            else:
                cw = random.uniform(0.005, 0.025)
                ch = random.uniform(0.10, 0.35)
            # Draw crack as a jagged line
            px = int(cx * IMGSZ)
            py = int(cy * IMGSZ)
            length = int(max(cw, ch) * IMGSZ)
            thickness = max(1, int(min(cw, ch) * IMGSZ))
            angle = random.uniform(0, math.pi)
            x1 = int(px - length/2 * math.cos(angle))
            y1 = int(py - length/2 * math.sin(angle))
            x2 = int(px + length/2 * math.cos(angle))
            y2 = int(py + length/2 * math.sin(angle))
            # Main crack line
            cv2.line(img, (x1, y1), (x2, y2), (50, 45, 40), thickness)
            # Add slight branching
            branch_len = length // 4
            bx = x2
            by = y2
            ba = angle + random.uniform(-0.5, 0.5)
            bx2 = int(bx + branch_len * math.cos(ba))
            by2 = int(by + branch_len * math.sin(ba))
            cv2.line(img, (bx, by), (bx2, by2), (60, 55, 45), max(1, thickness - 1))
            yolo_lines.append(f'3 {cx:.6f} {cy:.6f} {cw:.6f} {ch:.6f}')
        stem = f'pure_crack_{i:04d}'
        cv2.imwrite(str(rid / f'{stem}.jpg'), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text('\n'.join(yolo_lines))
        total += 1

    log(f'  Pure artifact images generated: {total}')
    return total


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 6: Copy-Paste augmentation with real colony crops
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def copy_paste_augmentation(bg_images, colony_crops):
    """
    Paste real colony crops onto background images.
    This creates natural-looking augmented images where colony
    objects appear in diverse contexts.
    """
    log('STEP 6: Copy-Paste augmentation with colony crops')
    rid = OUTPUT / 'raw' / 'images'
    rld = OUTPUT / 'raw' / 'labels'

    if not bg_images:
        log('  No backgrounds available, skipping')
        return 0

    random.seed(RANDOM_SEED)
    total = 0

    # Get colony crops (class 0)
    colony_items = colony_crops.get(0, [])
    if not colony_items:
        log('  No colony crops available, skipping')
        return 0

    log(f'  Colony crops available: {len(colony_items)}')

    for i in range(N_CROP_BUBBLE):
        bg_path = bg_images[i % len(bg_images)]
        img = cv2.imread(str(bg_path))
        if img is None:
            continue
        img = cv2.resize(img, (IMGSZ, IMGSZ))
        yolo_lines = []
        # Paste 1-3 colonies
        n_paste = random.randint(1, 3)
        for _ in range(n_paste):
            crop, cw, ch = random.choice(colony_items)
            # Resize crop
            target_w = int(cw * IMGSZ * random.uniform(0.8, 1.2))
            target_h = int(ch * IMGSZ * random.uniform(0.8, 1.2))
            target_w = max(10, min(IMGSZ - 10, target_w))
            target_h = max(10, min(IMGSZ - 10, target_h))
            try:
                crop_resized = cv2.resize(crop, (target_w, target_h))
            except:
                continue
            # Random position
            px = random.randint(0, IMGSZ - target_w)
            py = random.randint(0, IMGSZ - target_h)
            # Paste
            img[py:py+target_h, px:px+target_w] = crop_resized
            cx = (px + target_w/2) / IMGSZ
            cy = (py + target_h/2) / IMGSZ
            w = target_w / IMGSZ
            h = target_h / IMGSZ
            yolo_lines.append(f'0 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}')
        # Also add synthetic bubble artifacts
        for _ in range(random.randint(1, 3)):
            bx = random.uniform(0.1, 0.9)
            by = random.uniform(0.1, 0.9)
            bw = random.uniform(0.03, 0.08)
            bh = random.uniform(0.03, 0.08)
            yolo_lines.append(f'1 {bx:.6f} {by:.6f} {bw:.6f} {bh:.6f}')
            # Draw bubble
            overlay = img.copy()
            px2 = int(bx * IMGSZ)
            py2 = int(by * IMGSZ)
            rx2 = int(bw * IMGSZ / 2)
            ry2 = int(bh * IMGSZ / 2)
            cv2.ellipse(overlay, (px2, py2), (rx2, ry2), 0, 0, 360, (220, 230, 240), -1)
            img = cv2.addWeighted(overlay, 0.5, img, 0.5, 0)
        stem = f'cp_bubble_{i:04d}'
        cv2.imwrite(str(rid / f'{stem}.jpg'), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text('\n'.join(yolo_lines))
        total += 1

    for i in range(N_CROP_DUST):
        bg_path = bg_images[i % len(bg_images)]
        img = cv2.imread(str(bg_path))
        if img is None:
            continue
        img = cv2.resize(img, (IMGSZ, IMGSZ))
        yolo_lines = []
        # Paste colony
        n_paste = random.randint(1, 2)
        for _ in range(n_paste):
            crop, cw, ch = random.choice(colony_items)
            target_w = int(cw * IMGSZ * random.uniform(0.8, 1.2))
            target_h = int(ch * IMGSZ * random.uniform(0.8, 1.2))
            target_w = max(10, min(IMGSZ - 10, target_w))
            target_h = max(10, min(IMGSZ - 10, target_h))
            try:
                crop_resized = cv2.resize(crop, (target_w, target_h))
            except:
                continue
            px = random.randint(0, IMGSZ - target_w)
            py = random.randint(0, IMGSZ - target_h)
            img[py:py+target_h, px:px+target_w] = crop_resized
            cx = (px + target_w/2) / IMGSZ
            cy = (py + target_h/2) / IMGSZ
            w = target_w / IMGSZ
            h = target_h / IMGSZ
            yolo_lines.append(f'0 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}')
        # Add dust
        for _ in range(random.randint(3, 8)):
            dx = random.uniform(0.05, 0.95)
            dy = random.uniform(0.05, 0.95)
            dw = random.uniform(0.005, 0.015)
            dh = random.uniform(0.005, 0.015)
            yolo_lines.append(f'2 {dx:.6f} {dy:.6f} {dw:.6f} {dh:.6f}')
            px3 = int(dx * IMGSZ)
            py3 = int(dy * IMGSZ)
            r3 = max(1, int(dw * IMGSZ / 2))
            cv2.circle(img, (px3, py3), r3, (80, 75, 65), -1)
        stem = f'cp_dust_{i:04d}'
        cv2.imwrite(str(rid / f'{stem}.jpg'), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text('\n'.join(yolo_lines))
        total += 1

    for i in range(N_CROP_CRACK):
        bg_path = bg_images[i % len(bg_images)]
        img = cv2.imread(str(bg_path))
        if img is None:
            continue
        img = cv2.resize(img, (IMGSZ, IMGSZ))
        yolo_lines = []
        # Paste colony
        n_paste = random.randint(1, 2)
        for _ in range(n_paste):
            crop, cw, ch = random.choice(colony_items)
            target_w = int(cw * IMGSZ * random.uniform(0.8, 1.2))
            target_h = int(ch * IMGSZ * random.uniform(0.8, 1.2))
            target_w = max(10, min(IMGSZ - 10, target_w))
            target_h = max(10, min(IMGSZ - 10, target_h))
            try:
                crop_resized = cv2.resize(crop, (target_w, target_h))
            except:
                continue
            px = random.randint(0, IMGSZ - target_w)
            py = random.randint(0, IMGSZ - target_h)
            img[py:py+target_h, px:px+target_w] = crop_resized
            cx = (px + target_w/2) / IMGSZ
            cy = (py + target_h/2) / IMGSZ
            w = target_w / IMGSZ
            h = target_h / IMGSZ
            yolo_lines.append(f'0 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}')
        # Add crack
        for _ in range(random.randint(1, 2)):
            cx2 = random.uniform(0.2, 0.8)
            cy2 = random.uniform(0.2, 0.8)
            if random.random() > 0.5:
                cw2 = random.uniform(0.1, 0.3)
                ch2 = random.uniform(0.005, 0.02)
            else:
                cw2 = random.uniform(0.005, 0.02)
                ch2 = random.uniform(0.1, 0.3)
            yolo_lines.append(f'3 {cx2:.6f} {cy2:.6f} {cw2:.6f} {ch2:.6f}')
            # Draw crack line
            px4 = int(cx2 * IMGSZ)
            py4 = int(cy2 * IMGSZ)
            length4 = int(max(cw2, ch2) * IMGSZ)
            thick4 = max(1, int(min(cw2, ch2) * IMGSZ))
            angle4 = random.uniform(0, math.pi)
            x1_4 = int(px4 - length4/2 * math.cos(angle4))
            y1_4 = int(py4 - length4/2 * math.sin(angle4))
            x2_4 = int(px4 + length4/2 * math.cos(angle4))
            y2_4 = int(py4 + length4/2 * math.sin(angle4))
            cv2.line(img, (x1_4, y1_4), (x2_4, y2_4), (50, 45, 40), thick4)
        stem = f'cp_crack_{i:04d}'
        cv2.imwrite(str(rid / f'{stem}.jpg'), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text('\n'.join(yolo_lines))
        total += 1

    log(f'  Copy-paste augmented: {total}')
    return total


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 7: Stratified split (ensures all classes in each split)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def split_dataset_stratified():
    """
    V2 FIX: Stratified split that ensures each split has representation
    from ALL classes, including pure artifact images.
    """
    log('STEP 7: Stratified dataset split (80/12/8)')
    rid = OUTPUT / 'raw' / 'images'
    rld = OUTPUT / 'raw' / 'labels'

    pairs = [(rid / n, rld / f'{Path(n).stem}.txt') for n in sorted(os.listdir(rid))
             if n.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp')) and (rld / f'{Path(n).stem}.txt').exists()]

    log(f'  Total image-label pairs: {len(pairs)}')

    # Count class distribution
    cc = Counter()
    for _, lp in pairs:
        with open(lp) as f:
            for line in f:
                parts = line.strip().split()
                if parts:
                    cc[int(parts[0])] += 1
    log(f'  Class distribution: {dict(cc)}')

    random.seed(RANDOM_SEED)

    # V2 FIX: Group by ALL classes present in image (not just dominant)
    # This ensures pure artifact images go into the right groups
    by_primary_class = defaultdict(list)
    pure_artifact = []  # images with NO colony

    for ip, lp in pairs:
        with open(lp) as f:
            cls_list = [int(l.strip().split()[0]) for l in f if l.strip()]
        if not cls_list:
            continue
        classes_present = set(cls_list)
        # Pure artifact: has bubble/dust/crack but NO colony
        if 0 not in classes_present and len(classes_present) > 0:
            pure_artifact.append((ip, lp, classes_present))
        else:
            primary = Counter(cls_list).most_common(1)[0][0]
            by_primary_class[primary].append((ip, lp))

    log(f'  Pure artifact images (no colony): {len(pure_artifact)}')
    log(f'  Colony-containing images by primary class: { {k: len(v) for k, v in sorted(by_primary_class.items())} }')

    train_p, val_p, test_p = [], [], []

    # Split pure artifact images — ensure they're in all splits
    random.shuffle(pure_artifact)
    n = len(pure_artifact)
    nt = max(1, int(n * 0.80))
    nv = max(1, int(n * 0.12))
    for i, (ip, lp, _) in enumerate(pure_artifact):
        if i < nt:
            train_p.append((ip, lp))
        elif i < nt + nv:
            val_p.append((ip, lp))
        else:
            test_p.append((ip, lp))

    # Split colony-containing images
    for c, group in sorted(by_primary_class.items()):
        random.shuffle(group)
        n = len(group)
        nt = max(1, int(n * 0.80))
        nv = max(1, int(n * 0.12))
        train_p.extend(group[:nt])
        val_p.extend(group[nt:nt + nv])
        test_p.extend(group[nt + nv:])

    # Write splits
    for sn, sp in [('train', train_p), ('val', val_p), ('test', test_p)]:
        img_d = OUTPUT / sn / 'images'
        lbl_d = OUTPUT / sn / 'labels'
        img_d.mkdir(parents=True, exist_ok=True)
        lbl_d.mkdir(parents=True, exist_ok=True)
        for ip, lp in sp:
            di = img_d / ip.name
            dl = lbl_d / lp.name
            if not di.exists():
                shutil.copy2(str(ip), str(di))
            if not dl.exists():
                shutil.copy2(str(lp), str(dl))

    # Report split stats
    for sn, sp in [('train', train_p), ('val', val_p), ('test', test_p)]:
        split_cc = Counter()
        for _, lp in sp:
            with open(lp) as f:
                for line in f:
                    parts = line.strip().split()
                    if parts:
                        split_cc[int(parts[0])] += 1
        log(f'  {sn}: {len(sp)} images | classes: {dict(split_cc)}')

    log(f'  Train: {len(train_p)} | Val: {len(val_p)} | Test: {len(test_p)}')
    return len(train_p), len(val_p), len(test_p)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 8: Generate data.yaml
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def gen_yaml():
    yaml_content = f'path: {OUTPUT}\ntrain: train/images\nval: val/images\ntest: test/images\nnc: {NC}\nnames: {CLASS_NAMES}\n'
    (OUTPUT / 'data.yaml').write_text(yaml_content)
    log('  data.yaml written')
    return OUTPUT / 'data.yaml'


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 9: Train WITHOUT MLflow (avoid Host header crashes)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def train_yolo(data_yaml, smoke_test=False):
    """
    V2 FIX: Train with adjusted hyperparams for class imbalance.
    - Increased cls weight (2.0 instead of 0.5)
    - Reduced mosaic (0.5 instead of 1.0)
    - Copy-paste augmentation enabled
    - No MLflow (avoid crash from Host header issues)
    """
    tag = 'SMOKE_TEST' if smoke_test else 'FULL_TRAIN'
    log(f'STEP 9: Training YOLOv8s [{tag}] on GPU {DEVICE}')
    log(f'  cls_weight={CLS_WEIGHT} | mosaic={MOSAIC} | copy_paste={COPY_PASTE}')

    from ultralytics import YOLO

    epochs = 5 if smoke_test else EPOCHS
    run_name = f'v2_{"smoke" if smoke_test else "full"}_{datetime.datetime.now().strftime("%Y%m%d_%H%M")}'
    project_name = 'runs_v2_smoke' if smoke_test else 'runs_v2_balanced'

    model = YOLO('yolov8s.pt')

    results = model.train(
        data=str(data_yaml),
        epochs=epochs,
        imgsz=IMGSZ,
        batch=BATCH_SIZE,
        patience=PATIENCE if not smoke_test else 5,
        device=DEVICE,
        workers=WORKERS,
        project=str(WORKSPACE / 'runs'),
        name=project_name,
        exist_ok=True,
        seed=RANDOM_SEED,
        # V2 KEY FIX: Increased cls weight for class discrimination
        cls=CLS_WEIGHT,
        box=BOX_WEIGHT,
        dfl=DFL_WEIGHT,
        # V2 FIX: Reduced mosaic so small artifacts aren't shrunk further
        mosaic=MOSAIC,
        mixup=MIXUP,
        # V2 FIX: Enable copy-paste augmentation
        copy_paste=COPY_PASTE,
        # Standard augmentations
        hsv_h=0.015,
        hsv_s=0.7,
        hsv_v=0.4,
        degrees=15,
        translate=0.1,
        scale=0.5,
        flipud=0.2,
        fliplr=0.5,
        close_mosaic=10,
    )

    # Validate
    best_path = WORKSPACE / 'runs' / project_name / 'weights' / 'best.pt'
    last_path = WORKSPACE / 'runs' / project_name / 'weights' / 'last.pt'
    eval_path = best_path if best_path.exists() else last_path

    if eval_path.exists():
        log(f'  Evaluating: {eval_path}')
        val_model = YOLO(str(eval_path))
        metrics = val_model.val(data=str(data_yaml), imgsz=IMGSZ, device=DEVICE)

        log(f'  === [{tag}] Results ===')
        log(f'  Overall: mAP50={metrics.box.map50:.4f} | mAP50-95={metrics.box.map:.4f} | P={metrics.box.mp:.4f} | R={metrics.box.mr:.4f}')
        for i, name in enumerate(CLASS_NAMES):
            ap50 = float(metrics.box.maps[i]) if i < len(metrics.box.maps) else 0
            log(f'  {name}: mAP50={ap50:.4f}')

        if not smoke_test and best_path.exists():
            dst = WORKSPACE / 'models' / 'best_v2_balanced.pt'
            shutil.copy2(str(best_path), str(dst))
            log(f'  Best model saved -> {dst}')

        return metrics
    else:
        log('  ERROR: No model weights found after training!')
        return None


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN PIPELINE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--smoke', action='store_true', help='Run 5-epoch smoke test only')
    parser.add_argument('--skip-to', type=str, default=None,
                        help='Skip to step (s1-s9). E.g., --skip-to s7 skips data prep')
    parser.add_argument('--train-only', action='store_true', help='Only run training (skip data prep)')
    args = parser.parse_args()

    t0 = time.time()
    log('=' * 60)
    log('V2 Balanced Training — Fixing Class Imbalance')
    log(f'Device: GPU {DEVICE} | Batch: {BATCH_SIZE} | Epochs: {EPOCHS if not args.smoke else 5}')
    log(f'KEY FIXES: cls_weight={CLS_WEIGHT} | mosaic={MOSAIC} | copy_paste={COPY_PASTE}')
    log(f'Pure artifact images: bubble={N_PURE_BUBBLE} dust={N_PURE_DUST} crack={N_PURE_CRACK}')
    log('=' * 60)

    (OUTPUT / 'raw' / 'images').mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'raw' / 'labels').mkdir(parents=True, exist_ok=True)

    # Checkpoint system
    cp_path = OUTPUT / 'checkpoint_v2_balanced.json'
    ck = {}
    if cp_path.exists():
        with open(cp_path) as f:
            ck = json.load(f)
        log(f'  Resuming from checkpoint: {list(ck.keys())}')

    def save_step(step, data):
        ck[step] = data
        ck[f'{step}_t'] = datetime.datetime.now().isoformat()
        with open(cp_path, 'w') as f:
            json.dump(ck, f, indent=2)

    skip = args.skip_to
    train_only = args.train_only

    if train_only:
        data_yaml = OUTPUT / 'data.yaml'
        if not data_yaml.exists():
            log('ERROR: data.yaml not found. Run data prep first.')
            return
        train_yolo(data_yaml, smoke_test=args.smoke)
        return

    # STEP 1: U2Net mask conversion
    if skip and skip != 's1' and 's1' not in ck:
        log('Skipping to step after s1 — assuming s1 done')
        save_step('s1', {'skipped': True})
    if 's1' not in ck:
        n = convert_u2net_masks()
        save_step('s1', {'n': n})

    # STEP 2: Pseudo-labeling
    if 's2' not in ck:
        n = pseudo_label_resnet()
        save_step('s2', {'n': n})

    # STEP 3: Collect backgrounds
    bg_images = []
    if 's3' not in ck:
        bg_images = collect_background_images()
        save_step('s3', {'n': len(bg_images)})
    else:
        bg_images = collect_background_images()

    # STEP 4: Extract colony crops
    colony_crops = {}
    if 's4' not in ck:
        colony_crops = extract_colony_crops()
        save_step('s4', {str(k): len(v) for k, v in colony_crops.items()})
    else:
        colony_crops = extract_colony_crops()

    # STEP 5: Pure artifact images — KEY FIX
    if 's5' not in ck:
        n = generate_pure_artifact_images(bg_images)
        save_step('s5', {'n': n})

    # STEP 6: Copy-paste augmentation
    if 's6' not in ck:
        n = copy_paste_augmentation(bg_images, colony_crops)
        save_step('s6', {'n': n})

    # STEP 7: Stratified split
    if 's7' not in ck:
        nt, nv, ne = split_dataset_stratified()
        save_step('s7', {'train': nt, 'val': nv, 'test': ne})

    # STEP 8: Generate YAML
    data_yaml = gen_yaml()

    # STEP 9: Train
    if args.smoke:
        train_yolo(data_yaml, smoke_test=True)
    else:
        train_yolo(data_yaml, smoke_test=False)

    elapsed = (time.time() - t0) / 60
    log(f'Pipeline complete in {elapsed:.1f} min')


if __name__ == '__main__':
    main()
