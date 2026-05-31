# Production Readiness Roadmap - PlateVision AI V4
# Generated: 2026-05-11 | Updated: 2026-05-31
# Owner: AI/ML Engineering Team
# Status: V4 IN PRODUCTION — Remaining items for next iteration

═══════════════════════════════════════════════════════════════════════════════
PHASE 1: DATA ENGINEERING & VALIDATION (Week 1-2)
═══════════════════════════════════════════════════════════════════════════════

✓ 1.1 VALIDATION SET REBALANCING [COMPLETED]
    Problem: val set extremely imbalanced (1818 colony vs 58 crack)
    Action: Create stratified validation set with min 200 instances per class
    Result: yolo_v3_production created with stratified split, min 150/class in val
    Deliverable: data/yolo_v3_production/ ✓

✓ 1.2 COLONY DATA AUGMENTATION PIPELINE [COMPLETED]
    Problem: colony mAP50 only 0.629 — insufficient variety
    Action: Copy-paste augmentation from existing colony crops (augment_colony_v2.py)
    Result: 2,000 synthetic colony images added, total dataset ~5,357 images
    Deliverable: 2,000 syn_col_*.jpg in data/yolo_v3_production/train/ ✓

□ 1.3 DATA QUALITY AUDIT
    Action:
      - Run bounding box quality check (IoU < 0.3 flags)
      - Detect mislabeled classes (visual inspection of 500 random samples)
      - Remove duplicate/near-duplicate images
    Tool: fiftyone, cleanlab, or custom CV audit script
    Deliverable: data_audit_report_v3.md
    Owner: Data Engineer
    ETA: 2 days

□ 1.4 TEST SET CREATION (HOLDOUT)
    Problem: No dedicated test set for final evaluation
    Action: Create 500-image holdout set (never seen during training/validation)
    - Source: 30% from each dataset (AGAR, DIBaS, internal lab images)
    - Annotations verified by 2 annotators + adjudication for disagreements
    - Stratified by class and plate type
    Deliverable: data/yolo_v3_production/test_holdout/
    Owner: Domain Expert + Data Engineer
    ETA: 3 days

═══════════════════════════════════════════════════════════════════════════════
PHASE 2: MODEL ARCHITECTURE & TRAINING (Week 2-3)
═══════════════════════════════════════════════════════════════════════════════

✓ 2.1 ARCHITECTURE UPGRADE [COMPLETED]
    Current: YOLOv8s (11.1M params)
    Result: YOLOv8m (25.9M params) — selected and trained as V4 production model
    Deliverable: best_v4_production.pt, mAP50=0.9145 ✓

✓ 2.2 FOCAL LOSS + CLASS WEIGHTING [COMPLETED]
    Problem: colony class underperforming despite high instance count
    Result: Implemented in V4 training (cls=3.5, label_smoothing=0.05, AdamW optimizer)
    Deliverable: train_v4_production.py ✓

□ 2.3 MULTI-SCALE TRAINING + TEST-TIME AUGMENTATION (TTA)
    Action:
      - Enable multi-scale during training (imgsz range 480-800)
      - Implement TTA at inference: flip + multi-scale averaging
      - NMS threshold tuning per class
    Expected gain: +3-5% mAP50
    Deliverable: Updated inference pipeline
    Owner: ML Engineer
    ETA: 2 days

□ 2.4 KNOWLEDGE DISTILLATION (OPTIONAL)
    If YOLOv8m performs significantly better:
    - Train YOLOv8m as teacher
    - Distill to YOLOv8s/n for production speed
    Target: Retain 95% of teacher accuracy with 50% latency
    Deliverable: distillation_training.py
    Owner: ML Engineer
    ETA: 3 days

═══════════════════════════════════════════════════════════════════════════════
PHASE 3: TESTING & VALIDATION SUITE (Week 3-4)
═══════════════════════════════════════════════════════════════════════════════

□ 3.1 UNIT TESTS FOR INFERENCE PIPELINE [CRITICAL]
    Create tests/ directory with:
      - test_model_loading.py (verify model loads, correct classes)
      - test_inference.py (verify output format, non-empty for valid input)
      - test_preprocessing.py (verify image normalization, resizing)
      - test_postprocessing.py (verify NMS, confidence filtering)
    Framework: pytest + coverage report (target: >80%)
    Deliverable: tests/ directory with CI integration
    Owner: ML Engineer
    ETA: 2 days

