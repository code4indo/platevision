# AGENTS.md — Plate Count Reader Project Context

> File ini dibuat untuk memberikan konteks lengkap kepada coding agent (Cursor, Copilot, Claude Code, dll)
> agar dapat memahami arsitektur, konvensi, dan alur kerja project Plate Count Reader.

---

## 1. Project Overview

**Nama Project**: Plate Count Reader — Automated Colony Counter
**Hackathon**: AI Open Innovation Challenge 2026 — Healthcare Category
**Tujuan**: Sistem otomatis untuk mendeteksi dan menghitung koloni bakteri pada agar plate menggunakan YOLOv8.
**Path**: `/media/lambda_one/DFSSD04/project/healtcare`

### Apa yang dilakukan sistem ini?
Sistem menerima foto agar plate sebagai input, menjalankan deteksi objek menggunakan model YOLOv8,
dan menghasilkan: (1) gambar dengan bounding box annotation, (2) jumlah koloni per kelas,
(3) klasifikasi CFU (TFTC / IDEAL / TNTC), dan (4) statistik detail per deteksi.

### 4 Kelas Deteksi
| ID | Kelas | Deskripsi |
|----|-------|-----------|
| 0 | `colony` | Koloni bakteri — target utama penghitungan |
| 1 | `bubble` | Gelembung udara pada media agar (common false positive) |
| 2 | `dust` | Debu/kontaminan kecil pada permukaan plate |
| 3 | `crack` | Retakan pada media agar yang menyerupai koloni |

---

## 2. Hardware & Environment

| Komponen | Detail |
|----------|--------|
| GPU | 2x NVIDIA RTX A4000 (16GB VRAM each) |
| Python | 3.10.12 |
| Virtual Env | `.venv` (di root project) |
| OS | Linux (uptime 78+ days) |

### Key Python Packages
| Package | Versi | Kegunaan |
|---------|-------|----------|
| `ultralytics` | 8.4.48 | YOLOv8 training & inference |
| `torch` | 2.7.0 | Deep learning framework |
| `torchvision` | 0.22.0 | Vision utilities |
| `gradio` | 6.14.0 | Web UI untuk demo |
| `opencv-python` | 4.13.0.92 | Image processing |
| `numpy` | 1.26.4 | Numerical computation |
| `scipy` | 1.17.0 | Connected component analysis (AGAR conversion) |
| `pillow` | 12.1.1 | Image I/O |
| `pandas` | 1.3.5 | Data manipulation |

> **PENTING**: Selalu `source .venv/bin/activate` sebelum menjalankan script Python.

---

## 3. Directory Structure

