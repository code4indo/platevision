#!/usr/bin/env python3
"""
Training Script V3 — Fine-tune from V2 with Enhanced Crack/Dust Detection
==========================================================================
IMPROVEMENTS OVER V2:
  1. Fine-tune from V2 best.pt (not from scratch) — preserves learned features
  2. Better crack generation: curved, jagged, branching, more realistic
  3. More crack data: 800 pure crack images (was 300)
  4. Minimum crack bbox size: 0.02 (was 0.005) — more detectable
  5. Class-balanced oversampling: crack 5x, dust 3x
  6. Lower initial LR for fine-tuning: 0.001 (was 0.01)
  7. Cosine LR scheduler for smoother convergence
  8. Extended training: 200 epochs with patience 50
  9. Disable MLflow to avoid crashes
  10. Smoke test mode (5 epochs) for verification

USAGE:
  python train_4class_v3.py                     # Full training
  python train_4class_v3.py --smoke-test        # Smoke test (5 epochs)
  python train_4class_v3.py --skip-data-prep    # Skip data prep, train only
"""
import os, sys, json, time, shutil, random, datetime, math, argparse
from pathlib import Path
from collections import Counter, defaultdict
import cv2, numpy as np
from scipy import ndimage

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WORKSPACE = Path('/media/lambda_one/DFSSD04/project/healtcare')
AGAR = WORKSPACE / 'data/agar'
V2_DATA = WORKSPACE / 'data/yolo_v2_balanced'
OUTPUT = WORKSPACE / 'data/yolo_v3_enhanced'
V2_BEST = WORKSPACE / 'runs/runs_v2_balanced/weights/best.pt'

CLASS_NAMES = ['colony', 'bubble', 'dust', 'crack']
NC = 4
RANDOM_SEED = 42

# Training hyperparams
EPOCHS = 200
BATCH_SIZE = 16
IMGSZ = 640
PATIENCE = 50
DEVICE = '1'
WORKERS = 6

# Fine-tuning: lower LR than training from scratch
LR0 = 0.001      # was 0.01 in V2
LRF = 0.01
COS_LR = True     # cosine LR scheduler

# Loss weights
CLS_WEIGHT = 2.5   # increased from 2.0 → 2.5 for better class discrimination
BOX_WEIGHT = 7.5
DFL_WEIGHT = 1.5

# Augmentation
MOSAIC = 0.4       # reduced from 0.5 → so individual objects aren't too small
MIXUP = 0.05       # reduced from 0.1
COPY_PASTE = 0.3
FLIPUD = 0.3       # increased from 0.2
FLIPLR = 0.5
HSV_H = 0.015
HSV_S = 0.7
HSV_V = 0.4
DEGREES = 10       # reduced from 15 → less rotation for crack detection
TRANSLATE = 0.1
SCALE = 0.5
ERASING = 0.3      # reduced from 0.4

# V3: Enhanced artifact generation
N_PURE_BUBBLE = 400    # same as V2
N_PURE_DUST = 500      # increased from 350
N_PURE_CRACK = 800     # increased from 300 — KEY IMPROVEMENT
N_CROP_BUBBLE = 300    # same
N_CROP_DUST = 350      # increased from 250
N_CROP_CRACK = 500     # increased from 200 — KEY IMPROVEMENT

# V3: Minimum bbox sizes (in normalized coords)
MIN_CRACK_SIZE = 0.02   # was ~0.005 in V2, too small for YOLO
MIN_DUST_SIZE = 0.008   # was ~0.005 in V2
MIN_BUBBLE_SIZE = 0.03  # same as V2

# V3: Oversampling factors for class-balanced training
OVERSAMPLE_CRACK = 5     # repeat crack images 5x
OVERSAMPLE_DUST = 3      # repeat dust images 3x
OVERSAMPLE_BUBBLE = 2    # repeat bubble images 2x

# Pseudo-labeling params (reuse V2)
PL_CONF = 0.20
MAX_PER_BUCKET = 1000
MIN_COLONY_AREA = 8

# MLflow - DISABLED to avoid crashes
MLFLOW_ENABLED = False

