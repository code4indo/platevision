#!/bin/bash
cd /media/lambda_one/DFSSD04/project/healtcare
source .venv/bin/activate
echo "Starting V2 FULL training at $(date)"
python3 src/train_v2_fixed.py --train-only 2>&1
echo "Full training completed at $(date)"
