# Model Card: Plate Count Reader

## Model Details

- **Model Name**: Plate Count Reader - Colony Detector
- **Model Version**: v1.0
- **Architecture**: YOLOv8s (Small variant)
- **Task**: Object Detection (Bacterial Colony Detection)
- **Date**: May 2025
- **Developed by**: AI Open Hackathon - Healthcare Team

## Intended Use

- **Primary Use**: Automated detection and counting of bacterial colonies on agar plate images
- **Primary Users**: Microbiology laboratory technicians, quality control personnel
- **Out-of-Scope**: Clinical diagnosis, medical decision-making, non-agar plate images

## Training Data

### Datasets Used
1. **AGAR (Annotated Germs in Agar Plates)** - 20,623 images from Kaggle
   - Source: https://agar.neurosys.pl/
   - Contains diverse agar plate images with varying colony densities
   - Annotations converted from segmentation masks to bounding boxes

2. **DIBaS (Digital Images of Bacterial Species)** - 692 images from Kaggle
   - Source: https://misztal.edu.pl/software/databases/dibas/
   - 33 bacterial species, 20 images each

3. **Microbial Colony Recognition** - 40 images from Kaggle
   - Source: Kaggle dataset by zoya77
   - JSON bounding box annotations

### Data Processing
- All datasets converted to YOLOv8 format
- Single class: "colony" (class 0)
- Split: 70% train (205), 15% val (44), 15% test (45)

## Training Configuration

| Parameter | Value |
|-----------|-------|
| Base Model | yolov8s.pt (pretrained) |
| Epochs | 50 |
| Image Size | 640 |
| Batch Size | 16 |
| Optimizer | AdamW |
| Learning Rate | 0.001 (initial) → 0.01 (final) |
| Scheduler | Cosine LR with warmup (3 epochs) |
| Device | Tesla T4 GPU (Kaggle) |
| Seed | 42 |

## Performance Metrics

| Metric | Value |
|--------|-------|
| mAP50 | 0.866 |
| mAP50-95 | 0.604 |
| Precision | 0.933 |
| Recall | 0.835 |
| Parameters | 11,135,987 |
| Model Size | 21.5 MB |

## Ethical Considerations

- This model is a PoC for hackathon demonstration purposes
- Results should not be used for clinical decisions without validation
- Human verification recommended for critical applications

## Future Improvements

1. Expand dataset with more diverse agar plate images
2. Add multi-class detection (different colony morphologies)
3. Implement CFU calculation with dilution factor input
4. Train with larger model variant (YOLOv8m/l)
5. Add explainability features (GradCAM, attention maps)