def log(msg):
    ts = datetime.datetime.now().strftime('%H:%M:%S')
    print(f'[{ts}] {msg}', flush=True)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 1: Copy V2 dataset as base
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def copy_v2_dataset():
    """Copy V2 balanced dataset as the foundation for V3"""
    log('STEP 1: Copying V2 balanced dataset as V3 base')
    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)

    # Copy entire V2 dataset
    shutil.copytree(V2_DATA, OUTPUT)

    # Count existing data
    for split in ['train', 'val', 'test']:
        img_dir = OUTPUT / split / 'images'
        lbl_dir = OUTPUT / split / 'labels'
        n_img = len(list(img_dir.glob('*')))
        n_lbl = len(list(lbl_dir.glob('*')))
        log(f'  {split}: {n_img} images, {n_lbl} labels (from V2)')
    return True


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2: Generate enhanced pure artifact images (CRACK FOCUS)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def collect_background_images():
    """Get empty/near-empty petri dish images as backgrounds"""
    log('  Collecting background images...')
    bg_dir = V2_DATA / 'raw' / 'images'  # Reuse V2 backgrounds
    bg_images = []
    if bg_dir.exists():
        for f in sorted(bg_dir.glob('bg_*')):
            bg_images.append(str(f))
    log(f'  Found {len(bg_images)} background images from V2')
    return bg_images


