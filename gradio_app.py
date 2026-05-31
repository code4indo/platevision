#!/usr/bin/env python3
"""
Plate Count Reader - Gradio Web Application V2
Layout optimized: compact, efficient, mobile-friendly

Changes from V1:
- Compact 2-column layout with better proportions (2:3 input:output)
- Stats cards instead of plain textbox for Quick Count
- Side-by-side sliders in single row
- Tabbed sample gallery instead of stacked (saves 70% vertical space)
- Collapsible detail results
- Better mobile responsiveness
- Removed redundant section headers
"""

import os
import sys
import argparse
from pathlib import Path
from datetime import datetime

from model_engine import (
    model,
    MODEL_PATH,
    SAMPLES_DIR,
    detect_colonies,
    count_colonies_only,
    format_results_table,
)

import gradio as gr


def _count_class(category_dict):
    """Count items in sample category."""
    return len(category_dict)


def create_app():
    """Create the Gradio application — compact layout V2."""

    custom_css = """
    /* ── Base ── */
    .gradio-container { max-width: 1200px !important; margin: auto; }
    
    /* ── Header: Slimmer ── */
    .header-bar {
        background: linear-gradient(135deg, #0d9488, #115e59);
        color: white; padding: 1rem 1.5rem; border-radius: 10px;
        display: flex; align-items: center; justify-content: space-between;
        margin-bottom: 1rem;
    }
    .header-bar h1 { margin: 0; font-size: 1.4rem; font-weight: 700; }
    .header-bar .subtitle { opacity: 0.85; font-size: 0.85rem; }
    .header-bar .badge {
        background: rgba(255,255,255,0.2); border-radius: 6px;
        padding: 0.25rem 0.6rem; font-size: 0.75rem; font-weight: 600;
    }
    
    /* ── Stat Cards ── */
    .stat-row { display: flex; gap: 0.75rem; margin-bottom: 0.75rem; }
    .stat-card {
        flex: 1; background: #f0fdfa; border: 1px solid #99f6e4;
        border-radius: 8px; padding: 0.6rem 0.8rem; text-align: center;
    }
    .stat-card .label { font-size: 0.7rem; color: #6b7280; text-transform: uppercase; letter-spacing: 0.05em; }
    .stat-card .value { font-size: 1.8rem; font-weight: 800; color: #0d9488; line-height: 1.2; }
    .stat-card .sub { font-size: 0.7rem; color: #0d9488; }
    .stat-card.warn { background: #fef3c7; border-color: #fcd34d; }
    .stat-card.warn .value { color: #d97706; }
    .stat-card.warn .sub { color: #d97706; }
    .stat-card.danger { background: #fef2f2; border-color: #fca5a5; }
    .stat-card.danger .value { color: #dc2626; }
    .stat-card.danger .sub { color: #dc2626; }
    
    /* ── Hide footer ── */
    footer { display: none !important; }
    
    /* ── Compact sliders ── */
    .compact-row .form { gap: 0.5rem !important; }
    
    /* ── Sample tabs ── */
    .sample-tabs { margin-top: 0.5rem; }
    
    /* ── Detail box ── */
    .detail-box textarea { font-family: 'Courier New', monospace; font-size: 0.8rem; }
    """

    with gr.Blocks(
        title="Plate Count Reader",
        css=custom_css,
        theme=gr.themes.Soft(spacing_size="sm", radius_size="md"),
    ) as app:

        # ── Compact Header ──
        gr.HTML("""
        <div class="header-bar">
            <div>
                <h1>🧫 Plate Count Reader</h1>
                <span class="subtitle">Automated Colony Counter | AI Open Hackathon</span>
            </div>
            <span class="badge">YOLOv8-v4</span>
        </div>
        """)

        # ── Main: 2-column (input 2 : output 3) ──
        with gr.Row(equal_height=True):
            # LEFT: Input (narrower)
            with gr.Column(scale=2, min_width=320):
                input_image = gr.Image(
                    label="📸 Upload Agar Plate",
                    type="numpy",
                    height=350,
                    sources=["upload", "clipboard"],
                )

                with gr.Row():
                    conf_slider = gr.Slider(
                        0.05, 0.95, value=0.25, step=0.05,
                        label="Confidence", info="Deteksi min",
                        scale=1,
                    )
                    iou_slider = gr.Slider(
                        0.1, 0.9, value=0.45, step=0.05,
                        label="IoU (NMS)", info="Overlap max",
                        scale=1,
                    )

                with gr.Row():
                    detect_btn = gr.Button("🔍 Deteksi Koloni", variant="primary", size="lg", scale=3)
                    clear_btn = gr.Button("🗑️ Clear", variant="secondary", size="lg", scale=1)

                # Stats cards (replaces plain textbox)
                stat_html = gr.HTML(
                    value='<div class="stat-row">'
                          '<div class="stat-card"><div class="label">Koloni</div><div class="value">—</div><div class="sub">colony count</div></div>'
                          '<div class="stat-card"><div class="label">Total Objek</div><div class="value">—</div><div class="sub">all detections</div></div>'
                          '<div class="stat-card"><div class="label">Confidence</div><div class="value">—</div><div class="sub">rata-rata</div></div>'
                          '<div class="stat-card"><div class="label">Status</div><div class="value">—</div><div class="sub">TFTC/IDEAL/TNTC</div></div>'
                          '</div>',
                )

            # RIGHT: Output (wider)
            with gr.Column(scale=3, min_width=400):
                output_image = gr.Image(
                    label="🎯 Hasil Deteksi",
                    type="numpy",
                    height=450,
                )

        # ── Detail Results (collapsible) ──
        with gr.Accordion("📋 Detail Hasil Deteksi", open=False):
            results_text = gr.Textbox(
                interactive=False,
                lines=15,
                max_lines=25,
                show_label=False,
                elem_classes=["detail-box"],
            )

        # ── Sample Images (TABS — saves ~70% vertical space) ──
        sample_categories = {
            "🧫 Colony": sorted([
                str(f) for f in SAMPLES_DIR.glob("test_colony_*")
                if f.suffix.lower() in ('.jpg', '.jpeg', '.png')
                and not any(x in f.name for x in ("bubble", "dust", "crack"))
            ]),
            "🫧 Bubble": sorted([
                str(f) for f in SAMPLES_DIR.glob("test_bubble_*")
                if f.suffix.lower() in ('.jpg', '.jpeg', '.png')
            ]),
            "💫 Dust": sorted([
                str(f) for f in SAMPLES_DIR.glob("test_dust_*")
                if f.suffix.lower() in ('.jpg', '.jpeg', '.png')
            ]),
            "🔧 Crack": sorted([
                str(f) for f in SAMPLES_DIR.glob("test_crack_*")
                if f.suffix.lower() in ('.jpg', '.jpeg', '.png')
            ]),
            "🔬 Multi": sorted(
                [str(f) for f in SAMPLES_DIR.glob("test_colony_bubble_*")
                 if f.suffix.lower() in ('.jpg', '.jpeg', '.png')]
                + [str(f) for f in SAMPLES_DIR.glob("test_colony_dust_*")
                   if f.suffix.lower() in ('.jpg', '.jpeg', '.png')]
                + [str(f) for f in SAMPLES_DIR.glob("test_colony_crack_*")
                   if f.suffix.lower() in ('.jpg', '.jpeg', '.png')]
            ),
            "🧪 Real": sorted([
                str(f) for f in SAMPLES_DIR.glob("test_real_*")
                if f.suffix.lower() in ('.jpg', '.jpeg', '.png')
            ]),
        }
        original_samples = sorted([
            str(f) for f in SAMPLES_DIR.glob("*")
            if f.suffix.lower() in ('.jpg', '.jpeg', '.png')
            and not f.name.startswith("result_")
            and not f.name.startswith("test_")
        ])

        has_any = any(v for v in sample_categories.values()) or original_samples
        if has_any:
            with gr.Accordion("🖼️ Sample Gambar (klik untuk memuat)", open=False):
                with gr.Tabs():
                    for cat_name, cat_files in sample_categories.items():
                        if cat_files:
                            with gr.Tab(f"{cat_name} ({len(cat_files)})"):
                                gr.Examples(
                                    examples=cat_files,
                                    inputs=input_image,
                                    examples_per_page=12,
                                )
                    if original_samples:
                        with gr.Tab(f"📸 Demo ({len(original_samples)})"):
                            gr.Examples(
                                examples=original_samples,
                                inputs=input_image,
                                examples_per_page=12,
                            )

        # ── Model Info (accordion, collapsed) ──
        with gr.Accordion("ℹ️ Info Model & Petunjuk", open=False):
            if model:
                gr.Markdown(f"""
                **YOLOv8m V4** | `{MODEL_PATH.name}` | {MODEL_PATH.stat().st_size/(1024*1024):.1f} MB | {sum(p.numel() for p in model.model.parameters()):,} params
                
                **4 Kelas:** colony, bubble, dust, crack | **mAP50:** 0.9145 | **Precision:** 0.9235 | **Recall:** 0.8731
                
                ---
                **Interpretasi:** TFTC (<30) → IDEAL (30-300) → TNTC (>300)  
                **GPU:** 2x NVIDIA RTX A4000 (16GB)  
                **Cara pakai:** Upload foto → sesuaikan threshold → Deteksi
                """)
            else:
                gr.Markdown("⚠️ Model belum dimuat. Pastikan `best_v4_production.pt` ada di folder `models/`")

        # ── Event Handlers ──
        def on_detect(image, conf, iou):
            if image is None:
                empty_stats = '<div class="stat-row">' \
                    '<div class="stat-card"><div class="label">Koloni</div><div class="value">—</div></div>' \
                    '<div class="stat-card"><div class="label">Total Objek</div><div class="value">—</div></div>' \
                    '<div class="stat-card"><div class="label">Confidence</div><div class="value">—</div></div>' \
                    '<div class="stat-card"><div class="label">Status</div><div class="value">—</div></div>' \
                    '</div>'
                return None, empty_stats, "❌ Upload gambar terlebih dahulu"

            annotated, results = detect_colonies(image, conf_threshold=conf, iou_threshold=iou)
            detail = format_results_table(results)

            # Extract stats
            stats = results.get("statistics", {})
            total_colonies = stats.get("total_colonies", 0)
            total_objects = stats.get("total_objects", 0)
            avg_conf = stats.get("avg_confidence", 0)

            # Determine TFTC/IDEAL/TNTC status
            if total_colonies < 30:
                status, status_cls = "TFTC", "warn"
                status_sub = "< 30 koloni"
            elif total_colonies <= 300:
                status, status_cls = "IDEAL", ""
                status_sub = "30-300 koloni"
            else:
                status, status_cls = "TNTC", "danger"
                status_sub = "> 300 koloni"

            stats_html = f'<div class="stat-row">' \
                f'<div class="stat-card"><div class="label">Koloni</div><div class="value">{total_colonies}</div><div class="sub">colony</div></div>' \
                f'<div class="stat-card"><div class="label">Total Objek</div><div class="value">{total_objects}</div><div class="sub">semua deteksi</div></div>' \
                f'<div class="stat-card"><div class="label">Confidence</div><div class="value">{avg_conf:.1%}</div><div class="sub">rata-rata</div></div>' \
                f'<div class="stat-card {status_cls}"><div class="label">Status</div><div class="value">{status}</div><div class="sub">{status_sub}</div></div>' \
                f'</div>'

            return annotated, stats_html, detail

        def on_clear():
            empty_stats = '<div class="stat-row">' \
                '<div class="stat-card"><div class="label">Koloni</div><div class="value">—</div></div>' \
                '<div class="stat-card"><div class="label">Total Objek</div><div class="value">—</div></div>' \
                '<div class="stat-card"><div class="label">Confidence</div><div class="value">—</div></div>' \
                '<div class="stat-card"><div class="label">Status</div><div class="value">—</div></div>' \
                '</div>'
            return None, empty_stats, ""

        detect_btn.click(
            fn=on_detect,
            inputs=[input_image, conf_slider, iou_slider],
            outputs=[output_image, stat_html, results_text],
        )
        clear_btn.click(
            fn=on_clear,
            outputs=[input_image, stat_html, results_text],
        )
        input_image.upload(
            fn=on_detect,
            inputs=[input_image, conf_slider, iou_slider],
            outputs=[output_image, stat_html, results_text],
        )

    return app


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Plate Count Reader - Gradio V2')
    parser.add_argument('--port', type=int, default=7860)
    parser.add_argument('--host', type=str, default='0.0.0.0')
    parser.add_argument('--share', action='store_true')
    parser.add_argument('--debug', action='store_true')
    args = parser.parse_args()

    print(f"\n{'='*60}")
    print(f"  Plate Count Reader V2 - Compact Layout")
    print(f"  {args.host}:{args.port}")
    print(f"{'='*60}\n")

    app = create_app()
    app.launch(
        server_name=args.host,
        server_port=args.port,
        share=args.share,
        debug=args.debug,
    )