□ 3.2 MODEL PERFORMANCE TESTS
    Automated evaluation on:
      - Holdout test set (must achieve colony mAP50 > 0.75)
      - Stress test: 1000 inference calls < 2s each on GPU
      - Edge cases: empty plate, overexposed, blurry, multiple plates
      - Adversarial: rotated 180°, flipped, extreme contrast
    Deliverable: test_performance.py + benchmark_results.json
    Owner: ML Engineer
    ETA: 2 days

□ 3.3 REGRESSION TESTING FRAMEWORK
    Action: Implement model comparison pipeline
      - Automatically compare new model vs production baseline
      - Track per-class metric deltas
      - Block deployment if any class drops > 5% mAP50
    Deliverable: regression_test.py + GitHub Actions workflow
    Owner: ML Engineer + DevOps
    ETA: 2 days

□ 3.4 A/B TEST PROTOCOL
    Design for gradual rollout:
      - 10% traffic → new model, 90% → old model (Week 1)
      - 50/50 split (Week 2)
      - 100% new model (Week 3, if metrics pass)
    Metrics to track:
      - User correction rate (how often user overrides AI count)
      - Average handling time per plate
      - User satisfaction score (1-5 Likert scale)
    Deliverable: ab_test_protocol.md + monitoring dashboard
    Owner: Product Manager + ML Engineer
    ETA: 1 day (design) + ongoing

═══════════════════════════════════════════════════════════════════════════════
PHASE 4: MLOPS & MONITORING (Week 4-5)
═══════════════════════════════════════════════════════════════════════════════

□ 4.1 MODEL REGISTRY (MLflow / DVC)
    Current: ad-hoc file storage in runs/
    Action:
      - Standardize model versioning with MLflow Model Registry
      - Track: metrics, parameters, artifacts, dataset version
      - Stage transitions: None → Staging → Production → Archived
    Deliverable: MLflow registry setup + model promotion workflow
    Owner: MLOps Engineer
    ETA: 2 days

□ 4.2 DATA VERSIONING (DVC)
    Action:
      - Initialize DVC for dataset versioning
      - Track: raw data, processed data, annotations
      - Link dataset version to model version (reproducibility)
    Deliverable: dvc.yaml + remote storage config
    Owner: MLOps Engineer
    ETA: 1 day

□ 4.3 DRIFT DETECTION
    Implement monitoring for:
      - Data drift: input image distribution (brightness, contrast, color)
      - Concept drift: per-class accuracy degradation over time
      - Prediction drift: output confidence score distribution
    Alert threshold: trigger retraining if drift_score > 0.15
    Tool: Evidently AI, WhyLabs, or custom statistical tests
    Deliverable: drift_monitor.py + alerting rules
    Owner: MLOps Engineer
    ETA: 3 days

□ 4.4 LOGGING & OBSERVABILITY
    Action:
      - Structured logging for every inference (image_hash, timestamp, predictions, confidence)
      - Centralized logging: ELK stack or cloud logging
      - Error tracking: Sentry integration for model crashes
      - Performance metrics: latency P50/P95/P99, throughput
    Deliverable: logging_config.py + dashboards
    Owner: Backend Engineer + MLOps
    ETA: 2 days

□ 4.5 MODEL RETRAINING PIPELINE
    Automated pipeline triggered by:
      - Schedule: monthly retraining
      - Event: drift detection alert
      - Manual: new labeled data batch > 500 images
    Stages:
      1. Data validation (schema, quality checks)
      2. Training (with early stopping + cross-validation)
      3. Evaluation (holdout test + regression tests)
      4. Human review (if metrics pass, promote to staging)
      5. A/B test (staging → production)
    Tool: Airflow, Prefect, or GitHub Actions + self-hosted runner
    Deliverable: retrain_pipeline.yaml
    Owner: MLOps Engineer
    ETA: 4 days

