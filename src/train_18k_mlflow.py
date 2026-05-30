#!/usr/bin/env python3
"""18K AGAR Multi-Class Training Pipeline with MLflow Tracking"""
import os, sys, json, time, shutil, random, datetime
from pathlib import Path
from collections import Counter, defaultdict
import cv2, numpy as np
from scipy import ndimage
import mlflow

WORKSPACE = Path('/media/lambda_one/DFSSD04/project/healtcare')
AGAR = WORKSPACE / 'data/agar'
OUTPUT = WORKSPACE / 'data/yolo_18k_multiclass'
MLFLOW_URI = 'http://localhost:5000'
MLFLOW_EXPERIMENT = 'plate_count_reader_18k'
CLASS_NAMES = ['colony', 'bubble', 'dust', 'crack']
NC = 4
RANDOM_SEED = 42
MIN_COLONY_AREA = 8
MAX_COLONIES = 3000
PL_CONF = 0.20
EPOCHS = 150
BATCH_SIZE = 32
IMGSZ = 640
PATIENCE = 25
DEVICE = '0'  # Single GPU (DDP needs special setup)
N_SYNTHETIC_BUBBLE = 1000
N_SYNTHETIC_DUST = 800
N_SYNTHETIC_CRACK = 500

def convert_u2net_masks():
    print('STEP 1: Converting U2Net masks to YOLO boxes')
    # Masks are in colony_detecting/ with _mask suffix
    mask_dir = AGAR / 'dataset/dataset_for_u2net/dataset_for_u2net/train_mask/colony_detecting'
    img_dir = AGAR / 'dataset/dataset_for_u2net/dataset_for_u2net/train'
    converted = 0
    if not mask_dir.exists():
        print(f'  Mask dir not found: {mask_dir}'); return 0
    for mask_name in sorted(os.listdir(mask_dir)):
        if not mask_name.endswith('_mask.png'): continue
        # Find corresponding image: remove _mask suffix
        img_name = mask_name.replace('_mask.png', '.png')
        # Try in train dir
        img_path = img_dir / img_name
        if not img_path.exists():
            # Try valid dir
            img_path = AGAR / 'dataset/dataset_for_u2net/dataset_for_u2net/valid' / img_name
        if not img_path.exists(): continue
        mask_path = mask_dir / mask_name
        img = cv2.imread(str(img_path))
        if img is None: continue
        img_h, img_w = img.shape[:2]
        mask = cv2.imread(str(mask_path), cv2.IMREAD_GRAYSCALE)
        if mask is None: continue
        mask_bin = (mask > 127).astype(np.uint8)
        labeled, nf = ndimage.label(mask_bin)
        if nf > MAX_COLONIES: continue
        yolo_lines = []
        for lid in range(1, nf+1):
            comp = labeled == lid
            if comp.sum() < MIN_COLONY_AREA: continue
            ys, xs = np.where(comp)
            x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
            cx = max(0, min(1, (x0+x1)/2.0/img_w))
            cy = max(0, min(1, (y0+y1)/2.0/img_h))
            w = max(0.001, min(1, (x1-x0)/img_w))
            h = max(0.001, min(1, (y1-y0)/img_h))
            yolo_lines.append(f'0 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}')
        if not yolo_lines: continue
        stem = Path(img_name).stem
        out_img = OUTPUT / 'raw' / 'images' / img_name
        out_lbl = OUTPUT / 'raw' / 'labels' / f'{stem}.txt'
        out_img.parent.mkdir(parents=True, exist_ok=True)
        out_lbl.parent.mkdir(parents=True, exist_ok=True)
        if not out_img.exists(): shutil.copy2(str(img_path), str(out_img))
        out_lbl.write_text('\n'.join(yolo_lines))
        converted += 1
    # Also do valid masks
    vmask_dir = AGAR / 'dataset/dataset_for_u2net/dataset_for_u2net/valid_mask/colony_detecting'
    if vmask_dir.exists():
        for mask_name in sorted(os.listdir(vmask_dir)):
            if not mask_name.endswith('_mask.png'): continue
            img_name = mask_name.replace('_mask.png', '.png')
            img_path = AGAR / 'dataset/dataset_for_u2net/dataset_for_u2net/valid' / img_name
            if not img_path.exists(): continue
            mask_path = vmask_dir / mask_name
            img = cv2.imread(str(img_path))
            if img is None: continue
            img_h, img_w = img.shape[:2]
            mask = cv2.imread(str(mask_path), cv2.IMREAD_GRAYSCALE)
            if mask is None: continue
            mask_bin = (mask > 127).astype(np.uint8)
            labeled, nf = ndimage.label(mask_bin)
            if nf > MAX_COLONIES: continue
            yolo_lines = []
            for lid in range(1, nf+1):
                comp = labeled == lid
                if comp.sum() < MIN_COLONY_AREA: continue
                ys, xs = np.where(comp)
                x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
                cx = max(0, min(1, (x0+x1)/2.0/img_w))
                cy = max(0, min(1, (y0+y1)/2.0/img_h))
                w = max(0.001, min(1, (x1-x0)/img_w))
                h = max(0.001, min(1, (y1-y0)/img_h))
                yolo_lines.append(f'0 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}')
            if not yolo_lines: continue
            stem = Path(img_name).stem
            out_img = OUTPUT / 'raw' / 'images' / img_name
            out_lbl = OUTPUT / 'raw' / 'labels' / f'{stem}.txt'
            if not out_img.exists(): shutil.copy2(str(img_path), str(out_img))
            out_lbl.write_text('\n'.join(yolo_lines))
            converted += 1
    print(f'  Converted: {converted}')
    return converted

