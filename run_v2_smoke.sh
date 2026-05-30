#!/bin/bash
cd /media/lambda_one/DFSSD04/project/healtcare
source .venv/bin/activate
echo "Starting V2 smoke test at $(date)"
python3 src/train_v2_fixed.py --smoke 2>&1
echo "Smoke test completed at $(date)"