═══════════════════════════════════════════════════════════════════════════════
PHASE 5: REGULATORY & COMPLIANCE (Week 5-6)
═══════════════════════════════════════════════════════════════════════════════

✓ 5.1 MODEL DOCUMENTATION (MODEL CARD) [COMPLETED]
    Result: docs/model_card.md updated to V4 with full metrics and evolution history ✓

□ 5.2 RISK ASSESSMENT (ISO 14971 for Medical Devices)
    If classified as medical device software (SaMD):
      - Hazard analysis: false negative → incorrect CFU → wrong treatment
      - Risk control: human-in-the-loop mandatory
      - Residual risk acceptance criteria
    Deliverable: risk_assessment_report.md
    Owner: Quality Assurance + Regulatory Affairs
    ETA: 3 days

□ 5.3 CLINICAL VALIDATION (MINI-STUDY)
    Design:
      - 3 lab technicians count 100 plates manually (ground truth)
      - Same 100 plates processed by AI
      - Calculate: agreement rate, Cohen's kappa, Bland-Altman plot
    Success criteria:
      - Colony count agreement within ±10% for >90% of plates
      - Cohen's kappa > 0.8 (almost perfect agreement)
    Deliverable: clinical_validation_report.pdf
    Owner: Domain Expert + Statistician
    ETA: 7 days (depends on lab availability)

□ 5.4 AUDIT TRAIL
    Every prediction must be traceable:
      - Model version used
      - Input image checksum (SHA-256)
      - Timestamp + user ID
      - Prediction + confidence scores
      - User correction (if any)
    Retention: 7 years (healthcare standard)
    Deliverable: audit_schema.sql + data retention policy
    Owner: Backend Engineer + Compliance Officer
    ETA: 2 days

═══════════════════════════════════════════════════════════════════════════════
PHASE 6: DEPLOYMENT ARCHITECTURE (Week 6-7)
═══════════════════════════════════════════════════════════════════════════════

□ 6.1 MODEL SERVING OPTIMIZATION
    Current: Gradio app loads model in-process
    Production architecture options:
      a) Triton Inference Server (NVIDIA) — optimized GPU batching
      b) TorchServe — AWS standard, easy A/B testing
      c) FastAPI + ONNX Runtime — lightweight, CPU fallback
    Target: <100ms inference per image (currently ~8ms, but no batching)
    Deliverable: serving/Dockerfile + docker-compose.yml
    Owner: MLOps Engineer + Backend Engineer
    ETA: 3 days

□ 6.2 REDUNDANCY & FAILOVER
    Action:
      - Run 2+ model instances behind load balancer
      - Fallback to previous model version if new model errors > 1%
      - Health check endpoint: /health returns model status
    Deliverable: k8s deployment manifest or docker-compose
    Owner: DevOps Engineer
    ETA: 2 days

□ 6.3 API GATEWAY & RATE LIMITING
    Action:
      - Implement API key authentication
      - Rate limiting: 100 req/min per user (prevent abuse)
      - Request validation: image size, format, max dimensions
      - Response caching for identical inputs (idempotent)
    Deliverable: nginx/api-gateway.conf or Kong config
    Owner: Backend Engineer
    ETA: 2 days

□ 6.4 BACKUP & DISASTER RECOVERY
    Action:
      - Daily backup of model weights + training data
      - Cross-region storage (cloud bucket replication)
      - RTO < 1 hour, RPO < 24 hours
    Deliverable: backup_policy.md + automated scripts
    Owner: DevOps Engineer
    ETA: 1 day

═══════════════════════════════════════════════════════════════════════════════
PHASE 7: HUMAN-IN-THE-LOOP (HITL) DESIGN (Week 7-8)
═══════════════════════════════════════════════════════════════════════════════

□ 7.1 FEEDBACK MECHANISM UI
    Gradio app enhancements:
      - "Edit Detection" button: user can add/remove bounding boxes
      - "Correct Count" input: user enters manual count
      - "Flag Image" button: mark for review / retraining
      - Confidence indicator: red (<0.5), yellow (0.5-0.7), green (>0.7)
    Deliverable: Updated gradio_app.py + feedback schema
    Owner: Frontend/ML Engineer
    ETA: 3 days

