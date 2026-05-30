#!/usr/bin/env python3
import os, sys, json, time, shutil, random, datetime
from pathlib import Path
from collections import Counter, defaultdict
import cv2, numpy as np
from scipy import ndimage

WORKSPACE = Path('/media/lambda_one/DFSSD04/project/healtcare')
AGAR = WORKSPACE / 'data/agar'
OUTPUT = WORKSPACE / 'data/yolo_18k_multiclass'
MLFLOW_URI = 'http://localhost:5500'
MLFLOW_EXPERIMENT = 'plate_count_reader_18k'
CLASS_NAMES = ['colony', 'bubble', 'dust', 'crack']
NC = 4
RANDOM_SEED = 42
MIN_COLONY_AREA = 8
MAX_COLONIES = 3000
PL_CONF = 0.20
EPOCHS = 150
BATCH_SIZE = 16
IMGSZ = 640
PATIENCE = 30
DEVICE = '1'
WORKERS = 6
N_SYNTHETIC_BUBBLE = 1000
N_SYNTHETIC_DUST = 800
N_SYNTHETIC_CRACK = 500
MAX_PER_BUCKET = 1000

def log(msg):
    ts = datetime.datetime.now().strftime('%H:%M:%S')
    print(f'[{ts}] {msg}', flush=True)

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
            out_lbl.write_text(chr(10).join(yolo_lines))
            converted += 1
    log(f'  Converted: {converted}')
    return converted

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
                ol.write_text(chr(10).join(yolo_lines))
                labeled += 1
        if (i // bs) % 10 == 0:
            log(f'  Progress: {i}/{len(sampled)}, labeled: {labeled}')
    log(f'  Pseudo-labeled: {labeled}')
    return labeled

def generate_synthetic_artifacts():
    log('STEP 3: Generating synthetic artifacts')
    rid = OUTPUT / 'raw' / 'images'
    rld = OUTPUT / 'raw' / 'labels'
    labeled = [(rid / n, rld / f'{Path(n).stem}.txt') for n in sorted(os.listdir(rid))
               if n.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp')) and (rld / f'{Path(n).stem}.txt').exists()]
    log(f'  Base images with labels: {len(labeled)}')
    if not labeled:
        return 0
    random.seed(RANDOM_SEED)
    random.shuffle(labeled)
    aug = 0
    for i in range(N_SYNTHETIC_BUBBLE):
        si, sl = labeled[i % len(labeled)]
        img = cv2.imread(str(si))
        if img is None:
            continue
        existing = sl.read_text().strip().split(chr(10))
        new_lines = list(existing)
        for _ in range(random.randint(1, 3)):
            new_lines.append(f'1 {random.uniform(.1,.9):.6f} {random.uniform(.1,.9):.6f} {random.uniform(.02,.08):.6f} {random.uniform(.02,.08):.6f}')
        stem = f'aug_bubble_{i:04d}'
        img_r = cv2.resize(img, (IMGSZ, IMGSZ))
        cv2.imwrite(str(rid / f'{stem}.jpg'), img_r, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text(chr(10).join(new_lines))
        aug += 1
    for i in range(N_SYNTHETIC_DUST):
        si, sl = labeled[(i + 100) % len(labeled)]
        img = cv2.imread(str(si))
        if img is None:
            continue
        existing = sl.read_text().strip().split(chr(10))
        new_lines = list(existing)
        for _ in range(random.randint(3, 8)):
            new_lines.append(f'2 {random.uniform(.05,.95):.6f} {random.uniform(.05,.95):.6f} {random.uniform(.003,.015):.6f} {random.uniform(.003,.015):.6f}')
        stem = f'aug_dust_{i:04d}'
        img_r = cv2.resize(img, (IMGSZ, IMGSZ))
        cv2.imwrite(str(rid / f'{stem}.jpg'), img_r, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text(chr(10).join(new_lines))
        aug += 1
    for i in range(N_SYNTHETIC_CRACK):
        si, sl = labeled[(i + 200) % len(labeled)]
        img = cv2.imread(str(si))
        if img is None:
            continue
        existing = sl.read_text().strip().split(chr(10))
        new_lines = list(existing)
        for _ in range(random.randint(1, 2)):
            cx, cy = random.uniform(.2, .8), random.uniform(.2, .8)
            if random.random() > .5:
                w, h = random.uniform(.1, .3), random.uniform(.005, .02)
            else:
                w, h = random.uniform(.005, .02), random.uniform(.1, .3)
            new_lines.append(f'3 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}')
        stem = f'aug_crack_{i:04d}'
        img_r = cv2.resize(img, (IMGSZ, IMGSZ))
        cv2.imwrite(str(rid / f'{stem}.jpg'), img_r, [cv2.IMWRITE_JPEG_QUALITY, 90])
        (rld / f'{stem}.txt').write_text(chr(10).join(new_lines))
        aug += 1
    log(f'  Augmented: {aug}')
    return aug

def split_dataset():
    log('STEP 4: Splitting dataset (80/12/8)')
    rid = OUTPUT / 'raw' / 'images'
    rld = OUTPUT / 'raw' / 'labels'
    pairs = [(rid / n, rld / f'{Path(n).stem}.txt') for n in sorted(os.listdir(rid))
             if n.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp')) and (rld / f'{Path(n).stem}.txt').exists()]
    log(f'  Total: {len(pairs)}')
    cc = Counter()
    for _, lp in pairs:
        with open(lp) as f:
            for line in f:
                parts = line.strip().split()
                if parts:
                    cc[int(parts[0])] += 1
    log(f'  Class distribution: {dict(cc)}')
    random.seed(RANDOM_SEED)
    by_class = defaultdict(list)
    for ip, lp in pairs:
        with open(lp) as f:
            cls = [int(l.strip().split()[0]) for l in f if l.strip()]
        dominant = Counter(cls).most_common(1)[0][0] if cls else 0
        by_class[dominant].append((ip, lp))
    train_p, val_p, test_p = [], [], []
    for c, group in sorted(by_class.items()):
        random.shuffle(group)
        n = len(group)
        nt = max(1, int(n * 0.80))
        nv = max(1, int(n * 0.12))
        train_p.extend(group[:nt])
        val_p.extend(group[nt:nt + nv])
        test_p.extend(group[nt + nv:])
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
    log(f'  Train: {len(train_p)} | Val: {len(val_p)} | Test: {len(test_p)}')
    return len(train_p), len(val_p), len(test_p)

def gen_yaml():
    yaml_content = f'path: {OUTPUT}\ntrain: train/images\nval: val/images\ntest: test/images\nnc: {NC}\nnames: {CLASS_NAMES}\n'
    (OUTPUT / 'data.yaml').write_text(yaml_content)
    log('  data.yaml written')
    return OUTPUT / 'data.yaml'

def train_mlflow(data_yaml):
    log('STEP 6: Training YOLOv8s with MLflow on GPU 1')
    from ultralytics import YOLO
    import mlflow
    mlflow.set_tracking_uri(MLFLOW_URI)
    mlflow.set_experiment(MLFLOW_EXPERIMENT)
    run_name = f'18k_mc_gpu1_{datetime.datetime.now().strftime("%Y%m%d_%H%M")}'
    model = YOLO('yolov8s.pt')
    with mlflow.start_run(run_name=run_name):
        mlflow.log_params({'model': 'yolov8s', 'epochs': EPOCHS, 'batch': BATCH_SIZE,
            'imgsz': IMGSZ, 'device': DEVICE, 'nc': NC, 'classes': str(CLASS_NAMES),
            'patience': PATIENCE, 'workers': WORKERS, 'seed': RANDOM_SEED})
        results = model.train(data=str(data_yaml), epochs=EPOCHS, imgsz=IMGSZ,
            batch=BATCH_SIZE, patience=PATIENCE, device=DEVICE, workers=WORKERS,
            project=str(WORKSPACE / 'runs'), name='18k_multiclass_gpu1', exist_ok=True,
            seed=RANDOM_SEED, hsv_h=0.015, hsv_s=0.7, hsv_v=0.4, degrees=15,
            translate=0.1, scale=0.5, flipud=0.2, fliplr=0.5, mosaic=1.0, mixup=0.1)
        best_path = WORKSPACE / 'runs' / '18k_multiclass_gpu1' / 'weights' / 'best.pt'
        if best_path.exists():
            dst = WORKSPACE / 'models' / 'best_multiclass_18k.pt'
            shutil.copy2(str(best_path), str(dst))
            mlflow.log_artifact(str(dst), 'model')
            log(f'  Best model saved -> {dst}')
        last_path = WORKSPACE / 'runs' / '18k_multiclass_gpu1' / 'weights' / 'last.pt'
        val_model = YOLO(str(best_path)) if best_path.exists() else YOLO(str(last_path))
        metrics = val_model.val(data=str(data_yaml), split='test', imgsz=IMGSZ, device=DEVICE)
        mlflow.log_metrics({'mAP50': float(metrics.box.map50), 'mAP50-95': float(metrics.box.map),
            'precision': float(metrics.box.mp), 'recall': float(metrics.box.mr)})
        for i, name in enumerate(CLASS_NAMES):
            mlflow.log_metrics({f'{name}_mAP50': float(metrics.box.maps50[i]), f'{name}_mAP50-95': float(metrics.box.maps[i])})
        log(f'  Overall: mAP50={metrics.box.map50:.4f} | mAP50-95={metrics.box.map:.4f}')
        for i, name in enumerate(CLASS_NAMES):
            log(f'  {name}: mAP50={metrics.box.maps50[i]:.4f}')
        run_dir = WORKSPACE / 'runs' / '18k_multiclass_gpu1'
        for fname in ['results.csv', 'confusion_matrix.png', 'results.png', 'PR_curve.png', 'F1_curve.png']:
            fpath = run_dir / fname
            if fpath.exists():
                mlflow.log_artifact(str(fpath), 'artifacts')
    return best_path if best_path.exists() else None

def main():
    t0 = time.time()
    log('=' * 60)
    log('18K AGAR Multi-Class Training with MLflow')
    log(f'Device: GPU {DEVICE} | Batch: {BATCH_SIZE} | Epochs: {EPOCHS}')
    log(f'MLflow: https://ml.jatnikonm.tech')
    log('=' * 60)
    (OUTPUT / 'raw' / 'images').mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'raw' / 'labels').mkdir(parents=True, exist_ok=True)
    cp_path = OUTPUT / 'checkpoint_v2.json'
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
    if 's1' not in ck:
        n = convert_u2net_masks()
        save_step('s1', {'n': n})
    if 's2' not in ck:
        n = pseudo_label_resnet()
        save_step('s2', {'n': n})
    if 's3' not in ck:
        n = generate_synthetic_artifacts()
        save_step('s3', {'n': n})
    if 's4' not in ck:
        nt, nv, ne = split_dataset()
        save_step('s4', {'train': nt, 'val': nv, 'test': ne})
    data_yaml = gen_yaml()
    if 's6' not in ck:
        mp = train_mlflow(data_yaml)
        save_step('s6', {'model': str(mp) if mp else None})
    elapsed = (time.time() - t0) / 60
    log(f'Pipeline complete in {elapsed:.1f} min | MLflow: https://ml.jatnikonm.tech')

if __name__ == '__main__':
    main()