def generate_enhanced_crack_images(bg_images, n_images=N_PURE_CRACK):
    """
    V3 KEY IMPROVEMENT: Much more realistic crack generation

    Improvements over V2:
    - Curved/irregular crack paths (not just straight lines)
    - Multiple branching patterns
    - Variable thickness along the crack
    - More realistic appearance with texture
    - Minimum bounding box size enforced (0.02)
    - Multiple crack styles: straight, curved, star, network
    """
    log(f'  Generating {n_images} ENHANCED pure crack images')

    rid = OUTPUT / 'train' / 'images'
    rld = OUTPUT / 'train' / 'labels'

    random.seed(RANDOM_SEED + 42)  # Different seed for V3
    total = 0

    for i in range(n_images):
        # Choose background
        if bg_images:
            bg_path = bg_images[i % len(bg_images)]
            img = cv2.imread(str(bg_path))
            if img is None:
                img = np.full((IMGSZ, IMGSZ, 3), [210, 200, 190], dtype=np.uint8)
            else:
                img = cv2.resize(img, (IMGSZ, IMGSZ))
        else:
            img = np.full((IMGSZ, IMGSZ, 3), [210, 200, 190], dtype=np.uint8)

        yolo_lines = []
        n_cracks = random.randint(1, 3)

        for _ in range(n_cracks):
            # Choose crack style
            crack_style = random.choice(['curved', 'jagged', 'branching', 'network'])

            if crack_style == 'curved':
                # Curved crack: generate a smooth curve
                points = []
                start_x = random.uniform(0.1, 0.4)
                start_y = random.uniform(0.2, 0.8)
                length = random.uniform(0.15, 0.4)
                n_pts = random.randint(8, 15)
                angle = random.uniform(0, 2 * math.pi)
                curvature = random.uniform(-0.3, 0.3)

                for j in range(n_pts):
                    t = j / (n_pts - 1)
                    x = start_x + t * length * math.cos(angle) + curvature * math.sin(angle * t)
                    y = start_y + t * length * math.sin(angle) - curvature * math.cos(angle * t)
                    x = max(0.02, min(0.98, x))
                    y = max(0.02, min(0.98, y))
                    points.append((int(x * IMGSZ), int(y * IMGSZ)))

                # Draw with variable thickness
                for j in range(len(points) - 1):
                    thickness = max(1, random.randint(1, 3))
                    color = random.choice([(40, 35, 30), (50, 45, 38), (60, 52, 42)])
                    cv2.line(img, points[j], points[j+1], color, thickness)

                # Compute bounding box
                xs = [p[0] / IMGSZ for p in points]
                ys = [p[1] / IMGSZ for p in points]
                cx = (min(xs) + max(xs)) / 2
                cy = (min(ys) + max(ys)) / 2
                cw = max(MIN_CRACK_SIZE, max(xs) - min(xs))
                ch = max(MIN_CRACK_SIZE, max(ys) - min(ys))
                # Ensure bbox doesn't exceed image bounds
                cw = min(cw, min(cx * 2, (1.0 - cx) * 2))
                ch = min(ch, min(cy * 2, (1.0 - cy) * 2))

                yolo_lines.append(f'3 {cx:.6f} {cy:.6f} {cw:.6f} {ch:.6f}')

            elif crack_style == 'jagged':
                # Jagged crack: zigzag pattern
                start_x = random.uniform(0.1, 0.3)
                start_y = random.uniform(0.1, 0.9)
                length = random.uniform(0.2, 0.5)
                angle = random.uniform(0, 2 * math.pi)
                n_segs = random.randint(5, 10)

                points = []
                px, py = start_x, start_y
                for j in range(n_segs):
                    # Zigzag offset
                    offset = random.uniform(-0.03, 0.03)
                    seg_len = length / n_segs
                    px += seg_len * math.cos(angle) + offset * math.cos(angle + math.pi/2)
                    py += seg_len * math.sin(angle) + offset * math.sin(angle + math.pi/2)
                    px = max(0.02, min(0.98, px))
                    py = max(0.02, min(0.98, py))
                    points.append((int(px * IMGSZ), int(py * IMGSZ)))

                # Draw
                for j in range(len(points) - 1):
                    thickness = max(1, random.randint(1, 3))
                    color = random.choice([(45, 40, 35), (55, 48, 40), (65, 56, 46)])
                    cv2.line(img, points[j], points[j+1], color, thickness)
                    # Add slight noise around the line
                    for _ in range(2):
                        nx = points[j+1][0] + random.randint(-2, 2)
                        ny = points[j+1][1] + random.randint(-2, 2)
                        cv2.circle(img, (nx, ny), 1, color, -1)

                # Compute bounding box
                xs = [p[0] / IMGSZ for p in points]
                ys = [p[1] / IMGSZ for p in points]
                cx = (min(xs) + max(xs)) / 2
                cy = (min(ys) + max(ys)) / 2
                cw = max(MIN_CRACK_SIZE, max(xs) - min(xs))
                ch = max(MIN_CRACK_SIZE, max(ys) - min(ys))
                yolo_lines.append(f'3 {cx:.6f} {cy:.6f} {cw:.6f} {ch:.6f}')

            elif crack_style == 'branching':
                # Main line with 2-3 branches
                # Main crack
                cx_main = random.uniform(0.2, 0.8)
                cy_main = random.uniform(0.2, 0.8)
                main_angle = random.uniform(0, math.pi)
                main_len = random.uniform(0.1, 0.3)

                x1 = int((cx_main - main_len/2 * math.cos(main_angle)) * IMGSZ)
                y1 = int((cy_main - main_len/2 * math.sin(main_angle)) * IMGSZ)
                x2 = int((cx_main + main_len/2 * math.cos(main_angle)) * IMGSZ)
                y2 = int((cy_main + main_len/2 * math.sin(main_angle)) * IMGSZ)

                cv2.line(img, (x1, y1), (x2, y2), (45, 40, 35), 2)

                # Branches
                n_branches = random.randint(2, 3)
                all_xs = [x1/IMGSZ, x2/IMGSZ]
                all_ys = [y1/IMGSZ, y2/IMGSZ]

                for b in range(n_branches):
                    # Branch starts from random point on main line
                    t = random.uniform(0.3, 0.8)
                    bx = int((x1 + t * (x2 - x1)))
                    by = int((y1 + t * (y2 - y1)))
                    branch_angle = main_angle + random.choice([-1, 1]) * random.uniform(0.3, 1.0)
                    branch_len = main_len * random.uniform(0.3, 0.7) * IMGSZ
                    bx2 = int(bx + branch_len * math.cos(branch_angle))
                    by2 = int(by + branch_len * math.sin(branch_angle))
                    cv2.line(img, (bx, by), (bx2, by2), (50, 45, 38), max(1, random.randint(1, 2)))

                    all_xs.extend([bx/IMGSZ, bx2/IMGSZ])
                    all_ys.extend([by/IMGSZ, by2/IMGSZ])

                cx = (min(all_xs) + max(all_xs)) / 2
                cy = (min(all_ys) + max(all_ys)) / 2
                cw = max(MIN_CRACK_SIZE, max(all_xs) - min(all_xs))
                ch = max(MIN_CRACK_SIZE, max(all_ys) - min(all_ys))
                yolo_lines.append(f'3 {cx:.6f} {cy:.6f} {cw:.6f} {ch:.6f}')

            else:  # network
                # Star/network pattern: multiple lines from center
                cx_net = random.uniform(0.25, 0.75)
                cy_net = random.uniform(0.25, 0.75)
                n_rays = random.randint(3, 6)

                all_xs = []
                all_ys = []

                for r in range(n_rays):
                    angle = r * 2 * math.pi / n_rays + random.uniform(-0.3, 0.3)
                    ray_len = random.uniform(0.05, 0.2) * IMGSZ
                    ex = int(cx_net * IMGSZ + ray_len * math.cos(angle))
                    ey = int(cy_net * IMGSZ + ray_len * math.sin(angle))
                    cv2.line(img, (int(cx_net * IMGSZ), int(cy_net * IMGSZ)),
                            (ex, ey), (48, 42, 36), max(1, random.randint(1, 2)))
                    all_xs.append(ex / IMGSZ)
                    all_ys.append(ey / IMGSZ)

                all_xs.append(cx_net)
                all_ys.append(cy_net)
                bmin_x = min(all_xs)
                bmax_x = max(all_xs)
                bmin_y = min(all_ys)
                bmax_y = max(all_ys)
                cx = (bmin_x + bmax_x) / 2
                cy = (bmin_y + bmax_y) / 2
                cw = max(MIN_CRACK_SIZE, bmax_x - bmin_x)
                ch = max(MIN_CRACK_SIZE, bmax_y - bmin_y)
                yolo_lines.append(f'3 {cx:.6f} {cy:.6f} {cw:.6f} {ch:.6f}')

        stem = f'v3_pure_crack_{i:04d}'
        cv2.imwrite(str(rid / f'{stem}.jpg'), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text('\n'.join(yolo_lines))
        total += 1

    log(f'  Enhanced crack images generated: {total}')
    return total


def generate_enhanced_dust_images(bg_images, n_images=N_PURE_DUST):
    """
    V3 IMPROVEMENT: Better dust generation with clusters and varying sizes
    """
    log(f'  Generating {n_images} enhanced pure dust images')

    rid = OUTPUT / 'train' / 'images'
    rld = OUTPUT / 'train' / 'labels'

    random.seed(RANDOM_SEED + 43)
    total = 0

    for i in range(n_images):
        if bg_images:
            bg_path = bg_images[i % len(bg_images)]
            img = cv2.imread(str(bg_path))
            if img is None:
                img = np.full((IMGSZ, IMGSZ, 3), [210, 200, 190], dtype=np.uint8)
            else:
                img = cv2.resize(img, (IMGSZ, IMGSZ))
        else:
            img = np.full((IMGSZ, IMGSZ, 3), [210, 200, 190], dtype=np.uint8)

        yolo_lines = []

        # Generate dust in clusters (more realistic)
        n_clusters = random.randint(2, 5)
        for c in range(n_clusters):
            # Cluster center
            cluster_cx = random.uniform(0.1, 0.9)
            cluster_cy = random.uniform(0.1, 0.9)
            cluster_spread = random.uniform(0.03, 0.12)

            n_dust_in_cluster = random.randint(3, 10)
            cluster_xs = []
            cluster_ys = []

            for d in range(n_dust_in_cluster):
                # Individual dust within cluster
                dx = cluster_cx + random.gauss(0, cluster_spread / 3)
                dy = cluster_cy + random.gauss(0, cluster_spread / 3)
                dx = max(0.02, min(0.98, dx))
                dy = max(0.02, min(0.98, dy))

                # Variable dust size
                dw = random.uniform(MIN_DUST_SIZE, 0.025)
                dh = random.uniform(MIN_DUST_SIZE, 0.025)

                # Draw dust particle
                px = int(dx * IMGSZ)
                py = int(dy * IMGSZ)
                r = max(1, int(max(dw, dh) * IMGSZ / 2))
                color = random.choice([
                    (50, 45, 40), (70, 62, 55), (90, 80, 70),
                    (110, 98, 85), (130, 118, 105)
                ])
                cv2.circle(img, (px, py), r, color, -1)
                # Slight noise
                for _ in range(2):
                    nx = px + random.randint(-2, 2)
                    ny = py + random.randint(-2, 2)
                    cv2.circle(img, (nx, ny), max(1, r - 1), color, -1)

                cluster_xs.append(dx)
                cluster_ys.append(dy)

            # Create one bounding box per cluster (more practical for detection)
            if cluster_xs:
                min_x = min(cluster_xs) - 0.005
                max_x = max(cluster_xs) + 0.005
                min_y = min(cluster_ys) - 0.005
                max_y = max(cluster_ys) + 0.005
                # Ensure minimum size
                bw = max(MIN_DUST_SIZE * 2, max_x - min_x)
                bh = max(MIN_DUST_SIZE * 2, max_y - min_y)
                bcx = (min_x + max_x) / 2
                bcy = (min_y + max_y) / 2
                yolo_lines.append(f'2 {bcx:.6f} {bcy:.6f} {bw:.6f} {bh:.6f}')

        stem = f'v3_pure_dust_{i:04d}'
        cv2.imwrite(str(rid / f'{stem}.jpg'), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text('\n'.join(yolo_lines))
        total += 1

    log(f'  Enhanced dust images generated: {total}')
    return total


def generate_enhanced_bubble_images(bg_images, n_images=N_PURE_BUBBLE):
    """Generate enhanced bubble images (same quality as V2, already good at 0.995)"""
    log(f'  Generating {n_images} pure bubble images')

    rid = OUTPUT / 'train' / 'images'
    rld = OUTPUT / 'train' / 'labels'

    random.seed(RANDOM_SEED + 44)
    total = 0

    for i in range(n_images):
        if bg_images:
            bg_path = bg_images[i % len(bg_images)]
            img = cv2.imread(str(bg_path))
            if img is None:
                img = np.full((IMGSZ, IMGSZ, 3), [210, 200, 190], dtype=np.uint8)
            else:
                img = cv2.resize(img, (IMGSZ, IMGSZ))
        else:
            img = np.full((IMGSZ, IMGSZ, 3), [210, 200, 190], dtype=np.uint8)

        yolo_lines = []
        n_bubbles = random.randint(2, 8)
        for _ in range(n_bubbles):
            cx = random.uniform(0.15, 0.85)
            cy = random.uniform(0.15, 0.85)
            bw = random.uniform(MIN_BUBBLE_SIZE, 0.12)
            bh = random.uniform(MIN_BUBBLE_SIZE, 0.12)

            px = int(cx * IMGSZ)
            py = int(cy * IMGSZ)
            rx = int(bw * IMGSZ / 2)
            ry = int(bh * IMGSZ / 2)

            overlay = img.copy()
            cv2.ellipse(overlay, (px, py), (rx, ry), 0, 0, 360, (220, 230, 240), -1)
            cv2.ellipse(overlay, (px, py), (rx, ry), 0, 0, 360, (180, 190, 200), 1)
            alpha = random.uniform(0.4, 0.7)
            img = cv2.addWeighted(overlay, alpha, img, 1 - alpha, 0)
            # Highlight
            hx = px - rx // 3
            hy = py - ry // 3
            cv2.circle(img, (hx, hy), max(1, rx // 4), (240, 245, 250), -1)

            yolo_lines.append(f'1 {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}')

        stem = f'v3_pure_bubble_{i:04d}'
        cv2.imwrite(str(rid / f'{stem}.jpg'), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text('\n'.join(yolo_lines))
        total += 1

    log(f'  Bubble images generated: {total}')
    return total


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 3: Class-balanced oversampling
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def apply_class_oversampling():
    """
    V3 KEY IMPROVEMENT: Oversample images with rare classes

    For each training image, count its class distribution.
    Images with crack get duplicated 5x, dust 3x, bubble 2x.
    This ensures the training sees rare classes more often.
    """
    log('STEP 3: Applying class-balanced oversampling')

    img_dir = OUTPUT / 'train' / 'images'
    lbl_dir = OUTPUT / 'train' / 'labels'

    oversample_map = {0: 1, 1: OVERSAMPLE_BUBBLE, 2: OVERSAMPLE_DUST, 3: OVERSAMPLE_CRACK}

    total_original = 0
    total_oversampled = 0

    for lbl_file in sorted(lbl_dir.glob('*.txt')):
        total_original += 1
        classes_in_image = set()
        with open(lbl_file) as f:
            for line in f:
                parts = line.strip().split()
                if parts:
                    classes_in_image.add(int(parts[0]))

        # Determine max oversampling for this image
        max_factor = 1
        for cls_id in classes_in_image:
            max_factor = max(max_factor, oversample_map.get(cls_id, 1))

        if max_factor <= 1:
            continue

        # Get corresponding image
        stem = lbl_file.stem
        img_file = None
        for ext in ['.jpg', '.png', '.jpeg']:
            candidate = img_dir / f'{stem}{ext}'
            if candidate.exists():
                img_file = candidate
                break

        if img_file is None:
            continue

        # Create oversampled copies
        for copy_idx in range(1, max_factor):
            new_stem = f'{stem}_os{copy_idx}'
            # Copy image
            shutil.copy2(str(img_file), str(img_dir / f'{new_stem}{img_file.suffix}'))
            # Copy label
            shutil.copy2(str(lbl_file), str(lbl_dir / f'{new_stem}.txt'))
            total_oversampled += 1

    log(f'  Original: {total_original} images')
    log(f'  Oversampled additions: {total_oversampled} images')
    log(f'  Total after oversampling: {total_original + total_oversampled} images')
    return total_original + total_oversampled


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 4: Update data.yaml
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def gen_yaml():
    yaml_path = OUTPUT / 'data.yaml'
    content = f"""path: {OUTPUT}
train: train/images
val: val/images
test: test/images
nc: {NC}
names: {CLASS_NAMES}
"""
    yaml_path.write_text(content)
    log(f'  data.yaml written to {yaml_path}')
    return yaml_path


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 5: Verify dataset integrity
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def verify_dataset():
    """Quick sanity check on the dataset"""
    log('STEP 5: Verifying dataset integrity')

    for split in ['train', 'val', 'test']:
        img_dir = OUTPUT / split / 'images'
        lbl_dir = OUTPUT / split / 'labels'

        n_img = len(list(img_dir.glob('*')))
        n_lbl = len(list(lbl_dir.glob('*')))

        counts = Counter()
        total_instances = 0
        empty_labels = 0

        for lbl_file in lbl_dir.glob('*.txt'):
            with open(lbl_file) as f:
                lines = [l.strip() for l in f if l.strip()]
            if not lines:
                empty_labels += 1
                continue
            for line in lines:
                cls = int(line.split()[0])
                counts[cls] += 1
                total_instances += 1

        log(f'  {split}: {n_img} images, {n_lbl} labels, {total_instances} instances, {empty_labels} empty')
        for cls_id, name in enumerate(CLASS_NAMES):
            n = counts.get(cls_id, 0)
            pct = n / total_instances * 100 if total_instances > 0 else 0
            log(f'    {name}: {n} ({pct:.1f}%)')

    return True


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 6: Train YOLO (Fine-tune from V2)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def train_yolo(data_yaml, smoke_test=False):
    """
    V3 KEY: Fine-tune from V2 best.pt instead of training from scratch
    """
    log(f'STEP 6: Training YOLOv8s (fine-tune from V2) — smoke_test={smoke_test}')

    from ultralytics import YOLO

    # Load V2 best weights for fine-tuning
    if V2_BEST.exists():
        log(f'  Loading V2 best weights: {V2_BEST}')
        model = YOLO(str(V2_BEST))
    else:
        log(f'  WARNING: V2 best.pt not found, using pretrained YOLOv8s')
        model = YOLO('yolov8s.pt')

    epochs = 5 if smoke_test else EPOCHS
    patience = 3 if smoke_test else PATIENCE

    # Disable MLflow to avoid "Invalid Host header" crashes
    os.environ['MLFLOW_DISABLE'] = '1'
    os.environ['MLFLOW_TRACKING_URI'] = ''

    results = model.train(
        data=str(data_yaml),
        epochs=epochs,
        imgsz=IMGSZ,
        batch=BATCH_SIZE,
        patience=patience,
        device=DEVICE,
        workers=WORKERS,
        project=str(WORKSPACE / 'runs'),
        name='runs_v3_enhanced',
        exist_ok=True,
        pretrained=True,
        optimizer='AdamW',
        lr0=LR0,
        lrf=LRF,
        cos_lr=COS_LR,
        momentum=0.9,
        weight_decay=0.0005,
        warmup_epochs=5 if not smoke_test else 1,
        warmup_momentum=0.8,
        warmup_bias_lr=0.05,
        box=BOX_WEIGHT,
        cls=CLS_WEIGHT,
        dfl=DFL_WEIGHT,
        hsv_h=HSV_H,
        hsv_s=HSV_S,
        hsv_v=HSV_V,
        degrees=DEGREES,
        translate=TRANSLATE,
        scale=SCALE,
        flipud=FLIPUD,
        fliplr=FLIPLR,
        mosaic=MOSAIC,
        mixup=MIXUP,
        copy_paste=COPY_PASTE,
        copy_paste_mode='flip',
        auto_augment='randaugment',
        erasing=ERASING,
        close_mosaic=10,
        seed=RANDOM_SEED,
        deterministic=True,
        amp=True,
        val=True,
        save=True,
        plots=True,
        verbose=True,
    )

    log('Training completed!')
    return results


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 7: Validate and report per-class metrics
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def validate_model(run_dir=None):
    """Run detailed validation with per-class metrics"""
    log('STEP 7: Validating model with per-class metrics')

    from ultralytics import YOLO

    if run_dir is None:
        run_dir = WORKSPACE / 'runs/runs_v3_enhanced'
    best_pt = run_dir / 'weights/best.pt'

    if not best_pt.exists():
        log(f'  WARNING: {best_pt} not found, trying last.pt')
        best_pt = run_dir / 'weights/last.pt'

    model = YOLO(str(best_pt))
    results = model.val(data=str(OUTPUT / 'data.yaml'), verbose=True)

    # Print per-class results
    print('\n' + '='*70)
    print('V3 VALIDATION RESULTS — Per-Class Breakdown')
    print('='*70)
    print(f'{"Class":<12} {"Precision":>10} {"Recall":>10} {"mAP50":>10} {"mAP50-95":>10}')
    print('-'*70)

    for i, name in enumerate(CLASS_NAMES):
        if i < len(results.box.maps):
            p = results.box.mp  # mean precision
            r = results.box.mr  # mean recall
            map50 = results.box.map50
            map = results.box.map
            # Per class from maps array
            print(f'{name:<12} {"—":>10} {"—":>10} {results.box.maps[i]:>10.4f} {"—":>10}')

    # Use the per-class detailed output from Ultralytics
    print(f'\nOverall: P={results.box.mp:.4f} R={results.box.mr:.4f} mAP50={results.box.map50:.4f} mAP50-95={results.box.map:.4f}')
    print('='*70)

    return results


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def main():
    parser = argparse.ArgumentParser(description='V3 Training: Fine-tune with enhanced artifacts')
    parser.add_argument('--smoke-test', action='store_true', help='Run 5-epoch smoke test')
    parser.add_argument('--skip-data-prep', action='store_true', help='Skip data preparation')
    parser.add_argument('--validate-only', action='store_true', help='Only validate existing model')
    args = parser.parse_args()

    log('╔══════════════════════════════════════════════════════╗')
    log('║  V3 Training: Enhanced Crack/Dust Detection         ║')
    log('║  Fine-tune from V2 best.pt                          ║')
    log('╚══════════════════════════════════════════════════════╝')

    if args.validate_only:
        validate_model()
        return

    if not args.skip_data_prep:
        # Step 1: Copy V2 dataset
        copy_v2_dataset()

        # Step 2: Collect backgrounds
        bg_images = collect_background_images()

        # Step 3: Generate enhanced artifacts
        log('STEP 2: Generating enhanced artifact images')
        n_bubble = generate_enhanced_bubble_images(bg_images)
        n_dust = generate_enhanced_dust_images(bg_images)
        n_crack = generate_enhanced_crack_images(bg_images)
        log(f'  Total new artifact images: {n_bubble + n_dust + n_crack}')

        # Step 4: Apply class-balanced oversampling
        apply_class_oversampling()

        # Step 5: Update data.yaml
        data_yaml = gen_yaml()

        # Step 6: Verify
        verify_dataset()
    else:
        data_yaml = OUTPUT / 'data.yaml'

    # Step 7: Train
    results = train_yolo(data_yaml, smoke_test=args.smoke_test)

    # Step 8: Validate
    if not args.smoke_test:
        validate_model()

    log('V3 Training pipeline completed!')


if __name__ == '__main__':
    main()