□ 7.2 ACTIVE LEARNING PIPELINE
    Action:
      - Weekly: collect images with lowest confidence / highest user correction
      - Send to annotation queue (Amazon SageMaker Ground Truth or Label Studio)
      - Threshold: flag images where |AI_count - User_count| > 10%
      - Batch size: 200 images/week for retraining
    Deliverable: active_learning_pipeline.py
    Owner: ML Engineer
    ETA: 3 days

□ 7.3 EXPLAINABILITY FEATURES
    Action:
      - Grad-CAM heatmap overlay on detected colonies
      - Per-detection confidence tooltip
      - "Why this count?" explanation panel
    Tool: Eigen-CAM (fast, no backward pass needed)
    Deliverable: explainability module
    Owner: ML Engineer
    ETA: 2 days

═══════════════════════════════════════════════════════════════════════════════
GO/NO-GO CHECKLIST (Before Production Deploy)
═══════════════════════════════════════════════════════════════════════════════

✓ Colony mAP50 ≥ 0.75 on stratified validation set — ACHIEVED: 0.9145
□ Colony mAP50 ≥ 0.70 on holdout test set
✓ Per-class precision & recall documented — V4: P=0.9235, R=0.8731
□ Clinical validation study completed (n≥100, kappa≥0.8)
□ Unit tests passing (coverage >80%)
□ Integration tests passing (end-to-end inference)
□ Regression tests: no class drops >5% from baseline
□ A/B test protocol approved by product team
□ Model card completed and reviewed
□ Risk assessment signed off by QA/regulatory
□ Audit trail implemented and tested
□ Drift detection + alerting configured
□ Backup/DR tested (simulated failure + recovery)
□ HITL feedback loop operational
□ Runbook for on-call engineer documented

═══════════════════════════════════════════════════════════════════════════════
ESTIMATED TIMELINE
═══════════════════════════════════════════════════════════════════════════════

Phase 1 (Data):        Week 1-2  ━━━━━━━━━━━━━━━━━━━━
Phase 2 (Model):       Week 2-3  ━━━━━━━━━━━━━━━━━━━━
Phase 3 (Testing):     Week 3-4  ━━━━━━━━━━━━━━━━━━━━
Phase 4 (MLOps):       Week 4-5  ━━━━━━━━━━━━━━━━━━━━
Phase 5 (Compliance):  Week 5-6  ━━━━━━━━━━━━━━━━━━━━
Phase 6 (Deploy):      Week 6-7  ━━━━━━━━━━━━━━━━━━━━
Phase 7 (HITL):        Week 7-8  ━━━━━━━━━━━━━━━━━━━━

TOTAL ESTIMATED: 8 weeks (2 months) with 2-3 engineers
CRITICAL PATH: Phase 1 → Phase 2 → Phase 3 → Phase 5 (Go/No-Go gate)

═══════════════════════════════════════════════════════════════════════════════
IMMEDIATE ACTION ITEMS (This Week)
═══════════════════════════════════════════════════════════════════════════════

1. [TODAY] Create stratified validation set (1.1)
2. [TODAY] Run architecture benchmark: YOLOv8m vs YOLOv8s (2.1)
3. [TOMORROW] Implement focal loss training (2.2)
4. [THIS WEEK] Set up MLflow model registry (4.1)
5. [THIS WEEK] Write first unit tests (3.1)

═══════════════════════════════════════════════════════════════════════════════
BUDGET / RESOURCE ESTIMATES
═══════════════════════════════════════════════════════════════════════════════

Compute:
  - GPU training (A4000 x2): included (existing)
  - Cloud inference (optional): ~$200/month for 2x T4 instances

Storage:
  - Dataset versioning (DVC + S3): ~$50/month for 500GB

Tools (open-source):
  - MLflow, DVC, Prefect, Evidently, Label Studio: $0

Personnel:
  - 1 ML Engineer (full-time, 8 weeks)
  - 1 MLOps Engineer (part-time, 4 weeks)
  - 1 Domain Expert (microbiologist, 20% time, 4 weeks)
  - 1 QA/Regulatory (part-time, 2 weeks)
