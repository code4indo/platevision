#!/bin/bash
cd /media/lambda_one/DFSSD04/project/healtcare
source .venv/bin/activate
mkdir -p data/agar
echo 'Starting AGAR download...' > data/agar_download.log
kaggle datasets download -d clb2256095392/automatic-colony-counting -p data/agar --unzip >> data/agar_download.log 2>&1
echo 'Download complete' >> data/agar_download.log
