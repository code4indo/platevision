import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/models/detection_result.dart';
import 'package:platevision_ai/providers/analysis_provider.dart';
import 'package:provider/provider.dart';

// ════════════════════════════════════════════════════════════════
// DETECTION OVERLAY PAINTER — Draws bounding boxes & + markers
// ════════════════════════════════════════════════════════════════

class DetectionOverlayPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final int imageWidth;
  final int imageHeight;
  final bool showBoundingBoxes;
  final bool showCrosshairs;
  final bool showLabels;

  DetectionOverlayPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    this.showBoundingBoxes = true,
    this.showCrosshairs = true,
    this.showLabels = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty || imageWidth <= 0 || imageHeight <= 0) return;

    // ── Calculate BoxFit.contain transform ──
    final containerAspect = size.width / size.height;
    final imageAspect = imageWidth / imageHeight;

    double scale, offsetX, offsetY;
    if (containerAspect > imageAspect) {
      // Container is wider — image fits by height
      scale = size.height / imageHeight;
      offsetX = (size.width - imageWidth * scale) / 2;
      offsetY = 0;
    } else {
      // Container is taller — image fits by width
      scale = size.width / imageWidth;
      offsetX = 0;
      offsetY = (size.height - imageHeight * scale) / 2;
    }

    // ── Draw each detection ──
    for (int i = 0; i < detections.length; i++) {
      final det = detections[i];
      final color = det.classColor;

      // Transform bounding box to display coordinates
      final displayRect = Rect.fromLTRB(
        det.boundingBox.left * scale + offsetX,
        det.boundingBox.top * scale + offsetY,
        det.boundingBox.right * scale + offsetX,
        det.boundingBox.bottom * scale + offsetY,
      );

      // ── Draw bounding box ──
      if (showBoundingBoxes) {
        final boxPaint = Paint()
          ..color = color.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRect(displayRect, boxPaint);

        // Semi-transparent fill
        final fillPaint = Paint()
          ..color = color.withOpacity(0.15)
          ..style = PaintingStyle.fill;
        canvas.drawRect(displayRect, fillPaint);
      }

      // ── Draw + crosshair at center ──
      if (showCrosshairs) {
        final center = displayRect.center;
        final crossSize = min(displayRect.width, displayRect.height) * 0.3;
        final clampedCross = max(4.0, min(crossSize, 14.0));

        final crossPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;

        // Horizontal line
        canvas.drawLine(
          Offset(center.dx - clampedCross, center.dy),
          Offset(center.dx + clampedCross, center.dy),
          crossPaint,
        );
        // Vertical line
        canvas.drawLine(
          Offset(center.dx, center.dy - clampedCross),
          Offset(center.dx, center.dy + clampedCross),
          crossPaint,
        );

        // Center dot
        final dotPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 2.0, dotPaint);
      }

      // ── Draw label (class + confidence) ──
      if (showLabels) {
        final label = '${det.className.toUpperCase()} ${(det.confidence * 100).toStringAsFixed(0)}%';
        final textStyle = ui.TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: ui.FontWeight.w600,
          letterSpacing: 0.3,
        );
        final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 9))
          ..pushStyle(textStyle)
          ..addText(label);
        final paragraph = paragraphBuilder.build()
          // FIX: constraint sesuai lebar canvas, bukan nilai besar 10000
          ..layout(ui.ParagraphConstraints(width: size.width));

        const labelHeight = 14.0;
        // FIX: longestLine = lebar teks aktual yg dirender
        // paragraph.width dulu = 10000 (nilai constraint) → sebabkan garis panjang
        final labelWidth = paragraph.longestLine + 8;

        // FIX: clamp posisi X agar label tidak keluar batas kanan canvas
        final labelX = displayRect.left.clamp(0.0, max(0.0, size.width - labelWidth)).toDouble();

        final labelBg = Rect.fromLTWH(
          labelX,
          displayRect.top - labelHeight,
          labelWidth,
          labelHeight,
        );

        // Only draw label if it fits above the box
        if (labelBg.top >= 0) {
          final bgPaint = Paint()
            ..color = color.withOpacity(0.85)
            ..style = PaintingStyle.fill;
          canvas.drawRect(labelBg, bgPaint);
          canvas.drawParagraph(paragraph, Offset(labelBg.left + 4, labelBg.top + 2.5));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}

