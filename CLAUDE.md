# CLAUDE.md — Project Context for Claude Code

> This file provides Claude Code with essential context about the Plate Count Reader project.
> For comprehensive details, see `AGENTS.md`.

## Project Summary

Automated bacterial colony counter on agar plates using YOLOv8 object detection.
- **Path**: `/media/lambda_one/DFSSD04/project/healtcare`
- **Purpose**: Detect & count colonies, bubbles, dust, cracks on agar plate images
- **Hackathon**: AI Open Innovation Challenge 2026 — Healthcare Category

## Quick Start

```bash
cd /media/lambda_one/DFSSD04/project/healtcare
source .venv/bin/activate   # ALWAYS activate venv first!
```

## 4 Detection Classes
`colony` (0) | `bubble` (1) | `dust` (2) | `crack` (3)

## Key Files
| File | Purpose |
|------|---------|
| `gradio_app.py` | Web UI (main demo), uses `models/best_v4_production.pt` |
| `src/train_v4_production.py` | Latest training script (YOLOv8m) |
| `src/inference.py` | CLI inference |
| `src/evaluate.py` | Model evaluation |
| `src/convert_dataset.py` | Dataset format converter |
| `src/create_stratified_split.py` | Stratified data splitting |
| `src/augment_colony_v2.py` | Colony augmentation |

## Production Dataset
`data/yolo_v3_production/` — stratified split + 2,000 synthetic colony augmentations (~5,357 images), 4 classes, use for all new training.

## Current Best Model
`models/best_v4_production.pt` — mAP50=0.9145, mAP50-95=0.6984, Precision=0.9235, Recall=0.8731
Architecture: YOLOv8m (25.9M params), Dataset: yolo_v3_production (5,357 images)

### Legacy Model
`models/best_v3_enhanced.pt` — mAP50=0.775, mAP50-95=0.525, Precision=0.747, Recall=0.859

## Hardware
2x NVIDIA RTX A4000 (16GB each)

## Important Conventions
- Python 3.10, ultralytics 8.4.48, torch 2.7.0
- Paths are hardcoded to `/media/lambda_one/DFSSD04/project/healtcare`
- Naming: `train_v<version>_<variant>.py`, `best_<version>_<desc>.pt`
- Comments mixed Indonesian/English
- No `requirements.txt` — packages in `.venv`
- `tests/` directory is empty — needs implementation
- MLflow at `https://ml.jatnikonm.tech`

## Before Modifying
- Read `AGENTS.md` for full architecture details
- Check `PRODUCTION_READINESS_ROADMAP.md` for planned improvements
- Always test with sample images in `samples/` before deploying Gradio changes