```
healtcare/
├── src/                          # Source code (Python scripts)
│   ├── train.py                  # Training v1 (single-class, basic)
│   ├── train_v2_fixed.py         # Training v2 (4-class, pseudo-labeling)
│   ├── train_v3.py               # Training v3 (4-class, enhanced data)
│   ├── train_v4_production.py    # Training v4 (YOLOv8m, focal loss, production)
│   ├── train_v4_final.py         # Training v4 wrapper
│   ├── train_v4_gpu1.py          # Training v4 single GPU
│   ├── train_v4_gpu1_mlflow.py   # Training v4 single GPU + MLflow logging
│   ├── train_v4_gpu1_optimized.py # Training v4 optimized params
│   ├── train_v4_minimal.py       # Training v4 minimal config
│   ├── train_18k_mlflow.py       # Training 18k dataset + MLflow
│   ├── train_18k_gpu1.py         # Training 18k dataset single GPU
│   ├── train_4class_v3.py        # Empty file (placeholder)
│   ├── inference.py              # CLI inference utility
│   ├── evaluate.py               # Model evaluation script
│   ├── convert_dataset.py        # Dataset format converter (AGAR, Microbial → YOLO)
│   ├── create_stratified_split.py # Stratified train/val/test split creator
│   ├── augment_colony.py         # Colony augmentation v1
│   ├── augment_colony_v2.py      # Colony augmentation v2 (crop-paste)
│   └── resume_training.py        # Resume interrupted training
│
├── data/                         # Dataset directories
│   ├── raw/                      # Raw downloaded data (empty/unused)
│   ├── processed/                # Processed data (empty/unused)
│   ├── agar/                     # AGAR dataset (~6.5GB, from Kaggle)
│   ├── yolo_18k_multiclass/      # 18k images, 4-class YOLO format (~2.2GB)
│   ├── yolo_v2_balanced/         # Balanced dataset v2 (~2.2GB)
│   ├── yolo_v3_enhanced/         # Enhanced dataset v3 (~2.3GB)
│   ├── yolo_v3_production/       # Production dataset (stratified) (~1.3GB)
│   └── yolo_dataset/             # Original small dataset
│
├── models/                       # Trained model weights
│   ├── best_plate_count_reader.pt  # V1 model (single-class)
│   ├── best_multiclass_18k.pt      # 18k multiclass model
│   ├── best_v2_balanced.pt         # V2 balanced model
│   └── best_v3_enhanced.pt         # V3 enhanced (CURRENTLY USED in Gradio)
│
├── runs/                         # Training run outputs (YOLO format)
│   ├── detect/                   # Early detection runs
│   ├── 18k_multiclass/           # 18k dataset training
│   ├── 18k_multiclass_gpu1/      # 18k single GPU
│   ├── mlflow/                   # MLflow tracked runs
│   ├── runs_v2_balanced/         # V2 balanced training
│   ├── runs_v2_smoke/            # V2 smoke test
│   └── runs_v3_enhanced/         # V3 enhanced training
│
├── notebooks/                    # Jupyter notebooks
│   ├── 01_data_exploration.ipynb
│   ├── 02_data_preparation.ipynb
│   ├── 03_model_training.ipynb
│   └── 04_model_evaluation.ipynb
│
├── docs/                         # Documentation
│   ├── model_card.md             # Model card (v1, outdated)
│   └── data_sources.md           # Data source documentation
│
├── tests/                        # Test directory (empty — needs implementation)
├── samples/                      # Sample images for demo
├── mlflow_artifacts/             # MLflow artifact storage
├── mlflow.db                     # MLflow SQLite tracking DB (v1)
├── mlflow_v2.db                  # MLflow SQLite tracking DB (v2)
│
├── gradio_app.py                 # Gradio web application (MAIN DEMO UI)
├── PRODUCTION_READINESS_ROADMAP.md # Production roadmap (8-week plan)
├── README.md                     # Project documentation
│
├── start.sh                      # Launch script for Gradio app
├── run_training.sh               # V1 training launcher
├── run_gpu1.sh                   # GPU1 training launcher
├── run_v2_full.sh                # V2 full training
├── run_v2_smoke.sh               # V2 smoke test
├── run_v4_training.sh            # V4 dual-GPU training (YOLO CLI)
├── run_v4_training_single_gpu.sh # V4 single-GPU training (YOLO CLI)
├── download_agar.sh              # AGAR dataset downloader (Kaggle API)
│
├── yolo26n.pt                    # YOLO nano pretrained weights
├── yolov8s.pt                    # YOLOv8s pretrained weights
├── yolov8m.pt                    # YOLOv8m pretrained weights
└── .venv/                        # Python virtual environment
```

---

## 4. Dataset Variants & Evolution

Dataset berevolusi melalui beberapa iterasi. **Gunakan `yolo_v3_production` untuk training production.**

| Dataset | Ukuran | Kelas | Split | Catatan |
|---------|--------|-------|-------|---------|
| `yolo_dataset` | ~294 img | 1 (colony) | 70/15/15 | Original kecil, v1 |
| `yolo_v2_balanced` | ~4,157 img | 4 | 80/12/8 | +pseudo-labeling +synthetic artifacts |
| `yolo_18k_multiclass` | ~18,000 img | 4 | train/val/test | Full AGAR + DIBaS + augmentation |
| `yolo_v3_enhanced` | ~4,157+ img | 4 | 80/12/8 | Enhanced augmentation + rebalancing |
| `yolo_v3_production` | ~3,357 img | 4 | stratified | **PRODUCTION** — stratified split, min 150/class in val |