// ════════════════════════════════════════════════════════════════
// ANALYSIS RESULT SCREEN — Laporan Hasil Analisis
// ════════════════════════════════════════════════════════════════

class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({super.key});

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  bool _showOriginal = false;
  String _classFilter = 'all';

  // ── Zoom / pan controller ──────────────────────────────────────────────
  final TransformationController _zoomController = TransformationController();
  static const double _minScale = 1.0;
  static const double _maxScale = 8.0;

  void _resetZoom() => _zoomController.value = Matrix4.identity();

  void _zoomBy(double factor) {
    final cur = _zoomController.value.getMaxScaleOnAxis();
    final next = (cur * factor).clamp(_minScale, _maxScale);
    if (next == cur) return;
    _zoomController.value = Matrix4.identity()..scale(next);
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // If accessed directly via URL (deep link) and no current result,
    // try loading the most recent analysis from history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ap = context.read<AnalysisProvider>();
      if (ap.currentResult == null && ap.history.isNotEmpty) {
        ap.loadFromHistory(ap.history.first);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AnalysisProvider>();
    final result = ap.currentResult;
    final imageBytes = ap.currentImageBytes;

    if (result == null) {
      return Scaffold(
        backgroundColor: AppColors.bgScaffold,
        appBar: AppBar(
          backgroundColor: AppColors.bgSecondary,
          title: Text('Analysis Result', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.of(context).pop()),
        ),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('NO RESULT', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text('Run an analysis first from the Capture page', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ])),
      );
    }

    final detections = _getFilteredDetections(result);
    final colonyCount = detections.where((d) => d.className == 'colony').length;
    final severity = _getSeverity(colonyCount);
    final severityColor = _getSeverityColor(colonyCount);

    return Scaffold(
      backgroundColor: AppColors.bgScaffold,
      appBar: _buildAppBar(result, severityColor),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── LEFT: Gambar Hasil Identifikasi (Marked Image) ──
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gambar utama dengan overlay deteksi
                  Expanded(
                    child: _buildDetectionImage(result, detections, imageBytes),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Class filter bar
                  _buildClassFilterBar(result),
                ],
              ),
            ),
          ),
          // ── RIGHT: Laporan Hasil Analisis ──
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, AppSpacing.md, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Colony count hero
                  _buildColonyCountHero(colonyCount, severity, severityColor, result),
                  const SizedBox(height: AppSpacing.md),
                  // Detection breakdown
                  _buildDetectionBreakdown(result, detections),
                  const SizedBox(height: AppSpacing.md),
                  // Before/After toggle info
                  _buildViewToggleInfo(),
                  const SizedBox(height: AppSpacing.md),
                  // Image & model details
                  _buildDetailsCard(result),
                  const SizedBox(height: AppSpacing.md),
                  // Sample metadata
                  _buildSampleMetadata(result),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar(AnalysisResult result, Color severityColor) {
    return AppBar(
      backgroundColor: AppColors.bgSecondary,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: severityColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('LAPORAN HASIL ANALISIS', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 1)),
      ]),
      actions: [
        // Before/After toggle
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _showOriginal = !_showOriginal),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _showOriginal ? AppColors.accentPrimary.withOpacity(0.15) : AppColors.bgInput,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _showOriginal ? AppColors.accentPrimary.withOpacity(0.5) : AppColors.borderSubtle),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_showOriginal ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 14, color: _showOriginal ? AppColors.accentPrimary : AppColors.textTertiary),
                const SizedBox(width: 5),
                Text(_showOriginal ? 'ORIGINAL' : 'MARKED', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: _showOriginal ? AppColors.accentPrimary : AppColors.textTertiary, letterSpacing: 1)),
              ]),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.borderSubtle),
      ),
    );
  }

  // ============================================================
  // GAMBAR HASIL IDENTIFIKASI — Main detection image
  // ============================================================

  Widget _buildDetectionImage(AnalysisResult result, List<DetectionResult> detections, Uint8List? imageBytes) {
    final hasImage = imageBytes != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: _showOriginal ? AppColors.borderSubtle : AppColors.accentPrimary.withOpacity(0.5),
          width: _showOriginal ? 1 : 2,
        ),
        boxShadow: [
          if (!_showOriginal)
            BoxShadow(color: AppColors.accentPrimary.withOpacity(0.08), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(AppSpacing.radiusMd), topRight: Radius.circular(AppSpacing.radiusMd)),
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(children: [
              Icon(_showOriginal ? Icons.image_outlined : Icons.auto_fix_high_rounded, size: 16,
                color: _showOriginal ? AppColors.textTertiary : AppColors.accentPrimary),
              const SizedBox(width: 8),
              Text(
                _showOriginal ? 'ORIGINAL IMAGE' : 'GAMBAR HASIL IDENTIFIKASI',
                style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _showOriginal ? AppColors.textTertiary : AppColors.accentPrimary, letterSpacing: 1.5),
              ),
              const Spacer(),
              if (!_showOriginal) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.colonyColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.colonyColor.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_circle_outline_rounded, size: 12, color: AppColors.colonyColor),
                    const SizedBox(width: 4),
                    Text('${detections.length}', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.colonyColor)),
                    const SizedBox(width: 2),
                    Text('detected', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w500, color: AppColors.colonyColor.withOpacity(0.8))),
                  ]),
                ),
              ],
            ]),
          ),
          // Image area — ACTUAL image with detection overlay + zoom/pan
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(AppSpacing.radiusMd), bottomRight: Radius.circular(AppSpacing.radiusMd)),
              child: hasImage
                ? Stack(children: [
                    // ─── InteractiveViewer: zoom scroll mouse + pinch touch ───────
                    Positioned.fill(
                      child: InteractiveViewer(
                        transformationController: _zoomController,
                        minScale: _minScale,
                        maxScale: _maxScale,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        child: Stack(fit: StackFit.expand, children: [
                          // ═══ GAMBAR ASLI ═══
                          Image.memory(imageBytes!, fit: BoxFit.contain),

                          // ═══ DETECTION OVERLAY — crosshair + markers ═══
                          if (!_showOriginal && result.imageWidth > 0 && result.imageHeight > 0)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: DetectionOverlayPainter(
                                  detections: detections,
                                  imageWidth: result.imageWidth,
                                  imageHeight: result.imageHeight,
                                  showBoundingBoxes: false,
                                  showCrosshairs: true,
                                  showLabels: false,
                                ),
                              ),
                            ),

                          // ═══ HOVER TOOLTIP — confidence % saat mouse hover ═══
                          if (!_showOriginal && result.imageWidth > 0 && result.imageHeight > 0)
                            Positioned.fill(
                              child: _DetectionTooltipLayer(
                                detections: detections,
                                imageWidth: result.imageWidth,
                                imageHeight: result.imageHeight,
                              ),
                            ),
                        ]),
                      ),
                    ),

                    // ─── Zoom controls (top-right) ────────────────────────────────
                    Positioned(
                      top: 8, right: 8,
                      child: _buildZoomControls(),
                    ),

                    // ═══ Legend badge (bottom-left) ═══
                    if (!_showOriginal && detections.isNotEmpty)
                      Positioned(bottom: 8, left: 8, child: _buildLegendBadge(detections)),
                  ])
                : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.broken_image_outlined, size: 40, color: AppColors.textMuted),
                    const SizedBox(height: 8),
                    Text('Image data not available', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text('Re-run analysis to view detection result', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted.withOpacity(0.7))),
                    const SizedBox(height: 8),
                    Text('Result: ${result != null ? "OK" : "null"} | Image: ${imageBytes != null ? "${imageBytes!.length}B" : "null"}', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: AppColors.textMuted.withOpacity(0.5))),
                  ])),
            ),
          ),
        ],
      ),
    );
  }

  /// Tombol zoom in / zoom out / reset di sudut gambar
  Widget _buildZoomControls() {
    return AnimatedBuilder(
      animation: _zoomController,
      builder: (context, _) {
        final scale = _zoomController.value.getMaxScaleOnAxis();
        final atMin = scale <= _minScale;
        final atMax = scale >= _maxScale;
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Zoom in
            _zoomBtn(
              icon: Icons.add_rounded,
              tooltip: 'Zoom in',
              enabled: !atMax,
              onTap: () => _zoomBy(1.0 + 0.3),
            ),
            Container(height: 1, color: Colors.white.withOpacity(0.1)),
            // Persentase zoom — tap untuk reset
            Tooltip(
              message: 'Reset zoom',
              child: GestureDetector(
                onTap: _resetZoom,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Text(
                    '${(scale * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Container(height: 1, color: Colors.white.withOpacity(0.1)),
            // Zoom out
            _zoomBtn(
              icon: Icons.remove_rounded,
              tooltip: 'Zoom out',
              enabled: !atMin,
              onTap: () => _zoomBy(1.0 / 1.3),
            ),
          ]),
        );
      },
    );
  }

  Widget _zoomBtn({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16,
            color: enabled ? Colors.white : Colors.white24),
        ),
      ),
    );
  }

  /// Legend badge showing color coding
  Widget _buildLegendBadge(List<DetectionResult> detections) {
    final classSet = <String>{};
    for (final d in detections) {
      classSet.add(d.className);
    }
    final classes = classSet.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LEGEND', style: GoogleFonts.jetBrainsMono(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1)),
          const SizedBox(height: 4),
          ...classes.map((cls) {
            final color = AppColors.getDetectionColor(cls);
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text(cls.toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================
  // CLASS FILTER BAR
  // ============================================================

  Widget _buildClassFilterBar(AnalysisResult result) {
    final classCounts = result.classCounts;
    final classes = ['all', ...classCounts.keys.toList()];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(children: [
        Icon(Icons.filter_list_rounded, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text('FILTER:', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: classes.map((cls) {
              final isSelected = _classFilter == cls;
              final color = cls == 'all' ? AppColors.accentPrimary : AppColors.getDetectionColor(cls);
              final count = cls == 'all' ? result.totalDetections : (classCounts[cls] ?? 0);
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _classFilter = cls),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.15) : AppColors.bgInput,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isSelected ? color.withOpacity(0.6) : AppColors.borderSubtle, width: isSelected ? 1.5 : 0.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (cls != 'all')
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                      if (cls != 'all') const SizedBox(width: 4),
                      Text(cls.toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? color : AppColors.textMuted, letterSpacing: 0.5)),
                      const SizedBox(width: 3),
                      Text('$count', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w800, color: isSelected ? color : AppColors.textTertiary)),
                    ]),
                  ),
                ),
              );
            }).toList()),
          ),
        ),
      ]),
    );
  }

  // ============================================================
  // COLONY COUNT HERO
  // ============================================================

  Widget _buildColonyCountHero(int colonyCount, String severity, Color severityColor, AnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: severityColor.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: severityColor.withOpacity(0.08), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: severityColor.withOpacity(0.4)),
            ),
            child: Text(severity, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: severityColor, letterSpacing: 2)),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$colonyCount', style: GoogleFonts.jetBrainsMono(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.0)),
            Text('Colony Count (CFU)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ]),
        const SizedBox(height: 12),
        // SNI/ISO validity
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: severityColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Icon(Icons.verified_rounded, size: 14, color: severityColor),
            const SizedBox(width: 6),
            Text('SNI/ISO Validity: ', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
            Text(_getValidityStatus(colonyCount), style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: severityColor)),
          ]),
        ),
      ]),
    );
  }

  // ============================================================
  // DETECTION BREAKDOWN
  // ============================================================

  Widget _buildDetectionBreakdown(AnalysisResult result, List<DetectionResult> detections) {
    final classCounts = <String, int>{};
    for (final d in detections) {
      classCounts[d.className] = (classCounts[d.className] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.pie_chart_rounded, size: 14, color: AppColors.accentSecondary),
          const SizedBox(width: 6),
          Text('DETECTION BREAKDOWN', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 10),
        _buildBreakdownRow('Colony', classCounts['colony'] ?? 0, AppColors.colonyColor, detections.length),
        const SizedBox(height: 6),
        _buildBreakdownRow('Bubble', classCounts['bubble'] ?? 0, AppColors.bubbleColor, detections.length),
        const SizedBox(height: 6),
        _buildBreakdownRow('Dust', classCounts['dust'] ?? 0, AppColors.dustColor, detections.length),
        const SizedBox(height: 6),
        _buildBreakdownRow('Crack', classCounts['crack'] ?? 0, AppColors.crackColor, detections.length),
        const Divider(height: 20, color: AppColors.borderSubtle),
        _buildBreakdownRow('Total', detections.length, AppColors.textPrimary, detections.length),
      ]),
    );
  }

  Widget _buildBreakdownRow(String label, int count, Color color, int total) {
    final pct = total > 0 ? (count / total * 100) : 0.0;
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary))),
      // Progress bar
      Expanded(
        flex: 2,
        child: LayoutBuilder(builder: (context, constraints) {
          return Stack(children: [
            Container(
              height: 6,
              decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(3)),
            ),
            FractionallySizedBox(
              widthFactor: pct / 100,
              child: Container(
                height: 6,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ]);
        }),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 36, child: Text('$count', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.right)),
      const SizedBox(width: 4),
      SizedBox(width: 42, child: Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted), textAlign: TextAlign.right)),
    ]);
  }

  // ============================================================
  // VIEW TOGGLE INFO
  // ============================================================

  Widget _buildViewToggleInfo() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        border: Border.all(color: AppColors.accentPrimary.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.accentPrimary),
        const SizedBox(width: 6),
        Expanded(child: Text(
          'Tekan ORIGINAL/MARKED di toolbar atas untuk beralih antara gambar asli dan gambar hasil identifikasi',
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.accentPrimary.withOpacity(0.8)),
        )),
      ]),
    );
  }

  // ============================================================
  // DETAILS CARD
  // ============================================================

  Widget _buildDetailsCard(AnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline_rounded, size: 14, color: AppColors.info),
          const SizedBox(width: 6),
          Text('DETAILS', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 10),
        _buildDetailRow('Sample ID', result.sampleId.isNotEmpty ? result.sampleId : '--'),
        const SizedBox(height: 5),
        _buildDetailRow('Image Size', '${result.imageWidth} x ${result.imageHeight} px'),
        const SizedBox(height: 5),
        _buildDetailRow('Processing Time', '${result.processingTime.inMilliseconds} ms'),
        const SizedBox(height: 5),
        _buildDetailRow('Avg Confidence', '${(result.averageConfidence * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 5),
        _buildDetailRow('Model', result.modelVersion),
        const SizedBox(height: 5),
        _buildDetailRow('Timestamp', _formatTimestamp(result.timestamp)),
      ]),
    );
  }

  // ============================================================
  // SAMPLE METADATA
  // ============================================================

  Widget _buildSampleMetadata(AnalysisResult result) {
    final hasMetadata = result.mediaType.isNotEmpty || result.sampleType.isNotEmpty;
    if (!hasMetadata) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.assignment_outlined, size: 14, color: AppColors.info),
          const SizedBox(width: 6),
          Text('SAMPLE METADATA', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 10),
        if (result.sampleType.isNotEmpty) _buildDetailRow('Sample Type', result.sampleType),
        if (result.sampleType.isNotEmpty) const SizedBox(height: 5),
        if (result.mediaType.isNotEmpty) _buildDetailRow('Media', result.mediaType),
        if (result.mediaType.isNotEmpty) const SizedBox(height: 5),
        if (result.dilution.isNotEmpty) _buildDetailRow('Dilution', result.dilution),
        if (result.dilution.isNotEmpty) const SizedBox(height: 5),
        if (result.inoculationMethod.isNotEmpty) _buildDetailRow('Inoculation', result.inoculationMethod),
        if (result.inoculationMethod.isNotEmpty) const SizedBox(height: 5),
        if (result.inoculumVolume.isNotEmpty) _buildDetailRow('Volume', result.inoculumVolume),
        if (result.inoculumVolume.isNotEmpty) const SizedBox(height: 5),
        if (result.incubatorTemp.isNotEmpty) _buildDetailRow('Temp', result.incubatorTemp),
        if (result.incubatorTemp.isNotEmpty) const SizedBox(height: 5),
        if (result.analystName.isNotEmpty) _buildDetailRow('Analyst', result.analystName),
      ]),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
      const Spacer(),
      Flexible(child: Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
    ]);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  List<DetectionResult> _getFilteredDetections(AnalysisResult result) {
    if (_classFilter == 'all') return result.detections;
    return result.detections.where((d) => d.className == _classFilter).toList();
  }

  String _getSeverity(int count) {
    if (count > 300) return 'TNTC';
    if (count > 150) return 'TFTC';
    if (count > 30) return 'IDEAL';
    return 'LOW';
  }

  Color _getSeverityColor(int count) {
    if (count > 300) return AppColors.error;
    if (count > 150) return AppColors.warning;
    if (count > 30) return AppColors.success;
    return AppColors.info;
  }

  String _getValidityStatus(int count) {
    if (count < 30) return 'Too Few (<30)';
    if (count > 300) return 'TNTC (>300)';
    return 'Valid (30-300)';
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

// ════════════════════════════════════════════════════════════════
// DETECTION TOOLTIP LAYER
// Widget yang menempatkan hover area transparan di setiap deteksi.
// Ikut zoom/pan karena berada di dalam InteractiveViewer.
// ════════════════════════════════════════════════════════════════

class _DetectionTooltipLayer extends StatefulWidget {
  final List<DetectionResult> detections;
  final int imageWidth;
  final int imageHeight;

  const _DetectionTooltipLayer({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  State<_DetectionTooltipLayer> createState() => _DetectionTooltipLayerState();
}

class _DetectionTooltipLayerState extends State<_DetectionTooltipLayer> {
  // Index deteksi yang sedang di-hover (-1 = tidak ada)
  int _hoveredIndex = -1;

  /// Hitung transform BoxFit.contain: scale + offset
  _ImageTransform _calcTransform(BoxConstraints constraints) {
    final cw = constraints.maxWidth;
    final ch = constraints.maxHeight;
    final iw = widget.imageWidth.toDouble();
    final ih = widget.imageHeight.toDouble();
    if (iw <= 0 || ih <= 0 || cw <= 0 || ch <= 0) {
      return _ImageTransform(scale: 1, offsetX: 0, offsetY: 0);
    }
    final containerAspect = cw / ch;
    final imageAspect = iw / ih;
    double scale, offsetX, offsetY;
    if (containerAspect > imageAspect) {
      scale = ch / ih;
      offsetX = (cw - iw * scale) / 2;
      offsetY = 0;
    } else {
      scale = cw / iw;
      offsetX = 0;
      offsetY = (ch - ih * scale) / 2;
    }
    return _ImageTransform(scale: scale, offsetX: offsetX, offsetY: offsetY);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final t = _calcTransform(constraints);

      return Stack(children: [
        // Hit area transparan per deteksi
        for (int i = 0; i < widget.detections.length; i++)
          _buildHoverArea(i, t, constraints),
      ]);
    });
  }

  Widget _buildHoverArea(int i, _ImageTransform t, BoxConstraints constraints) {
    final det = widget.detections[i];
    final box = det.boundingBox;

    // Koordinat tengah marker + di screen
    final cx = box.center.dx * t.scale + t.offsetX;
    final cy = box.center.dy * t.scale + t.offsetY;

    // Hit area: minimal 28px, maksimal lebar bbox ter-scale
    final bboxW = box.width * t.scale;
    final bboxH = box.height * t.scale;
    final hitW = bboxW.clamp(28.0, 64.0);
    final hitH = bboxH.clamp(28.0, 64.0);

    final isHovered = _hoveredIndex == i;
    final color = AppColors.getDetectionColor(det.className);
    final confidence = (det.confidence * 100).toStringAsFixed(0);
    final label = '${det.className.toUpperCase()}  $confidence%';

    return Positioned(
      left: cx - hitW / 2,
      top: cy - hitH / 2,
      width: hitW,
      height: hitH,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredIndex = i),
        onExit: (_) => setState(() => _hoveredIndex = -1),
        child: Stack(clipBehavior: Clip.none, children: [
          // Area transparan untuk deteksi hover
          Container(color: Colors.transparent),

          // Tooltip bubble — muncul saat hover
          if (isHovered)
            Positioned(
              // Tampil di atas marker, geser agar tidak terpotong kanan
              bottom: hitH / 2 + 6,
              left: _tooltipLeft(cx, hitW, label, constraints.maxWidth),
              child: _TooltipBubble(label: label, color: color),
            ),
        ]),
      ),
    );
  }

  /// Hitung posisi X tooltip agar tidak keluar batas kanan canvas
  double _tooltipLeft(double cx, double hitW, String label, double canvasW) {
    // Estimasi lebar tooltip: ~7px per karakter + 16px padding
    final estWidth = label.length * 7.0 + 16;
    final rawLeft = -estWidth / 2 + hitW / 2;
    // Clamp agar tidak keluar canvas
    final absLeft = cx - hitW / 2 + rawLeft;
    if (absLeft + estWidth > canvasW) {
      return canvasW - (cx - hitW / 2) - estWidth - 4;
    }
    if (absLeft < 0) return -cx + hitW / 2 + 4;
    return rawLeft;
  }
}

// Nilai transform BoxFit.contain
class _ImageTransform {
  final double scale, offsetX, offsetY;
  const _ImageTransform({required this.scale, required this.offsetX, required this.offsetY});
}

// Bubble tooltip dengan styling lab
class _TooltipBubble extends StatelessWidget {
  final String label;
  final Color color;
  const _TooltipBubble({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          height: 1.2,
        ),
      ),
    );
  }
}
