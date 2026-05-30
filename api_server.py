#!/usr/bin/env python3
"""
Plate Count Reader - FastAPI + Gradio Combined Server

Menyediakan:
- REST API di /api/health dan /api/predict untuk aplikasi Flutter
- Gradio UI di root path untuk browser

Usage:
    python3 api_server.py                # Start on default port 7860
    python3 api_server.py --port 8080    # Custom port
"""

import argparse
import time
import io
import os
import json
import base64
import uuid
from pathlib import Path
from datetime import datetime, date
from contextlib import asynccontextmanager

import numpy as np
from PIL import Image
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

from model_engine import model, detect_colonies, MODEL_PATH, BASE_DIR

# Import Gradio app builder
import gradio as gr
import gradio_app as gradio_module

# ============================================================================
# FastAPI App
# ============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("=" * 60)
    print("  Plate Count Reader - API Server Starting")
    print(f"  Model: {MODEL_PATH.name if MODEL_PATH.exists() else 'NOT FOUND'}")
    print(f"  Model loaded: {model is not None}")
    print("=" * 60)
    yield
    print("  API Server shutting down...")

app = FastAPI(
    title="Plate Count Reader API",
    description="REST API untuk PlateVisionAI Flutter app + Gradio Web UI",
    version="1.0.0",
    lifespan=lifespan,
)

# ============================================================================
# CORS Middleware — allow Flutter web app (platevision.jatnikonm.tech) to call API
# ============================================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://platevision.jatnikonm.tech",
        "https://healthcare.jatnikonm.tech",
        "http://localhost:7860",
        "http://127.0.0.1:7860",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "Accept"],
)

# ============================================================================
# Health Check Endpoint
# ============================================================================

@app.get("/api/health")
async def health_check():
    """Health check endpoint for Flutter app."""
    start = time.time()
    is_healthy = model is not None
    response_time = time.time() - start

    return JSONResponse({
        "status": "healthy" if is_healthy else "unhealthy",
        "is_healthy": is_healthy,
        "model_version": "YOLOv8-v4" if is_healthy else None,
        "model_loaded": is_healthy,
        "timestamp": datetime.utcnow().isoformat(),
        "response_time_ms": round(response_time * 1000, 2),
    })

# ============================================================================
# Prediction Endpoint
# ============================================================================