### Format data.yaml (YOLOv8)
```yaml
path: /media/lambda_one/DFSSD04/project/healtcare/data/yolo_v3_production
train: train/images
val: val/images
test: test/images
nc: 4
names: ['colony', 'bubble', 'dust', 'crack']
```

### Data Pipeline Flow
```
AGAR (segmentation masks)
  → scipy.ndimage.label (connected components) → bounding boxes → YOLO format
DIBaS (no annotations)
  → Pseudo-labeling using V1 model (conf > 0.20) → filtered labels
Microbial Colony (JSON bbox)
  → Direct conversion (x,y,w,h → normalized cx,cy,nw,nh)
Synthetic Artifacts (bubble/dust/crack)
  → Random position & size generation on existing images
```

---

## 5. Model Evolution & Performance

| Versi | Arsitektur | Dataset | mAP50 | mAP50-95 | Precision | Recall | Catatan |
|-------|-----------|---------|-------|----------|-----------|--------|---------|
| V1 | YOLOv8s | yolo_dataset (294 img, 1 class) | 0.866 | 0.604 | 0.933 | 0.835 | Single-class, baseline |
| V2 | YOLOv8s | yolo_v2_balanced (4-class) | — | — | — | — | 4-class intro + pseudo-labeling |
| V3 | YOLOv8s | yolo_v3_enhanced | 0.775 | 0.525 | 0.747 | 0.859 | EarlyStopping@142, best so far |
| V4 | YOLOv8m | yolo_v3_production | Target mAP50>=0.75 | — | — | — | Focal loss, AdamW, production |

### V3 Best Metrics (Current Production Model)
- **mAP50**: 0.775
- **mAP50-95**: 0.525
- **Precision**: 0.747
- **Recall**: 0.859
- **Epochs**: 192 (EarlyStopping at 142)
- **Model**: `models/best_v3_enhanced.pt`

---

## 6. Key Scripts & How to Use Them

### Training
```bash
# Aktifkan venv dulu!
source .venv/bin/activate

# V4 Production Training (RECOMMENDED)
python3 src/train_v4_production.py

# V4 Training via YOLO CLI (dual GPU)
bash run_v4_training.sh

# V4 Training via YOLO CLI (single GPU)
bash run_v4_training_single_gpu.sh

# V4 with MLflow logging (single GPU)
python3 src/train_v4_gpu1_mlflow.py
```

### Inference
```bash
# Single image
python3 src/inference.py --image test.jpg --model models/best_v3_enhanced.pt

# Batch directory
python3 src/inference.py --dir samples/ --model models/best_v3_enhanced.pt --output results/
```

### Evaluation
```bash
python3 src/evaluate.py --model models/best_v3_enhanced.pt --data data/yolo_v3_production/data.yaml --split val
```

### Data Preparation
```bash
# Convert datasets to YOLO format
python3 src/convert_dataset.py --source agar --input data/agar --output data/yolo_converted

# Create stratified split
python3 src/create_stratified_split.py
```

### Launch Gradio App
```bash
bash start.sh
# atau
python3 gradio_app.py --port 7860
python3 gradio_app.py --share  # dengan public URL
```

---

## 7. Gradio Application Architecture

**File**: `gradio_app.py` (~560 lines)

### Flow
```
User uploads image → detect_colonies() → YOLO inference → annotated image + stats
                                  ↓
                           count_colonies_only() → CFU classification (TFTC/IDEAL/TNTC)
                                  ↓
                           format_results_table() → detailed text report
```

### Key Functions
| Fungsi | Deskripsi |
|--------|-----------|
| `detect_colonies(image, conf, iou, max_det)` | Main detection — returns annotated image + results dict |
| `count_colonies_only(image, conf, iou)` | Quick colony count with CFU classification |
| `format_results_table(results_dict)` | Format results as readable text table |
| `create_app()` | Build Gradio Blocks UI |

