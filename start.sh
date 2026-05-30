#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Plate Count Reader - Launch Script
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Plate Count Reader - Automated Colony Counter          ║"
echo "║  AI Open Hackathon - Healthcare Category                ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Check model
if [ ! -f "models/best_plate_count_reader.pt" ]; then
    echo "❌ Model tidak ditemukan di models/best_plate_count_reader.pt"
    echo "   Pastikan model sudah didownload dari Kaggle"
    exit 1
fi

echo "✅ Model ditemukan: models/best_plate_count_reader.pt ($(du -h models/best_plate_count_reader.pt | cut -f1))"

# Check GPU
if command -v nvidia-smi &> /dev/null; then
    echo "✅ GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"
else
    echo "⚠️  GPU tidak terdeteksi (akan menggunakan CPU)"
fi

# Check Python packages
python3 -c "import ultralytics, gradio" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "📦 Installing required packages..."
    pip3 install ultralytics gradio
fi

echo ""
echo "🚀 Starting Gradio application..."
echo "   URL: http://0.0.0.0:7860"
echo ""

python3 gradio_app.py "$@"