def pseudo_label_resnet():
    print('STEP 2: Pseudo-labeling ResNet 18K dataset')
    from ultralytics import YOLO
    model_path = WORKSPACE / 'models/best_plate_count_reader.pt'
    if not model_path.exists(): print('  No model!'); return 0
    model = YOLO(str(model_path))
    resnet_dir = AGAR / 'dataset/dataset_for_resnet/dataset_for_resnet'
    if not resnet_dir.exists(): return 0
    all_images = []
    for cd in sorted(os.listdir(resnet_dir)):
        try: cnt = int(cd)
        except: continue
        if cnt == 0: continue
        for sp in ['train','val']:
            cp = resnet_dir / sp / cd
            if not cp.exists(): continue
            for f in sorted(os.listdir(cp)):
                if f.lower().endswith(('.png','.jpg','.jpeg','.bmp')):
                    all_images.append((cp/f, cnt))
    print(f'  ResNet images (count>0): {len(all_images)}')
    random.seed(RANDOM_SEED)
    by_count = defaultdict(list)
    for p,c in all_images: by_count[c].append(p)
    sampled = []
    for c,imgs in sorted(by_count.items()):
        random.shuffle(imgs); sampled.extend(imgs[:800])
    random.shuffle(sampled)
    print(f'  Sampled: {len(sampled)}')
    if not sampled: return 0
    labeled = 0
    for i in range(0, len(sampled), 64):
        batch = sampled[i:i+64]
        results = model(batch, conf=PL_CONF, verbose=False, imgsz=IMGSZ, device=DEVICE)
        for j, result in enumerate(results):
            if result.boxes is None or len(result.boxes) == 0: continue
            yolo_lines = []
            for k in range(len(result.boxes)):
                if float(result.boxes.conf[k]) < PL_CONF: continue
                xywhn = result.boxes.xywhn[k].cpu().numpy()
                cx,cy,w,h = [max(0,min(1,float(v))) for v in xywhn]
                w,h = max(0.001,w), max(0.001,h)
                yolo_lines.append(f'0 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}')
            if yolo_lines:
                src = batch[j]; stem = f'resnet_{Path(src).stem}'
                oi = OUTPUT/'raw'/f'images/{stem}{Path(src).suffix}'
                ol = OUTPUT/'raw'/f'labels/{stem}.txt'
                oi.parent.mkdir(parents=True, exist_ok=True)
                ol.parent.mkdir(parents=True, exist_ok=True)
                if not oi.exists(): shutil.copy2(str(src), str(oi))
                ol.write_text('\n'.join(yolo_lines))
                labeled += 1
        if (i//64)%10==0: print(f'  {i}/{len(sampled)}, labeled: {labeled}')
    print(f'  Pseudo-labeled: {labeled}')
    return labeled

def generate_synthetic_artifacts():
    print('STEP 3: Generating synthetic artifacts')
    rid = OUTPUT/'raw'/'images'; rld = OUTPUT/'raw'/'labels'
    labeled = [(rid/n, rld/f'{Path(n).stem}.txt') for n in sorted(os.listdir(rid))
               if n.lower().endswith(('.png','.jpg','.jpeg','.bmp')) and (rld/f'{Path(n).stem}.txt').exists()]
    print(f'  Base: {len(labeled)}')
    if not labeled: return 0
    random.seed(RANDOM_SEED); random.shuffle(labeled)
    aug = 0
    for i in range(N_SYNTHETIC_BUBBLE):
        si,sl = labeled[i%len(labeled)]; img = cv2.imread(str(si))
        if img is None: continue
        el = sl.read_text().strip().split('\n'); nl = list(el)
        for _ in range(random.randint(1,3)):
            nl.append(f'1 {random.uniform(.1,.9):.6f} {random.uniform(.1,.9):.6f} {random.uniform(.02,.08):.6f} {random.uniform(.02,.08):.6f}')
        s = f'aug_bubble_{i:04d}'; ir = cv2.resize(img,(IMGSZ,IMGSZ))
        cv2.imwrite(str(rid/f'{s}.jpg'),ir,[cv2.IMWRITE_JPEG_QUALITY,90])
        (rld/f'{s}.txt').write_text('\n'.join(nl)); aug+=1
    for i in range(N_SYNTHETIC_DUST):
        si,sl = labeled[(i+100)%len(labeled)]; img = cv2.imread(str(si))
        if img is None: continue
        el = sl.read_text().strip().split('\n'); nl = list(el)
        for _ in range(random.randint(3,8)):
            nl.append(f'2 {random.uniform(.05,.95):.6f} {random.uniform(.05,.95):.6f} {random.uniform(.003,.015):.6f} {random.uniform(.003,.015):.6f}')
        s = f'aug_dust_{i:04d}'; ir = cv2.resize(img,(IMGSZ,IMGSZ))
        cv2.imwrite(str(rid/f'{s}.jpg'),ir,[cv2.IMWRITE_JPEG_QUALITY,90])
        (rld/f'{s}.txt').write_text('\n'.join(nl)); aug+=1
    for i in range(N_SYNTHETIC_CRACK):
        si,sl = labeled[(i+200)%len(labeled)]; img = cv2.imread(str(si))
        if img is None: continue
        el = sl.read_text().strip().split('\n'); nl = list(el)
        for _ in range(random.randint(1,2)):
            cx,cy = random.uniform(.2,.8),random.uniform(.2,.8)
            if random.random()>.5: w,h = random.uniform(.1,.3),random.uniform(.005,.02)
            else: w,h = random.uniform(.005,.02),random.uniform(.1,.3)
            nl.append(f'3 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}')
        s = f'aug_crack_{i:04d}'; ir = cv2.resize(img,(IMGSZ,IMGSZ))
        cv2.imwrite(str(rid/f'{s}.jpg'),ir,[cv2.IMWRITE_JPEG_QUALITY,90])
        (rld/f'{s}.txt').write_text('\n'.join(nl)); aug+=1
    print(f'  Augmented: {aug}')
    return aug

def split_dataset():
    print('STEP 4: Split')
    rid = OUTPUT/'raw'/'images'; rld = OUTPUT/'raw'/'labels'
    pairs = [(rid/n,rld/f'{Path(n).stem}.txt') for n in sorted(os.listdir(rid))
             if n.lower().endswith(('.png','.jpg','.jpeg','.bmp')) and (rld/f'{Path(n).stem}.txt').exists()]
    print(f'  Total: {len(pairs)}')
    cc = Counter()
    for _,lp in pairs:
        with open(lp) as f:
            for l in f: cc[int(l.strip().split()[0])]+=1
    print(f'  Classes: {dict(cc)}')
    random.seed(RANDOM_SEED)
    bc = defaultdict(list)
    for ip,lp in pairs:
        with open(lp) as f: cls = [int(l.strip().split()[0]) for l in f]
        d = Counter(cls).most_common(1)[0][0] if cls else 0
        bc[d].append((ip,lp))
    tp,vp,ep = [],[],[]
    for c,g in sorted(bc.items()):
        random.shuffle(g); n=len(g)
        nt = max(1,int(n*.80)); nv = max(1,int(n*.12))
        tp.extend(g[:nt]); vp.extend(g[nt:nt+nv]); ep.extend(g[nt+nv:])
    for sn,sp in [('train',tp),('val',vp),('test',ep)]:
        id_=OUTPUT/sn/'images'; ld=OUTPUT/sn/'labels'
        id_.mkdir(parents=True,exist_ok=True); ld.mkdir(parents=True,exist_ok=True)
        for ip,lp in sp:
            di=id_/ip.name; dl=ld/lp.name
            if not di.exists(): shutil.copy2(str(ip),str(di))
            if not dl.exists(): shutil.copy2(str(lp),str(dl))
    print(f'  Train:{len(tp)} Val:{len(vp)} Test:{len(ep)}')
    return len(tp),len(vp),len(ep)

def gen_yaml():
    (OUTPUT/'data.yaml').write_text(f'path: {OUTPUT}\ntrain: train/images\nval: val/images\ntest: test/images\nnc: {NC}\nnames: {CLASS_NAMES}\n')
    return OUTPUT/'data.yaml'

def train_mlflow(dy):
    print('STEP 5: Training YOLOv8s with MLflow')
    from ultralytics import YOLO
    mlflow.set_tracking_uri(MLFLOW_URI)
    mlflow.set_experiment(MLFLOW_EXPERIMENT)
    model = YOLO('yolov8s.pt')
    with mlflow.start_run(run_name=f'18k_mc_{datetime.datetime.now().strftime("%Y%m%d_%H%M")}'):
        mlflow.log_params({'model':'yolov8s','epochs':EPOCHS,'batch':BATCH_SIZE,
            'imgsz':IMGSZ,'device':DEVICE,'nc':NC,'classes':str(CLASS_NAMES)})
        results = model.train(data=str(dy), epochs=EPOCHS, imgsz=IMGSZ,
            batch=BATCH_SIZE, patience=PATIENCE, device=DEVICE, workers=8,
            project=str(WORKSPACE/'runs'), name='18k_multiclass', exist_ok=True,
            hsv_h=0.015, hsv_s=0.7, hsv_v=0.4, degrees=15, translate=0.1,
            scale=0.5, flipud=0.2, fliplr=0.5, mosaic=1.0, mixup=0.1)
        bp = WORKSPACE/'runs'/'18k_multiclass'/'weights'/'best.pt'
        if bp.exists():
            dst = WORKSPACE/'models'/'best_multiclass_18k.pt'
            shutil.copy2(str(bp),str(dst))
            mlflow.log_artifact(str(dst),'model')
            print(f'  Best -> {dst}')
        vm = YOLO(str(bp)) if bp.exists() else model
        m = vm.val(data=str(dy), split='test', imgsz=IMGSZ)
        mlflow.log_metrics({'mAP50':float(m.box.map50),'mAP50-95':float(m.box.map),
            'precision':float(m.box.mp),'recall':float(m.box.mr)})
        for i,n in enumerate(CLASS_NAMES):
            mlflow.log_metrics({f'{n}_mAP50':float(m.box.maps50[i]),f'{n}_mAP50-95':float(m.box.maps[i])})
        print(f'  mAP50:{m.box.map50:.4f} mAP50-95:{m.box.map:.4f}')
        for i,n in enumerate(CLASS_NAMES):
            print(f'  {n}: mAP50={m.box.maps50[i]:.4f}')
        rd = WORKSPACE/'runs'/'18k_multiclass'
        for f in ['results.csv','confusion_matrix.png','results.png']:
            fp = rd/f
            if fp.exists(): mlflow.log_artifact(str(fp),'artifacts')
    return bp if bp.exists() else None

def main():
    t0 = time.time()
    print('='*60)
    print('18K AGAR Multi-Class Training with MLflow')
    print(f'MLflow: https://ml.jatnikonm.tech')
    print('='*60)
    (OUTPUT/'raw'/'images').mkdir(parents=True,exist_ok=True)
    (OUTPUT/'raw'/'labels').mkdir(parents=True,exist_ok=True)
    cp = OUTPUT/'checkpoint.json'
    ck = {}
    if cp.exists():
        with open(cp) as f: ck = json.load(f)
        print(f'  Checkpoint: {ck}')
    def sv(s,d):
        ck[s]=d; ck[f'{s}_t']=datetime.datetime.now().isoformat()
        with open(cp,'w') as f: json.dump(ck,f,indent=2)
    if 's1' not in ck: sv('s1',{'n':convert_u2net_masks()})
    if 's2' not in ck: sv('s2',{'n':pseudo_label_resnet()})
    if 's3' not in ck: sv('s3',{'n':generate_synthetic_artifacts()})
    if 's4' not in ck:
        nt,nv,ne = split_dataset()
        sv('s4',{'train':nt,'val':nv,'test':ne})
    dy = gen_yaml()
    if 's5' not in ck:
        mp = train_mlflow(dy)
        sv('s5',{'model':str(mp) if mp else None})
    print(f'\nDone in {(time.time()-t0)/60:.1f} min | MLflow: https://ml.jatnikonm.tech')

if __name__ == '__main__':
    main()
