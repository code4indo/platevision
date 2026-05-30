#!/usr/bin/env python3
"""Resume training from last.pt checkpoint with MLflow tracking."""
import os, sys, time, shutil, datetime
from pathlib import Path

WORKSPACE = Path('/media/lambda_one/DFSSD04/project/healtcare')
OUTPUT = WORKSPACE / 'data/yolo_18k_multiclass'
MLFLOW_URI = 'http://localhost:5500'
MLFLOW_EXPERIMENT = 'plate_count_reader_18k'
CLASS_NAMES = ['colony', 'bubble', 'dust', 'crack']
NC = 4
EPOCHS = 150
BATCH_SIZE = 16
IMGSZ = 640
PATIENCE = 30
DEVICE = '1'
WORKERS = 6

def log(msg):
    ts = datetime.datetime.now().strftime('%H:%M:%S')
    print(f'[{ts}] {msg}', flush=True)

def main():
    log('=' * 60)
    log('RESUMING Training from last.pt checkpoint')
    log(f'Device: GPU {DEVICE} | Batch: {BATCH_SIZE} | Target Epochs: {EPOCHS}')
    log('=' * 60)

    from ultralytics import YOLO
    import mlflow

    # Setup MLflow
    mlflow.set_tracking_uri(MLFLOW_URI)
    mlflow.set_experiment(MLFLOW_EXPERIMENT)

    last_pt = WORKSPACE / 'runs/18k_multiclass_gpu1/weights/last.pt'
    data_yaml = OUTPUT / 'data.yaml'

    if not last_pt.exists():
        log(f'ERROR: last.pt not found at {last_pt}')
        sys.exit(1)

    if not data_yaml.exists():
        log(f'ERROR: data.yaml not found at {data_yaml}')
        sys.exit(1)

    log(f'Loading checkpoint: {last_pt}')
    model = YOLO(str(last_pt))

    run_name = f'18k_mc_gpu1_resume_{datetime.datetime.now().strftime("%Y%m%d_%H%M")}'

    with mlflow.start_run(run_name=run_name):
        mlflow.log_params({
            'model': 'yolov8s',
            'epochs': EPOCHS,
            'batch': BATCH_SIZE,
            'imgsz': IMGSZ,
            'device': DEVICE,
            'nc': NC,
            'classes': str(CLASS_NAMES),
            'patience': PATIENCE,
            'workers': WORKERS,
            'resume': True,
            'resume_from': str(last_pt)
        })

        results = model.train(
            data=str(data_yaml),
            epochs=EPOCHS,
            imgsz=IMGSZ,
            batch=BATCH_SIZE,
            patience=PATIENCE,
            device=DEVICE,
            workers=WORKERS,
            project=str(WORKSPACE / 'runs'),
            name='18k_multiclass_gpu1',
            exist_ok=True,
            seed=42,
            resume=True,
            hsv_h=0.015, hsv_s=0.7, hsv_v=0.4,
            degrees=15, translate=0.1, scale=0.5,
            flipud=0.2, fliplr=0.5, mosaic=1.0, mixup=0.1
        )

        # Save best model
        best_path = WORKSPACE / 'runs/18k_multiclass_gpu1/weights/best.pt'
        if best_path.exists():
            dst = WORKSPACE / 'models/best_multiclass_18k.pt'
            shutil.copy2(str(best_path), str(dst))
            mlflow.log_artifact(str(dst), 'model')
            log(f'Best model saved -> {dst}')

        # Validate on test set
        eval_model_path = best_path if best_path.exists() else WORKSPACE / 'runs/18k_multiclass_gpu1/weights/last.pt'
        val_model = YOLO(str(eval_model_path))
        metrics = val_model.val(data=str(data_yaml), split='test', imgsz=IMGSZ, device=DEVICE)

        mlflow.log_metrics({
            'mAP50': float(metrics.box.map50),
            'mAP50-95': float(metrics.box.map),
            'precision': float(metrics.box.mp),
            'recall': float(metrics.box.mr)
        })

        for i, name in enumerate(CLASS_NAMES):
            mlflow.log_metrics({
                f'{name}_mAP50': float(metrics.box.maps50[i]),
                f'{name}_mAP50-95': float(metrics.box.maps[i])
            })

        log(f'Overall: mAP50={metrics.box.map50:.4f} | mAP50-95={metrics.box.map:.4f}')
        for i, name in enumerate(CLASS_NAMES):
            log(f'  {name}: mAP50={metrics.box.maps50[i]:.4f}')

        # Log artifacts
        run_dir = WORKSPACE / 'runs/18k_multiclass_gpu1'
        for fname in ['results.csv', 'confusion_matrix.png', 'results.png', 'PR_curve.png', 'F1_curve.png']:
            fpath = run_dir / fname
            if fpath.exists():
                mlflow.log_artifact(str(fpath), 'artifacts')

        # Mark checkpoint as complete
        import json
        cp_path = OUTPUT / 'checkpoint_v2.json'
        ck = {}
        if cp_path.exists():
            with open(cp_path) as f:
                ck = json.load(f)
        ck['s6'] = {'model': str(dst) if best_path.exists() else None, 'resumed': True}
        ck['s6_t'] = datetime.datetime.now().isoformat()
        with open(cp_path, 'w') as f:
            json.dump(ck, f, indent=2)

    log('Training pipeline complete!')

if __name__ == '__main__':
    main()
