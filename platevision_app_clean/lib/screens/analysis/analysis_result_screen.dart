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
// DETECTION OVERLAY PAINTER — V5 Clean Professional Design
// Numbered markers + subtle boxes + hover highlight
// ════════════════════════════════════════════════════════════════

class DetectionOverlayPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final int imageWidth;
  final int imageHeight;
  final int hoveredIndex;

  DetectionOverlayPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    this.hoveredIndex = -1,
  });

  static ({double scale, double ox, double oy}) calcTransform(Size canvasSize, int imgW, int imgH) {
    final ca = canvasSize.width / canvasSize.height;
    final ia = imgW / imgH;
    double s, ox, oy;
    if (ca > ia) {
      s = canvasSize.height / imgH;
      ox = (canvasSize.width - imgW * s) / 2;
      oy = 0;
    } else {
      s = canvasSize.width / imgW;
      ox = 0;
      oy = (canvasSize.height - imgH * s) / 2;
    }
    return (scale: s, ox: ox, oy: oy);
  }

  static Rect getDisplayRect(DetectionResult det, Size canvasSize, int imgW, int imgH) {
    final t = calcTransform(canvasSize, imgW, imgH);
    return Rect.fromLTRB(
      det.boundingBox.left * t.scale + t.ox,
      det.boundingBox.top * t.scale + t.oy,
      det.boundingBox.right * t.scale + t.ox,
      det.boundingBox.bottom * t.scale + t.oy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty || imageWidth <= 0 || imageHeight <= 0) return;
    final t = calcTransform(size, imageWidth, imageHeight);

    // ── Pass 1: Draw all non-hovered boxes (subtle) ──
    for (int i = 0; i < detections.length; i++) {
      if (i == hoveredIndex) continue;
      final det = detections[i];
      final color = det.classColor;
      final dr = Rect.fromLTRB(
        det.boundingBox.left * t.scale + t.ox,
        det.boundingBox.top * t.scale + t.oy,
        det.boundingBox.right * t.scale + t.ox,
        det.boundingBox.bottom * t.scale + t.oy,
      );

      // Subtle fill
      canvas.drawRect(dr, Paint()..color = color.withOpacity(0.06)..style = PaintingStyle.fill);
      // Thin border
      canvas.drawRect(dr, Paint()..color = color.withOpacity(0.45)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }

    // ── Pass 2: Draw hovered box (prominent) ──
    if (hoveredIndex >= 0 && hoveredIndex < detections.length) {
      final det = detections[hoveredIndex];
      final color = det.classColor;
      final dr = Rect.fromLTRB(
        det.boundingBox.left * t.scale + t.ox,
        det.boundingBox.top * t.scale + t.oy,
        det.boundingBox.right * t.scale + t.ox,
        det.boundingBox.bottom * t.scale + t.oy,
      );

      // Glow
      canvas.drawRect(dr.inflate(6), Paint()..color = color.withOpacity(0.08)..style = PaintingStyle.fill..maskFilter = MaskFilter.blur(BlurStyle.normal, 12));
      // Fill
      canvas.drawRect(dr, Paint()..color = color.withOpacity(0.15)..style = PaintingStyle.fill);
      // Stroke
      canvas.drawRect(dr, Paint()..color = color.withOpacity(0.95)..style = PaintingStyle.stroke..strokeWidth = 2.5);

      // Corner accents (L-shaped corners for precision look)
      final cL = max(10.0, min(min(dr.width, dr.height) * 0.2, 24.0));
      final cp = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.0..strokeCap = StrokeCap.round;
      // Top-left
      canvas.drawLine(Offset(dr.left, dr.top + cL), Offset(dr.left, dr.top), cp);
      canvas.drawLine(Offset(dr.left, dr.top), Offset(dr.left + cL, dr.top), cp);
      // Top-right
      canvas.drawLine(Offset(dr.right - cL, dr.top), Offset(dr.right, dr.top), cp);
      canvas.drawLine(Offset(dr.right, dr.top), Offset(dr.right, dr.top + cL), cp);
      // Bottom-left
      canvas.drawLine(Offset(dr.left, dr.bottom - cL), Offset(dr.left, dr.bottom), cp);
      canvas.drawLine(Offset(dr.left, dr.bottom), Offset(dr.left + cL, dr.bottom), cp);
      // Bottom-right
      canvas.drawLine(Offset(dr.right - cL, dr.bottom), Offset(dr.right, dr.bottom), cp);
      canvas.drawLine(Offset(dr.right, dr.bottom - cL), Offset(dr.right, dr.bottom), cp);

      // Label pill above box
      final label = '${det.className.toUpperCase()}  ${(det.confidence * 100).toStringAsFixed(0)}%';
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 11))
        ..pushStyle(ui.TextStyle(color: Colors.white, fontSize: 11, fontWeight: ui.FontWeight.w700))
        ..addText(label);
      final p = pb.build()..layout(ui.ParagraphConstraints(width: double.infinity));
      final lw = p.maxIntrinsicWidth + 20.0;
      final lh = 24.0;
      double lx = dr.left;
      double ly = dr.top - lh - 6;
      if (ly < 0) ly = dr.top + 4;
      // Clamp label within canvas
      if (lx + lw > size.width) lx = size.width - lw - 4;
      if (lx < 4) lx = 4;

      // Pill background
      final pillRect = RRect.fromRectAndRadius(Rect.fromLTWH(lx, ly, lw, lh), Radius.circular(6));
      canvas.drawRRect(pillRect, Paint()..color = color..style = PaintingStyle.fill);
      // Pill subtle inner border
      canvas.drawRRect(pillRect, Paint()..color = Colors.white.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 0.5);
      // Label text
      canvas.drawParagraph(p, Offset(lx + 10, ly + 5));

      // Small triangle pointer from pill to box
      final triCx = dr.left + min(20.0, dr.width / 2);
      final triY = ly + lh;
      if (ly < dr.top) {
        // Pill above box
        final tp = Path();
        tp.moveTo(triCx - 5, triY);
        tp.lineTo(triCx, triY + 5);
        tp.lineTo(triCx + 5, triY);
        tp.close();
        canvas.drawPath(tp, Paint()..color = color..style = PaintingStyle.fill);
      }
    }

    // ── Pass 3: Numbered markers on all detections ──
    for (int i = 0; i < detections.length; i++) {
      final det = detections[i];
      final color = det.classColor;
      final isH = (i == hoveredIndex);
      final dr = Rect.fromLTRB(
        det.boundingBox.left * t.scale + t.ox,
        det.boundingBox.top * t.scale + t.oy,
        det.boundingBox.right * t.scale + t.ox,
        det.boundingBox.bottom * t.scale + t.oy,
      );

      final c = dr.center;

      if (isH) {
        // Hovered: larger dot with ring
        canvas.drawCircle(c, 10, Paint()..color = color.withOpacity(0.25)..style = PaintingStyle.fill..maskFilter = MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawCircle(c, 8, Paint()..color = color..style = PaintingStyle.fill);
        canvas.drawCircle(c, 8, Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      } else {
        // Non-hovered: small solid dot
        canvas.drawCircle(c, 5, Paint()..color = color.withOpacity(0.85)..style = PaintingStyle.fill);
        canvas.drawCircle(c, 5, Paint()..color = Colors.white.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      }

      // Number text inside marker
      final numStr = '${i + 1}';
      final fontSize = isH ? 9.0 : 7.0;
      final npb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: fontSize))
        ..pushStyle(ui.TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: ui.FontWeight.w800))
        ..addText(numStr);
      final np = npb.build()..layout(ui.ParagraphConstraints(width: 30));
      canvas.drawParagraph(np, Offset(c.dx - np.maxIntrinsicWidth / 2, c.dy - np.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter old) => old.hoveredIndex != hoveredIndex || old.detections != detections;
}

// ════════════════════════════════════════════════════════════════
// INTERACTIVE DETECTION IMAGE — V5 Clean Design
// ════════════════════════════════════════════════════════════════

class InteractiveDetectionImage extends StatefulWidget {
  final Uint8List imageBytes;
  final AnalysisResult result;
  final List<DetectionResult> detections;
  final bool showOriginal;
  final ValueChanged<int> onHoverChanged;

  const InteractiveDetectionImage({
    super.key,
    required this.imageBytes,
    required this.result,
    required this.detections,
    required this.showOriginal,
    required this.onHoverChanged,
  });

  @override
  State<InteractiveDetectionImage> createState() => _InteractiveDetectionImageState();
}

class _InteractiveDetectionImageState extends State<InteractiveDetectionImage> {
  int _hoveredIndex = -1;

  void _setHovered(int idx) {
    if (idx != _hoveredIndex) {
      _hoveredIndex = idx;
      widget.onHoverChanged(idx);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final canvasSize = constraints.biggest;
      final imgW = widget.result.imageWidth;
      final imgH = widget.result.imageHeight;

      // Build positioned hit area buttons for each detection
      final hitAreas = <Widget>[];
      if (!widget.showOriginal && imgW > 0 && imgH > 0) {
        for (int i = 0; i < widget.detections.length; i++) {
          final dr = DetectionOverlayPainter.getDisplayRect(
            widget.detections[i], canvasSize, imgW, imgH,
          );
          final color = widget.detections[i].classColor;
          final isH = (i == _hoveredIndex);

          hitAreas.add(
            Positioned(
              left: max(0, dr.left - 4),
              top: max(0, dr.top - 4),
              width: max(dr.width + 8, 30),
              height: max(dr.height + 8, 30),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => _setHovered(i),
                onExit: (_) => _setHovered(-1),
                child: GestureDetector(
                  onTap: () => _setHovered(i == _hoveredIndex ? -1 : i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isH
                          ? color.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }

      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // ═══ GAMBAR ASLI ═══
          Image.memory(widget.imageBytes, fit: BoxFit.contain),

          // ═══ DETECTION OVERLAY via CustomPaint ═══
          if (!widget.showOriginal && imgW > 0)
            Positioned.fill(
              child: CustomPaint(
                painter: DetectionOverlayPainter(
                  detections: widget.detections,
                  imageWidth: imgW,
                  imageHeight: imgH,
                  hoveredIndex: _hoveredIndex,
                ),
              ),
            ),

          // ═══ HIT AREAS ═══
          ...hitAreas,

          // ═══ DETECTION COUNT BADGE (top-right) ═══
          if (!widget.showOriginal && widget.detections.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: _buildCountBadge(),
            ),

          // ═══ LEGEND (bottom-right) ═══
          if (!widget.showOriginal && widget.detections.isNotEmpty)
            Positioned(
              bottom: 8,
              right: 8,
              child: _buildLegendBadge(),
            ),
        ],
      );
    });
  }

  Widget _buildCountBadge() {
    final classCounts = <String, int>{};
    for (final d in widget.detections) { classCounts[d.className] = (classCounts[d.className] ?? 0) + 1; }
    final colonyCount = classCounts['colony'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle.withOpacity(0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_fix_high_rounded, size: 14, color: AppColors.accentPrimary),
          const SizedBox(width: 6),
          Text('${widget.detections.length}', style: GoogleFonts.jetBrainsMono(
            fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          )),
          const SizedBox(width: 4),
          Text('detected', style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textTertiary,
          )),
          if (colonyCount > 0) ...[
            const SizedBox(width: 10),
            Container(width: 1, height: 14, color: AppColors.borderSubtle),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.colonyColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.colonyColor.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.colonyColor, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('$colonyCount', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.colonyColor)),
                const SizedBox(width: 2),
                Text('colony', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w500, color: AppColors.colonyColor.withOpacity(0.8))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendBadge() {
    final classSet = <String>{};
    for (final d in widget.detections) { classSet.add(d.className); }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle.withOpacity(0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LEGEND', style: GoogleFonts.jetBrainsMono(
            fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5,
          )),
          const SizedBox(height: 6),
          ...classSet.map((cls) {
            final color = AppColors.getDetectionColor(cls);
            final count = widget.detections.where((d) => d.className == cls).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(cls.toUpperCase(), style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                  )),
                  const SizedBox(width: 6),
                  Text('x$count', style: GoogleFonts.jetBrainsMono(
                    fontSize: 8, fontWeight: FontWeight.w500, color: AppColors.textTertiary,
                  )),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 0.5))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, size: 10, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('Hover for detail', style: GoogleFonts.inter(
                  fontSize: 8, color: AppColors.textTertiary,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ANALYSIS RESULT SCREEN
// ════════════════════════════════════════════════════════════════

class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({super.key});
  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  bool _showOriginal = false;
  String _classFilter = 'all';
  int _hoveredDetectionIndex = -1;

  // ── Zoom state ──
  final TransformationController _zoomController = TransformationController();
  double _currentZoom = 1.0;
  static const double _minZoom = 1.0;
  static const double _maxZoom = 5.0;
  static const double _zoomStep = 0.5;

  // ── Panel resize state (horizontal) ──
  double _leftPanelRatio = 0.60;
  static const double _minLeftRatio = 0.30;
  static const double _maxLeftRatio = 0.80;
  bool _isDraggingDivider = false;

  // ── Vertical resize state (image vs filter bar) ──
  double _imagePanelRatio = 0.88;
  static const double _minImageRatio = 0.50;
  static const double _maxImageRatio = 0.96;
  bool _isDraggingVDivider = false;

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _zoomController.value = Matrix4.identity();
    setState(() => _currentZoom = 1.0);
  }

  void _zoomIn() {
    final newZoom = (_currentZoom + _zoomStep).clamp(_minZoom, _maxZoom);
    if (newZoom != _currentZoom) {
      _zoomController.value = Matrix4.identity()..scale(newZoom);
      setState(() => _currentZoom = newZoom);
    }
  }

  void _zoomOut() {
    final newZoom = (_currentZoom - _zoomStep).clamp(_minZoom, _maxZoom);
    if (newZoom != _currentZoom) {
      _zoomController.value = Matrix4.identity()..scale(newZoom);
      setState(() => _currentZoom = newZoom);
    }
  }

  void _onZoomChanged(Matrix4 matrix) {
    final scale = matrix.getMaxScaleOnAxis();
    final clamped = scale.clamp(_minZoom, _maxZoom);
    if (clamped != _currentZoom) {
      setState(() => _currentZoom = clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AnalysisProvider>();
    final result = ap.currentResult;
    final imageBytes = ap.currentImageBytes;

    if (result == null) {
      return Scaffold(
        backgroundColor: AppColors.bgScaffold,
        appBar: AppBar(backgroundColor: AppColors.bgSecondary, title: Text('Analysis Result', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.of(context).pop())),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted), const SizedBox(height: 12), Text('NO RESULT', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 2))])),
      );
    }

    final detections = _getFilteredDetections(result);
    final colonyCount = detections.where((d) => d.className == 'colony').length;
    final severity = _getSeverity(colonyCount);
    final severityColor = _getSeverityColor(colonyCount);

    return Scaffold(
      backgroundColor: AppColors.bgScaffold,
      appBar: _buildAppBar(result, severityColor),
      body: LayoutBuilder(builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final dividerWidth = 10.0;
        final leftWidth = (totalWidth - dividerWidth) * _leftPanelRatio;
        final rightWidth = (totalWidth - dividerWidth) * (1 - _leftPanelRatio);

        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Left panel: Image + Filter (resizable) ──
          SizedBox(
            width: leftWidth,
            child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                flex: (_imagePanelRatio * 1000).round(),
                child: _buildDetectionImage(result, detections, imageBytes),
              ),
              _buildVerticalResizeDivider(),
              Expanded(
                flex: ((1 - _imagePanelRatio) * 1000).round(),
                child: _buildClassFilterBar(result),
              ),
            ])),
          ),

          // ── Horizontal resize divider ──
          _buildHorizontalResizeDivider(),

          // ── Right panel: Details ──
          SizedBox(
            width: rightWidth,
            child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, AppSpacing.md, AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _buildColonyCountHero(colonyCount, severity, severityColor, result),
              const SizedBox(height: AppSpacing.md),
              if (_hoveredDetectionIndex >= 0 && _hoveredDetectionIndex < detections.length) _buildHoveredInfoCard(detections[_hoveredDetectionIndex]),
              if (_hoveredDetectionIndex >= 0 && _hoveredDetectionIndex < detections.length) const SizedBox(height: AppSpacing.md),
              _buildDetectionBreakdown(result, detections), const SizedBox(height: AppSpacing.md),
              _buildViewToggleInfo(), const SizedBox(height: AppSpacing.md),
              _buildDetailsCard(result), const SizedBox(height: AppSpacing.md),
              _buildSampleMetadata(result),
            ])),
          ),
        ]);
      }),
    );
  }

  PreferredSizeWidget _buildAppBar(AnalysisResult result, Color severityColor) {
    return AppBar(backgroundColor: AppColors.bgSecondary, elevation: 0,
      leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.of(context).pop()),
      title: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: severityColor, shape: BoxShape.circle)), const SizedBox(width: 8), Text('LAPORAN HASIL ANALISIS', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 1))]),
      actions: [Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(onTap: () => setState(() => _showOriginal = !_showOriginal), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _showOriginal ? AppColors.accentPrimary.withOpacity(0.15) : AppColors.bgInput, borderRadius: BorderRadius.circular(6), border: Border.all(color: _showOriginal ? AppColors.accentPrimary.withOpacity(0.5) : AppColors.borderSubtle)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_showOriginal ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 14, color: _showOriginal ? AppColors.accentPrimary : AppColors.textTertiary), const SizedBox(width: 5), Text(_showOriginal ? 'ORIGINAL' : 'MARKED', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: _showOriginal ? AppColors.accentPrimary : AppColors.textTertiary, letterSpacing: 1))]))))],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.borderSubtle)),
    );
  }

  Widget _buildDetectionImage(AnalysisResult result, List<DetectionResult> detections, Uint8List? imageBytes) {
    final hasImage = imageBytes != null;
    final isZoomed = _currentZoom > 1.0;
    return Container(
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: isZoomed ? AppColors.accentPrimary.withOpacity(0.5) : (_showOriginal ? AppColors.borderSubtle : AppColors.accentPrimary.withOpacity(0.5)), width: isZoomed ? 2 : (_showOriginal ? 1 : 2)), boxShadow: [if (!_showOriginal || isZoomed) BoxShadow(color: AppColors.accentPrimary.withOpacity(0.08), blurRadius: 12, spreadRadius: 2)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.only(topLeft: Radius.circular(AppSpacing.radiusMd), topRight: Radius.circular(AppSpacing.radiusMd)), border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
          child: Row(children: [
            Icon(isZoomed ? Icons.zoom_in_rounded : (_showOriginal ? Icons.image_outlined : Icons.auto_fix_high_rounded), size: 16, color: isZoomed ? AppColors.accentPrimary : (_showOriginal ? AppColors.textTertiary : AppColors.accentPrimary)),
            const SizedBox(width: 8),
            Text(isZoomed ? 'ZOOM ${_currentZoom.toStringAsFixed(1)}x' : (_showOriginal ? 'ORIGINAL IMAGE' : 'GAMBAR HASIL IDENTIFIKASI'), style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: isZoomed ? AppColors.accentPrimary : (_showOriginal ? AppColors.textTertiary : AppColors.accentPrimary), letterSpacing: 1.5)),
            const Spacer(),
            // ── Zoom controls ──
            if (hasImage && !_showOriginal) ...[
              _buildZoomBtn(Icons.remove_rounded, _zoomOut, _currentZoom <= _minZoom),
              const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(3), border: Border.all(color: AppColors.borderSubtle)),
                child: Text('${_currentZoom.toStringAsFixed(1)}x', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 3),
              _buildZoomBtn(Icons.add_rounded, _zoomIn, _currentZoom >= _maxZoom),
              if (isZoomed) ...[const SizedBox(width: 4), _buildZoomBtn(Icons.refresh_rounded, _resetZoom, false)],
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.info.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.touch_app_rounded, size: 12, color: AppColors.info), const SizedBox(width: 4), Text('HOVER', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.info, letterSpacing: 1))])),
            ],
          ])),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(AppSpacing.radiusMd), bottomRight: Radius.circular(AppSpacing.radiusMd)),
          child: hasImage ? InteractiveViewer(
              transformationController: _zoomController,
              minScale: _minZoom,
              maxScale: _maxZoom,
              onInteractionUpdate: (details) => _onZoomChanged(_zoomController.value),
              child: InteractiveDetectionImage(imageBytes: imageBytes!, result: result, detections: detections, showOriginal: _showOriginal, onHoverChanged: (idx) => setState(() => _hoveredDetectionIndex = idx)),
            )
            : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.broken_image_outlined, size: 40, color: AppColors.textMuted), const SizedBox(height: 8), Text('Image data not available', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))])))),
      ]),
    );
  }

  Widget _buildZoomBtn(IconData icon, VoidCallback onTap, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: disabled ? AppColors.bgInput : AppColors.accentPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: disabled ? AppColors.borderSubtle : AppColors.accentPrimary.withOpacity(0.3), width: 1),
        ),
        child: Icon(icon, size: 14, color: disabled ? AppColors.textMuted : AppColors.accentPrimary),
      ),
    );
  }

  // ============================================================
  // HORIZONTAL RESIZE DIVIDER
  // ============================================================

  Widget _buildHorizontalResizeDivider() {
    final isActive = _isDraggingDivider;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
        onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
        onHorizontalDragCancel: () => setState(() => _isDraggingDivider = false),
        onHorizontalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final totalW = box.size.width - 10;
          final currentLeft = totalW * _leftPanelRatio;
          final newLeft = (currentLeft + details.delta.dx).clamp(totalW * _minLeftRatio, totalW * _maxLeftRatio);
          final newRatio = newLeft / totalW;
          if ((newRatio - _leftPanelRatio).abs() > 0.001) {
            setState(() => _leftPanelRatio = newRatio);
          }
        },
        child: Container(
          width: 10,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentPrimary.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Center(
            child: Container(
              width: 3, height: 40,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accentPrimary : AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VERTICAL RESIZE DIVIDER
  // ============================================================

  Widget _buildVerticalResizeDivider() {
    final isActive = _isDraggingVDivider;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onVerticalDragStart: (_) => setState(() => _isDraggingVDivider = true),
        onVerticalDragEnd: (_) => setState(() => _isDraggingVDivider = false),
        onVerticalDragCancel: () => setState(() => _isDraggingVDivider = false),
        onVerticalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final totalH = box.size.height;
          final dividerH = 8.0;
          final usable = totalH - dividerH;
          final currentImg = usable * _imagePanelRatio;
          final newImg = (currentImg + details.delta.dy).clamp(usable * _minImageRatio, usable * _maxImageRatio);
          final newRatio = newImg / usable;
          if ((newRatio - _imagePanelRatio).abs() > 0.001) {
            setState(() => _imagePanelRatio = newRatio);
          }
        },
        child: Container(
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 30),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentPrimary.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Container(
              width: 40, height: 3,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accentPrimary : AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoveredInfoCard(DetectionResult det) {
    final color = det.classColor;
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: color.withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Text('HOVERED DETECTION', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.5)), const Spacer(), Icon(Icons.touch_app_rounded, size: 16, color: color)]), const SizedBox(height: 10), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(det.className.toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w800, color: color, height: 1.0)), const SizedBox(width: 10), Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('${(det.confidence * 100).toStringAsFixed(1)}%', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)))]), const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: det.confidence, backgroundColor: AppColors.bgInput, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6)), const SizedBox(height: 8), Row(children: [Icon(Icons.crop_free_rounded, size: 12, color: AppColors.textMuted), const SizedBox(width: 4), Text('BBox: ', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)), Text('${det.boundingBox.left.toInt()},${det.boundingBox.top.toInt()} > ${det.boundingBox.right.toInt()},${det.boundingBox.bottom.toInt()}', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)), const SizedBox(width: 12), Icon(Icons.open_in_full_rounded, size: 12, color: AppColors.textMuted), const SizedBox(width: 4), Text('${det.boxWidth.toInt()}x${det.boxHeight.toInt()} px', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))])]),
    );
  }

  Widget _buildClassFilterBar(AnalysisResult result) {
    final classCounts = result.classCounts; final classes = ['all', ...classCounts.keys.toList()];
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(AppSpacing.radiusSm), border: Border.all(color: AppColors.borderSubtle)),
      child: Row(children: [Icon(Icons.filter_list_rounded, size: 13, color: AppColors.textTertiary), const SizedBox(width: 6), Text('FILTER:', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1)), const SizedBox(width: 8), Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: classes.map((cls) { final isSelected = _classFilter == cls; final color = cls == 'all' ? AppColors.accentPrimary : AppColors.getDetectionColor(cls); final count = cls == 'all' ? result.totalDetections : (classCounts[cls] ?? 0); return Padding(padding: const EdgeInsets.only(right: 4), child: GestureDetector(onTap: () => setState(() => _classFilter = cls), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.15) : AppColors.bgInput, borderRadius: BorderRadius.circular(4), border: Border.all(color: isSelected ? color.withOpacity(0.6) : AppColors.borderSubtle, width: isSelected ? 1.5 : 0.5)), child: Row(mainAxisSize: MainAxisSize.min, children: [if (cls != 'all') Container(width: 6, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))), if (cls != 'all') const SizedBox(width: 4), Text(cls.toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? color : AppColors.textMuted, letterSpacing: 0.5)), const SizedBox(width: 3), Text('$count', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w800, color: isSelected ? color : AppColors.textTertiary))])))); }).toList())))]));
  }

  Widget _buildColonyCountHero(int colonyCount, String severity, Color severityColor, AnalysisResult result) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: severityColor.withOpacity(0.3), width: 1.5), boxShadow: [BoxShadow(color: severityColor.withOpacity(0.08), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: severityColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: severityColor.withOpacity(0.4))), child: Text(severity, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: severityColor, letterSpacing: 2))), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$colonyCount', style: GoogleFonts.jetBrainsMono(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.0)), Text('Colony Count (CFU)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))])]), const SizedBox(height: 12), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: severityColor.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Row(children: [Icon(Icons.verified_rounded, size: 14, color: severityColor), const SizedBox(width: 6), Text('SNI/ISO Validity: ', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)), Text(_getValidityStatus(colonyCount), style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: severityColor))]))]),
    );
  }

  Widget _buildDetectionBreakdown(AnalysisResult result, List<DetectionResult> detections) {
    final classCounts = <String, int>{}; for (final d in detections) { classCounts[d.className] = (classCounts[d.className] ?? 0) + 1; }
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(AppSpacing.radiusSm), border: Border.all(color: AppColors.borderSubtle)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.pie_chart_rounded, size: 14, color: AppColors.accentSecondary), const SizedBox(width: 6), Text('DETECTION BREAKDOWN', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5))]), const SizedBox(height: 10),
        _buildBreakdownRow('Colony', classCounts['colony'] ?? 0, AppColors.colonyColor, detections.length), const SizedBox(height: 6),
        _buildBreakdownRow('Bubble', classCounts['bubble'] ?? 0, AppColors.bubbleColor, detections.length), const SizedBox(height: 6),
        _buildBreakdownRow('Dust', classCounts['dust'] ?? 0, AppColors.dustColor, detections.length), const SizedBox(height: 6),
        _buildBreakdownRow('Crack', classCounts['crack'] ?? 0, AppColors.crackColor, detections.length),
        const Divider(height: 20, color: AppColors.borderSubtle),
        _buildBreakdownRow('Total', detections.length, AppColors.textPrimary, detections.length)]));
  }

  Widget _buildBreakdownRow(String label, int count, Color color, int total) {
    final pct = total > 0 ? (count / total * 100) : 0.0;
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 8), Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary))), Expanded(flex: 2, child: LayoutBuilder(builder: (context, constraints) => Stack(children: [Container(height: 6, decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(3))), FractionallySizedBox(widthFactor: pct / 100, child: Container(height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))))]))), const SizedBox(width: 8), SizedBox(width: 36, child: Text('$count', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.right)), const SizedBox(width: 4), SizedBox(width: 42, child: Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted), textAlign: TextAlign.right))]);
  }

  Widget _buildViewToggleInfo() => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.accentPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(AppSpacing.radiusXs), border: Border.all(color: AppColors.accentPrimary.withOpacity(0.2))), child: Row(children: [Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.accentPrimary), const SizedBox(width: 6), Expanded(child: Text('Tekan ORIGINAL/MARKED untuk beralih. Arahkan kursor ke marker untuk detail deteksi.', style: GoogleFonts.inter(fontSize: 10, color: AppColors.accentPrimary.withOpacity(0.8))))]));

  Widget _buildDetailsCard(AnalysisResult result) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(AppSpacing.radiusSm), border: Border.all(color: AppColors.borderSubtle)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.info_outline_rounded, size: 14, color: AppColors.info), const SizedBox(width: 6), Text('DETAILS', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5))]), const SizedBox(height: 10),
        _buildDetailRow('Sample ID', result.sampleId.isNotEmpty ? result.sampleId : '--'), const SizedBox(height: 5),
        _buildDetailRow('Image Size', '${result.imageWidth} x ${result.imageHeight} px'), const SizedBox(height: 5),
        _buildDetailRow('Processing Time', '${result.processingTime.inMilliseconds} ms'), const SizedBox(height: 5),
        _buildDetailRow('Avg Confidence', '${(result.averageConfidence * 100).toStringAsFixed(1)}%'), const SizedBox(height: 5),
        _buildDetailRow('Model', result.modelVersion), const SizedBox(height: 5),
        _buildDetailRow('Timestamp', _formatTimestamp(result.timestamp))]));
  }

  Widget _buildSampleMetadata(AnalysisResult result) {
    final hasMetadata = result.mediaType.isNotEmpty || result.sampleType.isNotEmpty; if (!hasMetadata) return const SizedBox.shrink();
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(AppSpacing.radiusSm), border: Border.all(color: AppColors.borderSubtle)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.assignment_outlined, size: 14, color: AppColors.info), const SizedBox(width: 6), Text('SAMPLE METADATA', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5))]), const SizedBox(height: 10),
        if (result.sampleType.isNotEmpty) _buildDetailRow('Sample Type', result.sampleType), if (result.sampleType.isNotEmpty) const SizedBox(height: 5),
        if (result.mediaType.isNotEmpty) _buildDetailRow('Media', result.mediaType), if (result.mediaType.isNotEmpty) const SizedBox(height: 5),
        if (result.dilution.isNotEmpty) _buildDetailRow('Dilution', result.dilution), if (result.dilution.isNotEmpty) const SizedBox(height: 5),
        if (result.inoculationMethod.isNotEmpty) _buildDetailRow('Inoculation', result.inoculationMethod), if (result.inoculationMethod.isNotEmpty) const SizedBox(height: 5),
        if (result.inoculumVolume.isNotEmpty) _buildDetailRow('Volume', result.inoculumVolume), if (result.inoculumVolume.isNotEmpty) const SizedBox(height: 5),
        if (result.incubatorTemp.isNotEmpty) _buildDetailRow('Temp', result.incubatorTemp), if (result.incubatorTemp.isNotEmpty) const SizedBox(height: 5),
        if (result.analystName.isNotEmpty) _buildDetailRow('Analyst', result.analystName)]));
  }

  Widget _buildDetailRow(String label, String value) => Row(children: [Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)), const Spacer(), Flexible(child: Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis))]);

  List<DetectionResult> _getFilteredDetections(AnalysisResult result) { if (_classFilter == 'all') return result.detections; return result.detections.where((d) => d.className == _classFilter).toList(); }
  String _getSeverity(int c) { if (c > 300) return 'TNTC'; if (c > 150) return 'TFTC'; if (c > 30) return 'IDEAL'; return 'LOW'; }
  Color _getSeverityColor(int c) { if (c > 300) return AppColors.error; if (c > 150) return AppColors.warning; if (c > 30) return AppColors.success; return AppColors.info; }
  String _getValidityStatus(int c) { if (c < 30) return 'Too Few (<30)'; if (c > 300) return 'TNTC (>300)'; return 'Valid (30-300)'; }
  String _formatTimestamp(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}
