#!/bin/bash
cd /media/lambda_one/DFSSD04/project/healtcare
source .venv/bin/activate
echo "Training started at $(date)" > training.log
python3 src/train_18k_mlflow.py >> training.log 2>&1
echo "Training completed at $(date)" >> training.log
