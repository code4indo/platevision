#!/bin/bash
cd /media/lambda_one/DFSSD04/project/healtcare
source .venv/bin/activate
echo "Training started at $(date)" > training_gpu1.log
PYTHONUNBUFFERED=1 python3 -u src/train_18k_gpu1.py >> training_gpu1.log 2>&1
echo "Training completed at $(date)" >> training_gpu1.log

