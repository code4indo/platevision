#!/bin/bash
cd /media/lambda_one/DFSSD04/project/healtcare
export PYTHONUNBUFFERED=1

yolo detect train \
  data=data/yolo_v3_production/data.yaml \
  model=yolov8m.pt \
  epochs=150 \
  imgsz=640 \
  batch=16 \
  patience=40 \
  device=0 \
  workers=6 \
  project=runs \
  name=runs_v4_production \
  exist_ok=True \
  pretrained=True \
  optimizer=AdamW \
  lr0=0.0008 \
  lrf=0.008 \
  cos_lr=True \
  momentum=0.9 \
  weight_decay=0.0005 \
  warmup_epochs=5 \
  warmup_momentum=0.8 \
  warmup_bias_lr=0.05 \
  box=7.5 \
  cls=3.5 \
  dfl=1.5 \
  hsv_h=0.015 \
  hsv_s=0.6 \
  hsv_v=0.4 \
  degrees=8 \
  translate=0.08 \
  scale=0.4 \
  shear=0 \
  perspective=0.0 \
  flipud=0.3 \
  fliplr=0.5 \
  mosaic=0.3 \
  mixup=0.05 \
  copy_paste=0.2 \
  erasing=0.2 \
  label_smoothing=0.05 \
  close_mosaic=15 \
  save=True \
  plots=True