### Config di Gradio
```python
MODEL_PATH = BASE_DIR / "models" / "best_v3_enhanced.pt"  # Currently using V3
```

### CFU Classification Logic
- `< 30 koloni` → **TFTC** (Too Few To Count)
- `30-300 koloni` → **IDEAL** (dalam range hitung)
- `> 300 koloni` → **TNTC** (Too Numerous To Count)

---

## 8. Training Configuration (V4 Production)

```python
CONFIG = {
    'data': 'data/yolo_v3_production/data.yaml',
    'epochs': 150,
    'imgsz': 640,
    'batch': 12,           # YOLOv8m needs smaller batch
    'patience': 40,        # Early stopping
    'device': '0,1',       # Dual GPU
    'optimizer': 'AdamW',
    'lr0': 0.0008,
    'lrf': 0.008,          # Final LR fraction
    'cos_lr': True,        # Cosine LR scheduler
    'warmup_epochs': 5,
    'box': 7.5,            # Box loss weight
    'cls': 3.5,            # Classification loss weight (high for class imbalance)
    'dfl': 1.5,            # Distribution focal loss weight
    'label_smoothing': 0.05,
    'mosaic': 0.3,
    'mixup': 0.05,
    'copy_paste': 0.2,
    'erasing': 0.2,
    'flipud': 0.3,
    'fliplr': 0.5,
    'close_mosaic': 15,    # Disable mosaic for last 15 epochs
}
```

---

## 9. Coding Conventions

### Python Style
- Mengikuti PEP 8
- Docstring format: Google-style (`Args:`, `Returns:`)
- Type hints digunakan sebagian (tidak konsisten)
- Bahasa komentar: campuran Indonesia dan Inggris

### File Naming
- Training scripts: `train_<version>_<variant>.py` (e.g., `train_v4_production.py`)
- Shell scripts: `run_<version>_<variant>.sh` atau `start.sh`
- Dataset dirs: `yolo_<version>_<description>/`
- Model files: `best_<version>_<description>.pt`

### Import Pattern
```python
from ultralytics import YOLO      # Selalu menggunakan ultralytics
from pathlib import Path           # Path handling
import cv2                         # OpenCV untuk image processing
import numpy as np                 # Numerical ops
```

### Path Convention
- Workspace root: `/media/lambda_one/DFSSD04/project/healtcare`
- Selalu gunakan `Path()` daripada string concatenation
- `WORKSPACE = Path('/media/lambda_one/DFSSD04/project/healtcare')` — hardcoded di banyak script

---

## 10. MLflow Integration

- **Tracking URI**: `https://ml.jatnikonm.tech`
- **Local DB**: `mlflow_v2.db` (SQLite)
- **Artifacts**: `mlflow_artifacts/`
- Digunakan di: `src/train_18k_mlflow.py`, `src/train_v4_gpu1_mlflow.py`
- Beberapa training script TIDAK menggunakan MLflow (hanya YOLO built-in logging ke `runs/`)

---

## 11. Known Issues & TODOs

### Critical
- [ ] `tests/` directory kosong — tidak ada unit test
- [ ] `docs/model_card.md` outdated (masih v1 single-class)
- [ ] Colony mAP50 hanya 0.629 — target >= 0.75 untuk production
- [ ] Validation set imbalanced (1818 colony vs 58 crack di beberapa dataset)

### Technical Debt
- [ ] Banyak training script duplikat (v4 punya 6 varian)
- [ ] `train_4class_v3.py` kosong (0 bytes)
- [ ] Path hardcoded ke `/media/lambda_one/DFSSD04/project/healtcare`
- [ ] `data/raw/` dan `data/processed/` kosong
- [ ] Tidak ada `requirements.txt` atau `pyproject.toml`
- [ ] Tidak ada `.gitignore` yang proper

### Improvement Roadmap (dari PRODUCTION_READINESS_ROADMAP.md)
1. Stratified validation rebalancing
2. Colony augmentation pipeline (target 20,000+ instances)
3. Architecture upgrade (YOLOv8m → sudah dimulai di V4)
4. Focal loss implementation
5. Test suite (pytest)
6. MLflow model registry
7. Drift detection
8. Clinical validation study

