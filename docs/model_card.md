# Model Card: PlateVision AI — Colony Detector

## Model Details

- **Model Name**: PlateVision AI - Automated Colony Counter
- **Model Version**: v4.0 (Production)
- **Architecture**: YOLOv8m (Medium variant, 25.9M params)
- **Task**: Object Detection (Bacterial Colony Detection + Artifact Filtering)
- **Date**: May 2026
- **Developed by**: AI Open Innovation Challenge 2026 — Healthcare Team

## Intended Use

- **Primary Use**: Automated detection and counting of bacterial colonies on agar plate images, with simultaneous filtering of false positives (bubbles, dust, cracks)
- **Primary Users**: Microbiology laboratory technicians, quality control personnel
- **Out-of-Scope**: Clinical diagnosis, medical decision-making, non-agar plate images

## Training Data

### Datasets Used
1. **AGAR (Annotated Germs in Agar Plates)** — 20,623 images from Kaggle
   - Source: https://agar.neurosys.pl/
   - Contains diverse agar plate images with varying colony densities
   - U2Net subset (255 images): Segmentation masks converted to bounding boxes via connected component analysis (scipy.ndimage.label)
   - ResNet subset (~18K images): Pseudo-labeled using V1 model (conf > 0.20), 1,602 accepted

2. **DIBaS (Digital Images of Bacterial Species)** — 692 images from Kaggle
   - Source: https://misztal.edu.pl/software/databases/dibas/
   - 33 bacterial species, 20 images each
   - Used for augmentation context only (no bounding box annotations)

3. **Microbial Colony Recognition** — 40 images from Kaggle
   - Source: Kaggle dataset by zoya77
   - JSON bounding box annotations

### Data Processing Pipeline
- All datasets converted to YOLOv8 format with 4 classes: colony (0), bubble (1), dust (2), crack (3)
- Synthetic artifact generation: 1,000 bubbles, 800 dust, 500 cracks annotated on existing images
- Stratified split: `create_stratified_split.py` created balanced validation set (min 150 instances/class)
- Colony augmentation: `augment_colony_v2.py` generated 2,000 synthetic colony images via crop-paste technique
- Final dataset: **~5,357 images** (3,357 base stratified + 2,000 synthetic colony augmentations)

## Model Evolution

| Version | Architecture | Dataset | mAP50 | mAP50-95 | Precision | Recall | Notes |
|---------|-------------|---------|-------|----------|-----------|--------|-------|
| V1 | YOLOv8s | yolo_dataset (588 img, 1 class) | 0.866 | 0.604 | 0.933 | 0.835 | Single-class baseline |
| V2 | YOLOv8s | yolo_v2_balanced (4-class) | — | — | — | — | 4-class intro + pseudo-labeling |
| V3 | YOLOv8s | yolo_v3_enhanced (4,157 img) | 0.775 | 0.525 | 0.747 | 0.859 | EarlyStopping@142 |
| **V4** | **YOLOv8m** | **yolo_v3_production (5,357 img)** | **0.9145** | **0.6984** | **0.9235** | **0.8731** | **Current production** |

## Training Configuration (V4 Production)

| Parameter | Value |
|-----------|-------|
| Base Model | yolov8m.pt (COCO pretrained) |
| Epochs | 150 |
| Image Size | 640 |
| Batch Size | 12 (dual GPU) |
| Optimizer | AdamW |
| Learning Rate | 0.0008 (initial) → 0.008 (final fraction) |
| Scheduler | Cosine LR with 5 epoch warmup |
| Loss Weights | box=7.5, cls=3.5, dfl=1.5 |
| Label Smoothing | 0.05 |
| Device | 2x NVIDIA RTX A4000 (16GB each) |
| Mosaic | 0.3 (disabled last 15 epochs) |
| Mixup | 0.05 |
| Copy-Paste | 0.2 |
| Erasing | 0.2 |

## Performance Metrics (V4 Production)

| Metric | Value |
|--------|-------|
| **mAP50** | **0.9145** |
| **mAP50-95** | **0.6984** |
| **Precision** | **0.9235** |
| **Recall** | **0.8731** |
| Parameters | 25,900,000 (25.9M) |
| Model File | `best_v4_production.pt` |

### Per-Class Context
- **colony**: Primary detection target; significant improvement from V3 colony mAP50=0.629 to V4 overall mAP50=0.9145
- **bubble**: Very high detection accuracy (~0.995 mAP50 since V2)
- **dust**: Moderate detection; synthetic augmentation helps generalization
- **crack**: Most challenging class due to visual similarity with colony edges; stratified validation ensures minimum representation

## CFU Classification

The system classifies colony counts following industry standards:
- **< 30 colonies** → TFTC (Too Few To Count)
- **30–300 colonies** → IDEAL (within counting range)
- **> 300 colonies** → TNTC (Too Numerous To Count)

## Ethical Considerations

- This model is designed as a decision-support tool for laboratory technicians, not a replacement for human judgment
- Results should be verified by trained personnel for regulatory samples
- The model was trained on publicly available datasets; no patient data was used
- False negatives (missed colonies) could lead to underestimation of bacterial contamination — human-in-the-loop verification is recommended for critical applications
- The model may exhibit bias toward colony morphologies well-represented in the training data (primarily from AGAR dataset)

## Limitations

1. Performance may degrade on agar types not well-represented in training data (e.g., blood agar, MacConkey)
2. Overlapping/touching colonies may be counted as a single detection
3. Very small colonies (< 15px) may be missed due to detection threshold
4. Extreme lighting conditions or image quality may affect detection accuracy
5. The model does not differentiate bacterial species — all colonies are counted equally

## Deployment

- **Gradio Web App**: https://healthcare.jatnikonm.tech
- **REST API**: https://healthcare.jatnikonm.tech/api/predict
- **MLflow Tracking**: https://ml.jatnikonm.tech
- **Model Engine**: `model_engine.py` loads `best_v4_production.pt`
- **Flutter Mobile App**: PlateVisionAI (connects to REST API)