@app.post("/api/predict")
async def predict(
    file: UploadFile = File(...),
    conf_threshold: float = 0.25,
    iou_threshold: float = 0.45,
):
    """
    Predict endpoint for Flutter app.
    
    Accepts image file upload and returns detection results as JSON.
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    # Validate file type
    allowed_types = {"image/jpeg", "image/jpg", "image/png", "image/bmp", "image/tiff", "image/webp"}
    content_type = file.content_type or ""
    if content_type not in allowed_types:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported file type: {content_type}. Supported: JPEG, PNG, BMP, TIFF"
        )

    try:
        # Read image bytes
        image_bytes = await file.read()
        if len(image_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty file")

        # Convert to numpy array (RGB)
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        image_np = np.array(image)

        # Run detection
        start_time = time.time()
        annotated, results = detect_colonies(
            image_np,
            conf_threshold=conf_threshold,
            iou_threshold=iou_threshold,
        )
        elapsed = time.time() - start_time

        if "error" in results:
            raise HTTPException(status_code=500, detail=results["error"])

        stats = results.get("statistics", {})
        colonies = results.get("colonies", [])

        # Encode annotated image to base64 for optional return
        annotated_pil = Image.fromarray(annotated)
        buffered = io.BytesIO()
        annotated_pil.save(buffered, format="PNG")
        annotated_b64 = base64.b64encode(buffered.getvalue()).decode("utf-8")

        # Build response matching Flutter app's expected format
        detections = []
        for c in colonies:
            detections.append({
                "class": c["class_id"],
                "class_name": c["class"],
                "confidence": c["confidence"],
                "bbox": c["bbox"],
                "x1": c["bbox"][0],
                "y1": c["bbox"][1],
                "x2": c["bbox"][2],
                "y2": c["bbox"][3],
                "width": c["width"],
                "height": c["height"],
                "area_px": c["area_px"],
            })

        return JSONResponse({
            "status": "success",
            "model_version": "YOLOv8-v4",
            "processing_time_ms": round(elapsed * 1000, 1),
            "inference_time_ms": stats.get("inference_time_ms", round(elapsed * 1000, 1)),
            "image_width": image.width,
            "image_height": image.height,
            "total_detections": stats.get("total_objects", 0),
            "total_colonies": stats.get("total_colonies", 0),
            "class_breakdown": stats.get("class_breakdown", {}),
            "avg_confidence": stats.get("avg_confidence", 0),
            "detections": detections,
            "annotated_image_base64": f"data:image/png;base64,{annotated_b64}",
        })

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")


# ============================================================================
# Analysis Persistence Store (JSON file-based)
# ============================================================================

ANALYSES_DIR = BASE_DIR / "data" / "analyses"
ANALYSES_DIR.mkdir(parents=True, exist_ok=True)


def _load_analyses():
    """Load all analyses from JSON files, sorted newest-first."""
    analyses = []
    if not ANALYSES_DIR.exists():
        return analyses
    for fpath in sorted(ANALYSES_DIR.iterdir(), reverse=True):
        if fpath.suffix != ".json":
            continue
        try:
            with open(fpath) as f:
                analyses.append(json.load(f))
        except (json.JSONDecodeError, OSError):
            continue
    return analyses


def _save_analysis(data: dict) -> str:
    """Save a single analysis dict to a JSON file. Returns the analysis ID."""
    analysis_id = data.get("id") or str(uuid.uuid4())[:8]
    data["id"] = analysis_id
    fpath = ANALYSES_DIR / f"{analysis_id}.json"
    with open(fpath, "w") as f:
        json.dump(data, f, indent=2, default=str)
    return analysis_id


def _delete_analysis_file(analysis_id: str):
    fpath = ANALYSES_DIR / f"{analysis_id}.json"
    if fpath.exists():
        fpath.unlink()


# ============================================================================
# Analysis Persistence Endpoints
# ============================================================================


class AnalysisSaveRequest(BaseModel):
    """Payload for saving an analysis result."""
    id: str | None = None
    image_filename: str = ""
    image_width: int = 0
    image_height: int = 0
    processing_time_ms: float = 0.0
    inference_time_ms: float = 0.0
    model_version: str = "YOLOv8-v4"
    total_detections: int = 0
    total_colonies: int = 0
    avg_confidence: float = 0.0
    class_breakdown: dict[str, int] = {}
    detections: list[dict] = []
    annotated_image_base64: str | None = None
    batch_id: str | None = None
    media_type: str | None = None
    dilution: str | None = None
    operator_name: str | None = None
    laboratory: str | None = None
    notes: str | None = None


@app.post("/api/analyses")
async def save_analysis(req: AnalysisSaveRequest):
    """Save an analysis result to server-side storage."""
    try:
        analysis = req.model_dump()
        analysis["created_at"] = datetime.utcnow().isoformat()
        analysis["updated_at"] = analysis["created_at"]
        # Strip large base64 to save space; store separately
        annotated_b64 = analysis.pop("annotated_image_base64", None)

        analysis_id = _save_analysis(analysis)

        # Save annotated image separately if present
        if annotated_b64:
            img_dir = ANALYSES_DIR / "images"
            img_dir.mkdir(exist_ok=True)
            try:
                # Strip data:image/png;base64, prefix if present
                if "," in annotated_b64:
                    annotated_b64 = annotated_b64.split(",", 1)[1]
                img_bytes = base64.b64decode(annotated_b64)
                img_path = img_dir / f"{analysis_id}.png"
                with open(img_path, "wb") as f:
                    f.write(img_bytes)
            except Exception:
                pass  # non-critical

        return JSONResponse({
            "status": "saved",
            "id": analysis_id,
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Save error: {str(e)}")


@app.get("/api/analyses")
async def list_analyses(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    batch_id: str | None = Query(None),
    media_type: str | None = Query(None),
    operator_name: str | None = Query(None),
):
    """List saved analyses with optional filtering and pagination."""
    analyses = _load_analyses()

    # Apply filters
    if batch_id:
        analyses = [a for a in analyses if a.get("batch_id") == batch_id]
    if media_type:
        analyses = [a for a in analyses if a.get("media_type") == media_type]
    if operator_name:
        analyses = [a for a in analyses if a.get("operator_name") == operator_name]

    total = len(analyses)
    page = analyses[offset:offset + limit]

    return JSONResponse({
        "status": "success",
        "total": total,
        "offset": offset,
        "limit": limit,
        "analyses": page,
    })


@app.get("/api/analyses/{analysis_id}")
async def get_analysis(analysis_id: str):
    """Get a single analysis by ID."""
    fpath = ANALYSES_DIR / f"{analysis_id}.json"
    if not fpath.exists():
        raise HTTPException(status_code=404, detail="Analysis not found")
    try:
        with open(fpath) as f:
            data = json.load(f)
        # Include annotated image if available
        img_path = ANALYSES_DIR / "images" / f"{analysis_id}.png"
        if img_path.exists():
            with open(img_path, "rb") as f:
                b64 = base64.b64encode(f.read()).decode("utf-8")
            data["annotated_image_base64"] = f"data:image/png;base64,{b64}"
        return JSONResponse({"status": "success", "analysis": data})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Read error: {str(e)}")


@app.delete("/api/analyses/{analysis_id}")
async def delete_analysis(analysis_id: str):
    """Delete an analysis by ID."""
    _delete_analysis_file(analysis_id)
    img_path = ANALYSES_DIR / "images" / f"{analysis_id}.png"
    if img_path.exists():
        img_path.unlink()
    return JSONResponse({"status": "deleted", "id": analysis_id})


@app.get("/api/analyses/stats/overview")
async def analyses_overview():
    """Aggregated statistics for dashboard."""
    analyses = _load_analyses()

    total_analyses = len(analyses)
    total_colonies = sum(a.get("total_colonies", 0) for a in analyses)
    total_detections = sum(a.get("total_detections", 0) for a in analyses)

    # Class breakdown across all analyses
    class_breakdown: dict[str, int] = {}
    for a in analyses:
        cb = a.get("class_breakdown", {})
        for cls, cnt in cb.items():
            class_breakdown[cls] = class_breakdown.get(cls, 0) + cnt

    # Daily counts (last 30 days)
    daily_colony_counts: dict[str, int] = {}
    daily_analysis_counts: dict[str, int] = {}
    for a in analyses:
        created = a.get("created_at", "")
        day = created[:10] if created else ""
        if day:
            daily_colony_counts[day] = daily_colony_counts.get(day, 0) + a.get("total_colonies", 0)
            daily_analysis_counts[day] = daily_analysis_counts.get(day, 0) + 1

    # Confidence stats
    confs = []
    proc_times = []
    for a in analyses:
        avg = a.get("avg_confidence", 0)
        if avg > 0:
            confs.append(avg)
        pt = a.get("processing_time_ms", 0)
        if pt > 0:
            proc_times.append(pt)

    avg_confidence = round(sum(confs) / len(confs), 3) if confs else 0
    avg_processing_time = round(sum(proc_times) / len(proc_times), 1) if proc_times else 0

    # Recent activity (last 20)
    recent = []
    for a in analyses[:20]:
        recent.append({
            "id": a.get("id"),
            "created_at": a.get("created_at"),
            "total_colonies": a.get("total_colonies", 0),
            "total_detections": a.get("total_detections", 0),
            "processing_time_ms": a.get("processing_time_ms", 0),
            "avg_confidence": a.get("avg_confidence", 0),
            "media_type": a.get("media_type"),
            "dilution": a.get("dilution"),
            "operator_name": a.get("operator_name"),
        })

    return JSONResponse({
        "status": "success",
        "total_analyses": total_analyses,
        "total_colonies": total_colonies,
        "total_detections": total_detections,
        "class_breakdown": class_breakdown,
        "avg_confidence": avg_confidence,
        "avg_processing_time_ms": avg_processing_time,
        "daily_colony_counts": dict(sorted(daily_colony_counts.items())),
        "daily_analysis_counts": dict(sorted(daily_analysis_counts.items())),
        "recent_activity": recent,
    })

# ============================================================================
# Mount Gradio App
# ============================================================================

gradio_app = gradio_module.create_app()
app = gr.mount_gradio_app(app, gradio_app, path="/")

# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Plate Count Reader API Server")
    parser.add_argument("--port", type=int, default=7860, help="Server port (default: 7860)")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Server host (default: 0.0.0.0)")
    args = parser.parse_args()

    print(f"\n{'='*60}")
    print(f"  Starting Plate Count Reader API Server")
    print(f"  Host: {args.host}:{args.port}")
    print(f"  API:  http://{args.host}:{args.port}/api/health")
    print(f"  API:  http://{args.host}:{args.port}/api/predict")
    print(f"  UI:   http://{args.host}:{args.port}/")
    print(f"{'='*60}\n")

    uvicorn.run(app, host=args.host, port=args.port)