---

## 12. Quick Reference Commands

```bash
# === Setup ===
cd /media/lambda_one/DFSSD04/project/healtcare
source .venv/bin/activate

# === Training ===
python3 src/train_v4_production.py              # V4 production training
bash run_v4_training.sh                          # V4 via YOLO CLI (dual GPU)
bash run_v4_training_single_gpu.sh               # V4 via YOLO CLI (single GPU)

# === Inference ===
python3 src/inference.py --image samples/test.jpg
python3 src/inference.py --dir samples/ --output results/

# === Evaluation ===
python3 src/evaluate.py --model models/best_v3_enhanced.pt --data data/yolo_v3_production/data.yaml

# === Data ===
python3 src/convert_dataset.py --source agar --input data/agar --output data/yolo_converted
python3 src/create_stratified_split.py
python3 src/augment_colony_v2.py

# === Demo ===
python3 gradio_app.py --port 7860
bash start.sh

# === GPU Monitoring ===
nvidia-smi
watch -n1 nvidia-smi

# === MLflow ===
mlflow ui --backend-store-uri sqlite:///mlflow_v2.db --port 5000
```

---

## 13. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Plate Count Reader                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐    ┌───────────────┐    ┌──────────────────┐  │
│  │  Agar    │    │  Data         │    │  YOLOv8          │  │
│  │  Plate   │───▶│  Pipeline     │───▶│  Training        │  │
│  │  Image   │    │  (convert,    │    │  (ultralytics)   │  │
│  └──────────┘    │   augment,    │    │                  │  │
│                  │   split)      │    │  V1→V2→V3→V4     │  │
│  ┌──────────┐    └───────────────┘    └────────┬─────────┘  │
│  │  Sample  │                                   │            │
│  │  Images  │──────────────────────────────────▶│            │
│  └──────────┘                           ┌───────▼─────────┐ │
│                                         │  Model Weights   │ │
│                                         │  models/best_*.pt│ │
│                                         └───────┬─────────┘ │
│                                                 │            │
│                                        ┌────────▼────────┐  │
│                                        │  Gradio App     │  │
│                                        │  gradio_app.py  │  │
│                                        │                 │  │
│                                        │  Input Image ──▶│  │
│                                        │  YOLO Inference │  │
│                                        │  Colony Count   │  │
│                                        │  CFU Classify   │  │
│                                        │  Results Table  │  │
│                                        │ ▶ Annotated Img │  │
│                                        └─────────────────┘  │
│                                                              │
│  ┌──────────────┐    ┌───────────────┐                       │
│  │  MLflow      │    │  GPU Cluster  │                       │
│  │  Tracking    │    │  2x A4000     │                       │
│  │  + Registry  │    │  (16GB each)  │                       │
│  └──────────────┘    └───────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 14. When Modifying This Project

### Menambah training script baru
1. Ikuti naming convention: `train_v<version>_<variant>.py`
2. Gunakan `WORKSPACE = Path(...)` pattern
3. Tambahkan MLflow logging jika memungkinkan
4. Update section ini dengan info script baru

### Mengubah model di Gradio
1. Update `MODEL_PATH` di `gradio_app.py` line ~46
2. Update model info di accordion section
3. Test dengan sample images sebelum deploy

### Menambah dataset baru
1. Convert ke YOLO format menggunakan `src/convert_dataset.py`
2. Buat `data.yaml` mengikuti template yang ada
3. Jalankan `src/create_stratified_split.py` untuk split yang proper
4. Update table di section 4 (Dataset Variants)

### Menambah kelas deteksi baru
1. Update `nc` dan `names` di `data.yaml`
2. Update label files (class ID baru)
3. Retrain model dari awal (jangan fine-tune dari model 4-class)
4. Update `gradio_app.py` CFU classification logic
5. Update section 1 (4 Kelas Deteksi) di file ini
