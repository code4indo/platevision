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
import 'package:platevision_ai/screens/reports/interscience_report_screen.dart';

// ════════════════════════════════════════════════════════════════
// Undo/Redo snapshot for manual adjustments
// ════════════════════════════════════════════════════════════════

class _AdjustmentSnapshot {
  final Set<int> removedIndices;
  final List<DetectionResult> userAdded;

  _AdjustmentSnapshot({
    required this.removedIndices,
    required this.userAdded,
  });
}

// ════════════════════════════════════════════════════════════════
// DETECTION OVERLAY PAINTER — + manual add/remove markers
// ════════════════════════════════════════════════════════════════

class DetectionOverlayPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final int imageWidth;
  final int imageHeight;
  final int hoveredIndex;
  final Set<int> removedIndices;
  final List<DetectionResult> userAdded;

  DetectionOverlayPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    this.hoveredIndex = -1,
    this.removedIndices = const {},
    this.userAdded = const [],
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

  /// Convert a screen/display Offset back to image pixel coordinates.
  static Offset screenToImage(Offset screenPos, Size canvasSize, int imgW, int imgH) {
    final t = calcTransform(canvasSize, imgW, imgH);
    return Offset(
      (screenPos.dx - t.ox) / t.scale,
      (screenPos.dy - t.oy) / t.scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;
    final t = calcTransform(size, imageWidth, imageHeight);

    // ── Pass 1: Draw removed colonies (greyed out with X) ──
    for (final i in removedIndices) {
      if (i >= detections.length) continue;
      final det = detections[i];
      final dr = Rect.fromLTRB(
        det.boundingBox.left * t.scale + t.ox,
        det.boundingBox.top * t.scale + t.oy,
        det.boundingBox.right * t.scale + t.ox,
        det.boundingBox.bottom * t.scale + t.oy,
      );
      final grey = Paint()..color = Colors.grey.withOpacity(0.35)..style = PaintingStyle.fill;
      canvas.drawRect(dr, grey);
      // X mark
      final cp = Paint()..color = Colors.grey.withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = 2.0;
      canvas.drawLine(dr.topLeft, dr.bottomRight, cp);
      canvas.drawLine(dr.topRight, dr.bottomLeft, cp);
    }

    // ── Pass 2: Draw all non-removed, non-hovered AI boxes ──
    for (int i = 0; i < detections.length; i++) {
      if (removedIndices.contains(i)) continue;
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

    // ── Pass 3: Draw hovered box (prominent, if not removed) ──
    if (hoveredIndex >= 0 && hoveredIndex < detections.length && !removedIndices.contains(hoveredIndex)) {
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

    // ── Pass 4: Numbered markers on non-removed detections ──
    int markerNum = 0;
    for (int i = 0; i < detections.length; i++) {
      if (removedIndices.contains(i)) continue;
      markerNum++;
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
        canvas.drawCircle(c, 10, Paint()..color = color.withOpacity(0.25)..style = PaintingStyle.fill..maskFilter = MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawCircle(c, 8, Paint()..color = color..style = PaintingStyle.fill);
        canvas.drawCircle(c, 8, Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      } else {
        canvas.drawCircle(c, 5, Paint()..color = color.withOpacity(0.85)..style = PaintingStyle.fill);
        canvas.drawCircle(c, 5, Paint()..color = Colors.white.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      }

      // Number text inside marker
      final numStr = '$markerNum';
      final fontSize = isH ? 9.0 : 7.0;
      final npb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: fontSize))
        ..pushStyle(ui.TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: ui.FontWeight.w800))
        ..addText(numStr);
      final np = npb.build()..layout(ui.ParagraphConstraints(width: 30));
      canvas.drawParagraph(np, Offset(c.dx - np.maxIntrinsicWidth / 2, c.dy - np.height / 2));
    }

    // ── Pass 5: User‑added colony markers (orange circle, numbered) ──
    int userMarkerStart = markerNum; // continue numbering from AI
    for (int uaIdx = 0; uaIdx < userAdded.length; uaIdx++) {
      final added = userAdded[uaIdx];
      final uNum = userMarkerStart + uaIdx + 1;
      final dr = Rect.fromLTRB(
        added.boundingBox.left * t.scale + t.ox,
        added.boundingBox.top * t.scale + t.oy,
        added.boundingBox.right * t.scale + t.ox,
        added.boundingBox.bottom * t.scale + t.oy,
      );
      final c = dr.center;

      // Dashed circle
      final dashPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(c, 12, dashPaint);

      // Fill
      canvas.drawCircle(c, 12, Paint()..color = Colors.orange.withOpacity(0.25)..style = PaintingStyle.fill);

      // "+" crosshair using two lines (always perfectly centered)
      final crossPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      const crossSize = 6.0;
      canvas.drawLine(Offset(c.dx - crossSize, c.dy), Offset(c.dx + crossSize, c.dy), crossPaint);
      canvas.drawLine(Offset(c.dx, c.dy - crossSize), Offset(c.dx, c.dy + crossSize), crossPaint);

      // Number text below the circle
      final numStr = '$uNum';
      final npb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 7, textAlign: TextAlign.center))
        ..pushStyle(ui.TextStyle(color: Colors.orange, fontSize: 7, fontWeight: FontWeight.w700))
        ..addText(numStr);
      final np = npb.build()..layout(ui.ParagraphConstraints(width: 30));
      canvas.drawParagraph(np, Offset(c.dx - np.maxIntrinsicWidth / 2, c.dy + 15));
    }
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter old) =>
      old.hoveredIndex != hoveredIndex ||
      old.detections != detections ||
      old.removedIndices != removedIndices ||
      old.userAdded != userAdded;
}

// ════════════════════════════════════════════════════════════════
// EDIT MODE for manual colony add/remove
// ════════════════════════════════════════════════════════════════

enum EditMode { none, add, remove }

// ════════════════════════════════════════════════════════════════
// INTERACTIVE DETECTION IMAGE — with manual add/remove support
// ════════════════════════════════════════════════════════════════

class InteractiveDetectionImage extends StatefulWidget {
  final Uint8List imageBytes;
  final AnalysisResult result;
  final List<DetectionResult> detections;
  final bool showOriginal;
  final ValueChanged<int> onHoverChanged;

  // Manual add/remove
  final EditMode editMode;
  final Set<int> removedIndices;
  final List<DetectionResult> userAdded;
  final ValueChanged<Offset>? onAddColony;
  final ValueChanged<int>? onRemoveColony;
  final ValueChanged<int>? onRemoveUserAdded;

  const InteractiveDetectionImage({
    super.key,
    required this.imageBytes,
    required this.result,
    required this.detections,
    required this.showOriginal,
    required this.onHoverChanged,
    this.editMode = EditMode.none,
    this.removedIndices = const {},
    this.userAdded = const [],
    this.onAddColony,
    this.onRemoveColony,
    this.onRemoveUserAdded,
  });

  @override
  State<InteractiveDetectionImage> createState() => _InteractiveDetectionImageState();
}

class _InteractiveDetectionImageState extends State<InteractiveDetectionImage> {
  int _hoveredIndex = -1;
  final GlobalKey _imageAreaKey = GlobalKey();

  void _setHovered(int idx) {
    if (idx != _hoveredIndex) {
      _hoveredIndex = idx;
      widget.onHoverChanged(idx);
      setState(() {});
    }
  }

  void _handleImageTap(Offset localPos) {
    if (widget.editMode != EditMode.add || widget.onAddColony == null) return;

    // Get the RenderBox to compute position relative to the image area
    final renderBox = _imageAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    // Only trigger if the tap is within the image area bounds
    final imgW = widget.result.imageWidth;
    final imgH = widget.result.imageHeight;
    if (imgW <= 0 || imgH <= 0) return;

    final imageOffset = DetectionOverlayPainter.screenToImage(localPos, size, imgW, imgH);
    // Clamp to image bounds
    final clampedX = imageOffset.dx.clamp(0, imgW.toDouble()).toDouble();
    final clampedY = imageOffset.dy.clamp(0, imgH.toDouble()).toDouble();
    widget.onAddColony!(Offset(clampedX, clampedY));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final canvasSize = constraints.biggest;
      final imgW = widget.result.imageWidth;
      final imgH = widget.result.imageHeight;
      final isAddMode = widget.editMode == EditMode.add;
      final isRemoveMode = widget.editMode == EditMode.remove;

      // Build positioned hit area buttons for non‑removed AI detections
      final hitAreas = <Widget>[];
      if (!widget.showOriginal && imgW > 0 && imgH > 0) {
        // ── AI detections hit areas ──
        for (int i = 0; i < widget.detections.length; i++) {
          final isRemoved = widget.removedIndices.contains(i);
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
                cursor: isRemoveMode
                    ? SystemMouseCursors.click
                    : (isH ? SystemMouseCursors.click : SystemMouseCursors.basic),
                onEnter: (_) => _setHovered(i),
                onExit: (_) => _setHovered(-1),
                child: GestureDetector(
                  onTap: isRemoveMode && widget.onRemoveColony != null
                      ? () => widget.onRemoveColony!(i)
                      : () => _setHovered(i == _hoveredIndex ? -1 : i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isH && !isRemoved
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

        // ── User‑added detection hit areas ──
        for (int uaIdx = 0; uaIdx < widget.userAdded.length; uaIdx++) {
          final dr = DetectionOverlayPainter.getDisplayRect(
            widget.userAdded[uaIdx], canvasSize, imgW, imgH,
          );
          hitAreas.add(
            Positioned(
              left: max(0, dr.left - 6),
              top: max(0, dr.top - 6),
              width: max(dr.width + 12, 32),
              height: max(dr.height + 12, 32),
              child: MouseRegion(
                cursor: isRemoveMode ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: isRemoveMode && widget.onRemoveUserAdded != null
                      ? () => widget.onRemoveUserAdded!(uaIdx)
                      : null,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          );
        }
      }

      return Stack(
        key: _imageAreaKey,
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
                  removedIndices: widget.removedIndices,
                  userAdded: widget.userAdded,
                ),
              ),
            ),

          // ═══ HIT AREAS (AI detections) ═══
          ...hitAreas,

          // ═══ ADD‑MODE TAP CATCHER ═══
          if (isAddMode && !widget.showOriginal)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) => _handleImageTap(details.localPosition),
                child: MouseRegion(
                  cursor: SystemMouseCursors.precise,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

          // ═══ DETECTION COUNT BADGE ═══
          if (!widget.showOriginal && (widget.detections.isNotEmpty || widget.userAdded.isNotEmpty))
            Positioned(
              top: 8,
              right: 8,
              child: _buildCountBadge(),
            ),

          // ═══ LEGEND ═══
          if (!widget.showOriginal && (widget.detections.isNotEmpty || widget.userAdded.isNotEmpty))
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
    for (final d in widget.detections) {
      if (!widget.removedIndices.contains(widget.detections.indexOf(d))) {
        classCounts[d.className] = (classCounts[d.className] ?? 0) + 1;
      }
    }
    // Count user-added as "colony"
    classCounts['colony'] = (classCounts['colony'] ?? 0) + widget.userAdded.length;
    final totalDetected = classCounts.values.fold(0, (a, b) => a + b);
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
          Text('$totalDetected', style: GoogleFonts.jetBrainsMono(
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
          // Show adjustment summary
          if (widget.userAdded.length > 0 || widget.removedIndices.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(width: 1, height: 14, color: AppColors.borderSubtle),
            const SizedBox(width: 8),
            Text('±${widget.userAdded.length}', style: GoogleFonts.jetBrainsMono(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange,
            )),
            const SizedBox(width: 2),
            Text('adj', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w500, color: Colors.orange.withOpacity(0.8))),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendBadge() {
    // Include user-added in the class set
    final classSet = <String>{};
    for (final d in widget.detections) { classSet.add(d.className); }
    if (widget.userAdded.isNotEmpty) classSet.add('colony');

    final modeHint = widget.editMode == EditMode.add
        ? 'Tap image to add colony'
        : widget.editMode == EditMode.remove
            ? 'Tap colony or manual marker to remove'
            : 'Hover for detail';

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
            int count;
            if (cls == 'colony') {
              // Combine AI colonies (non-removed) + user-added
              final aiColonies = widget.detections.where((d) => d.className == 'colony').length - widget.removedIndices.length;
              count = aiColonies + widget.userAdded.length;
            } else {
              count = widget.detections.where((d) => d.className == cls && !widget.removedIndices.contains(widget.detections.indexOf(d))).length;
            }
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
          // Show user-added hint
          if (widget.userAdded.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5))),
                const SizedBox(width: 6),
                Text('MANUAL +', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.orange)),
                const SizedBox(width: 6),
                Text('x${widget.userAdded.length}', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w500, color: AppColors.textTertiary)),
              ]),
            ),
          ],
          if (widget.removedIndices.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5))),
                const SizedBox(width: 6),
                Text('REMOVED', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(width: 6),
                Text('x${widget.removedIndices.length}', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w500, color: AppColors.textTertiary)),
              ]),
            ),
          ],
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 0.5))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, size: 10, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(modeHint, style: GoogleFonts.inter(
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

  // ── Manual add/remove state ──
  EditMode _editMode = EditMode.none;
  Set<int> _removedColonyIndices = {};
  List<DetectionResult> _userAddedDetections = [];

  // ── Undo/Redo ──
  final List<_AdjustmentSnapshot> _adjustmentHistory = [];
  int _adjustmentHistoryIndex = -1;

  bool get _canUndo => _adjustmentHistoryIndex > 0;
  bool get _canRedo => _adjustmentHistoryIndex < _adjustmentHistory.length - 1;

  void _pushCheckpoint() {
    // Discard any future states past the current index
    _adjustmentHistory.removeRange(_adjustmentHistoryIndex + 1, _adjustmentHistory.length);
    _adjustmentHistory.add(_AdjustmentSnapshot(
      removedIndices: Set.from(_removedColonyIndices),
      userAdded: List.from(_userAddedDetections),
    ));
    _adjustmentHistoryIndex++;
  }

  void _undo() {
    if (!_canUndo) return;
    _adjustmentHistoryIndex--;
    final snap = _adjustmentHistory[_adjustmentHistoryIndex];
    setState(() {
      _removedColonyIndices = Set<int>.from(snap.removedIndices);
      _userAddedDetections = List<DetectionResult>.from(snap.userAdded);
    });
  }

  void _redo() {
    if (!_canRedo) return;
    _adjustmentHistoryIndex++;
    final snap = _adjustmentHistory[_adjustmentHistoryIndex];
    setState(() {
      _removedColonyIndices = Set<int>.from(snap.removedIndices);
      _userAddedDetections = List<DetectionResult>.from(snap.userAdded);
    });
  }

  /// Net colony count after manual adjustments.
  int get _adjustedColonyCount {
    final aiColonies = (_getCurrentDetections() ?? [])
        .where((d) => d.className == 'colony').length;
    return aiColonies - _removedColonyIndices.length + _userAddedDetections.length;
  }

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

  /// Returns the filtered detections.
  List<DetectionResult>? _getCurrentDetections() {
    final ap = context.read<AnalysisProvider>();
    final result = ap.currentResult;
    if (result == null) return null;
    return _getFilteredDetections(result);
  }

  // ── Manual add/remove handlers ──

  void _handleAddColony(Offset imagePos) {
    _pushCheckpoint();
    final halfSize = 15.0;
    final bbox = Rect.fromCenter(
      center: imagePos,
      width: halfSize * 2,
      height: halfSize * 2,
    );
    final newDetection = DetectionResult(
      className: 'colony',
      confidence: 1.0,
      boundingBox: bbox,
      classId: 0,
    );
    setState(() => _userAddedDetections.add(newDetection));
  }

  /// Toggle remove of an AI colony by its detection index.
  void _handleRemoveColony(int index) {
    _pushCheckpoint();
    setState(() {
      if (_removedColonyIndices.contains(index)) {
        _removedColonyIndices.remove(index);
      } else {
        _removedColonyIndices.add(index);
      }
    });
  }

  /// Remove a user‑added colony by its position in the userAdded list.
  void _handleRemoveUserAdded(int index) {
    _pushCheckpoint();
    setState(() => _userAddedDetections.removeAt(index));
  }

  void _toggleEditMode(EditMode mode) {
    final newMode = _editMode == mode ? EditMode.none : mode;
    if (newMode != EditMode.none && _editMode == EditMode.none) {
      // Entering edit mode — save initial checkpoint for undo
      _adjustmentHistory.clear();
      _adjustmentHistoryIndex = -1;
      _pushCheckpoint();
    }
    setState(() => _editMode = newMode);
  }

  Future<void> _saveAdjustments() async {
    final ap = context.read<AnalysisProvider>();
    final result = ap.currentResult;
    if (result == null) return;

    await ap.updateManualAdjustments(
      id: result.id,
      added: _userAddedDetections.length,
      removed: _removedColonyIndices.length,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Penyesuaian tersimpan (+${_userAddedDetections.length}/−${_removedColonyIndices.length})', style: GoogleFonts.inter(fontSize: 12)),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 2),
    ));
    setState(() => _editMode = EditMode.none);
  }

  void _cancelAdjustments() {
    setState(() {
      _userAddedDetections.clear();
      _removedColonyIndices.clear();
      _editMode = EditMode.none;
    });
    _adjustmentHistory.clear();
    _adjustmentHistoryIndex = -1;
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
    final displayCount = _adjustedColonyCount;
    final severity = _getSeverity(displayCount);
    final severityColor = _getSeverityColor(displayCount);

    return Scaffold(
      backgroundColor: AppColors.bgScaffold,
      appBar: _buildAppBar(result, severityColor, imageBytes),
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
              _buildColonyCountHero(displayCount, severity, severityColor, result),
              const SizedBox(height: AppSpacing.md),
              if (_hoveredDetectionIndex >= 0 && _hoveredDetectionIndex < detections.length) _buildHoveredInfoCard(detections[_hoveredDetectionIndex]),
              if (_hoveredDetectionIndex >= 0 && _hoveredDetectionIndex < detections.length) const SizedBox(height: AppSpacing.md),
              _buildDetectionBreakdown(result, detections), const SizedBox(height: AppSpacing.md),
              _buildViewToggleInfo(), const SizedBox(height: AppSpacing.md),
              _buildDetailsCard(result), const SizedBox(height: AppSpacing.md),
              _buildReportMetadataCard(result),
            ])),
          ),
        ]);
      }),
    );
  }

  PreferredSizeWidget _buildAppBar(AnalysisResult result, Color severityColor, Uint8List? imageBytes) {
    return AppBar(backgroundColor: AppColors.bgSecondary, elevation: 0,
      leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.of(context).pop()),
      title: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: severityColor, shape: BoxShape.circle)), const SizedBox(width: 8), Text('LAPORAN HASIL ANALISIS', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 1))]),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => InterscienceReportScreen(result: result, imageBytes: imageBytes)));
            },
            icon: const Icon(Icons.print_rounded, size: 14),
            label: Text('PRINT REPORT', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPrimary,
              backgroundColor: AppColors.accentPrimary.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: AppColors.accentPrimary.withOpacity(0.5)),
              ),
            ),
          ),
        ),
      ],
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
            // ── Original / Marked Toggle ──
            if (hasImage) ...[
              GestureDetector(onTap: () => setState(() => _showOriginal = !_showOriginal), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _showOriginal ? AppColors.accentPrimary.withOpacity(0.15) : AppColors.bgInput, borderRadius: BorderRadius.circular(6), border: Border.all(color: _showOriginal ? AppColors.accentPrimary.withOpacity(0.5) : AppColors.borderSubtle)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_showOriginal ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 14, color: _showOriginal ? AppColors.accentPrimary : AppColors.textTertiary), const SizedBox(width: 5), Text(_showOriginal ? 'ORIGINAL' : 'MARKED', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: _showOriginal ? AppColors.accentPrimary : AppColors.textTertiary, letterSpacing: 1))]))),
              const SizedBox(width: 12),
            ],
            // ── Zoom controls ──
            if (hasImage) ...[
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
              // ── ADD / REMOVE mode toggles ──
              _buildModeBtn(Icons.add_circle_outline_rounded, 'ADD', EditMode.add),
              const SizedBox(width: 3),
              _buildModeBtn(Icons.remove_circle_outline_rounded, 'REM', EditMode.remove),
              if (_editMode != EditMode.none) ...[
                const SizedBox(width: 3),
                _buildModeBtn(Icons.undo_rounded, 'UNDO', EditMode.none, isUndo: true),
                _buildModeBtn(Icons.redo_rounded, 'REDO', EditMode.none, isRedo: true),
                const SizedBox(width: 3),
                _buildModeBtn(Icons.check_circle_rounded, 'SAVE', EditMode.none, isSave: true),
                const SizedBox(width: 3),
                _buildModeBtn(Icons.cancel_rounded, 'BTL', EditMode.none, isCancel: true),
              ],
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.info.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.touch_app_rounded, size: 12, color: AppColors.info), const SizedBox(width: 4), Text('HOVER', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.info, letterSpacing: 1))])),            ],
          ])),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(AppSpacing.radiusMd), bottomRight: Radius.circular(AppSpacing.radiusMd)),
              child: hasImage ? InteractiveViewer(
                  transformationController: _zoomController,
                  minScale: _minZoom,
                  maxScale: _maxZoom,
                  onInteractionUpdate: (details) => _onZoomChanged(_zoomController.value),
                  child: InteractiveDetectionImage(
                    imageBytes: imageBytes,
                    result: result,
                    detections: detections,
                    showOriginal: _showOriginal,
                    onHoverChanged: (idx) => setState(() => _hoveredDetectionIndex = idx),
                    editMode: _editMode,
                    removedIndices: _removedColonyIndices,
                    userAdded: _userAddedDetections,
                    onAddColony: _handleAddColony,
                    onRemoveColony: _handleRemoveColony,
                    onRemoveUserAdded: _handleRemoveUserAdded,
                  ),
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

  Widget _buildModeBtn(IconData icon, String label, EditMode mode, {bool isSave = false, bool isCancel = false, bool isUndo = false, bool isRedo = false}) {
    final isActive = _editMode == mode && !isSave && !isCancel && !isUndo && !isRedo;
    final Color color;
    final Color bgColor;
    if (isSave) {
      color = AppColors.success;
      bgColor = AppColors.success.withOpacity(0.15);
    } else if (isCancel) {
      color = AppColors.textTertiary;
      bgColor = AppColors.textTertiary.withOpacity(0.1);
    } else if (isUndo || isRedo) {
      color = AppColors.info;
      bgColor = AppColors.info.withOpacity(0.1);
    } else if (mode == EditMode.add) {
      color = Colors.orange;
      bgColor = isActive ? Colors.orange.withOpacity(0.2) : AppColors.bgInput;
    } else {
      color = AppColors.error;
      bgColor = isActive ? AppColors.error.withOpacity(0.2) : AppColors.bgInput;
    }
    final bool disabled = (isUndo && !_canUndo) || (isRedo && !_canRedo);

    return GestureDetector(
      onTap: disabled
          ? null
          : () {
              if (isSave) {
                _saveAdjustments();
              } else if (isCancel) {
                _cancelAdjustments();
              } else if (isUndo) {
                _undo();
              } else if (isRedo) {
                _redo();
              } else {
                _toggleEditMode(mode);
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: disabled ? AppColors.bgInput : bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: disabled ? AppColors.borderSubtle : (isActive || isSave ? color.withOpacity(0.6) : AppColors.borderSubtle),
            width: isActive || isSave ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: disabled ? AppColors.textMuted : color),
          const SizedBox(width: 3),
          Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w700, color: disabled ? AppColors.textMuted : color, letterSpacing: 0.5)),
        ]),
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
    final aiCount = result.colonyCount;
    final hasAdjustments = _userAddedDetections.isNotEmpty || _removedColonyIndices.isNotEmpty;
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: severityColor.withOpacity(0.3), width: 1.5), boxShadow: [BoxShadow(color: severityColor.withOpacity(0.08), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: severityColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: severityColor.withOpacity(0.4))), child: Text(severity, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: severityColor, letterSpacing: 2))), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('$colonyCount', style: GoogleFonts.jetBrainsMono(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.0)), if (hasAdjustments && colonyCount != aiCount) ...[const SizedBox(width: 6), Icon(Icons.edit_rounded, size: 14, color: Colors.orange)]]), Text('Colony Count (CFU)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))]), const Spacer(), Container(width: 1, height: 40, color: AppColors.borderSubtle), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(result.adjustedCfuPerMLLabel, style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.0)), Text('CFU/mL', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))])]), const SizedBox(height: 12),
      if (hasAdjustments) Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange.withOpacity(0.3))), child: Row(children: [Icon(Icons.tune_rounded, size: 13, color: Colors.orange), const SizedBox(width: 6), Text('AI: $aiCount  |  +${_userAddedDetections.length}  |  −${_removedColonyIndices.length}  |  = $colonyCount (adjusted)', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange))]))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: severityColor.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Row(children: [Icon(Icons.verified_rounded, size: 14, color: severityColor), const SizedBox(width: 6), Text('SNI/ISO Validity: ', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)), Text(_getValidityStatus(colonyCount), style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: severityColor)), const Spacer(), Text('Dilution: ${result.dilution.isEmpty ? '1.0' : result.dilution}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textTertiary))]))]),
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

  Widget _buildViewToggleInfo() => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.accentPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(AppSpacing.radiusXs), border: Border.all(color: AppColors.accentPrimary.withOpacity(0.2))), child: Row(children: [Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.accentPrimary), const SizedBox(width: 6), Expanded(child: Text('Tekan ORIGINAL/MARKED untuk beralih. Gunakan ADD/REMOVE untuk adjust koloni manual.', style: GoogleFonts.inter(fontSize: 10, color: AppColors.accentPrimary.withOpacity(0.8))))]));

  Widget _buildDetailsCard(AnalysisResult result) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(AppSpacing.radiusSm), border: Border.all(color: AppColors.borderSubtle)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.info_outline_rounded, size: 14, color: AppColors.info), const SizedBox(width: 6), Text('DETAILS', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5))]), const SizedBox(height: 10),
        _buildDetailRow('Sample ID', result.sampleId.isNotEmpty ? result.sampleId : '--'), const SizedBox(height: 5),
        _buildDetailRow('Image Size', '${result.imageWidth} x ${result.imageHeight} px'), const SizedBox(height: 5),
        _buildDetailRow('Processing Time', '${result.processingTime.inMilliseconds} ms'), const SizedBox(height: 5),
        _buildDetailRow('Avg Confidence', '${(result.averageConfidence * 100).toStringAsFixed(1)}%'), const SizedBox(height: 5),
        _buildDetailRow('Manual Added', '+${result.added}'), const SizedBox(height: 5),
        _buildDetailRow('Manual Removed', '−${result.removed}'), const SizedBox(height: 5),
        _buildDetailRow('Model', result.modelVersion), const SizedBox(height: 5),
        _buildDetailRow('Timestamp', _formatTimestamp(result.timestamp))]));
  }

  Widget _buildReportMetadataCard(AnalysisResult result) {
    final colonies = result.detections.where((d) => d.className == 'colony').toList();
    final String minDiam = colonies.isEmpty ? '0.00' : (colonies.map((d) => d.boxWidth).reduce(min) / 10).toStringAsFixed(2);
    final String meanDiam = colonies.isEmpty ? '0.00' : (colonies.map((d) => d.boxWidth).reduce((a, b) => a + b) / colonies.length / 10).toStringAsFixed(2);
    final String maxDiam = colonies.isEmpty ? '0.00' : (colonies.map((d) => d.boxWidth).reduce(max) / 10).toStringAsFixed(2);
    
    final adjustedCount = result.colonyCount + result.added - result.removed;
    String comment;
    if (adjustedCount == 0) comment = 'No colonies';
    else if (adjustedCount < 30) comment = 'TFTC';
    else if (adjustedCount <= 300) comment = 'OK';
    else comment = 'TNTC';

    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(AppSpacing.radiusSm), border: Border.all(color: AppColors.borderSubtle)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.assignment_outlined, size: 14, color: AppColors.info), const SizedBox(width: 6), Text('REPORT METADATA', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5))]), 
        const SizedBox(height: 10),
        _buildDetailRow('Sample ID', result.id), const SizedBox(height: 5),
        _buildDetailRow('Media Type', result.mediaType.isNotEmpty ? result.mediaType : 'PCA'), const SizedBox(height: 5),
        _buildDetailRow('Dilution', result.dilution.isNotEmpty ? result.dilution : '1.0'), const SizedBox(height: 5),
        _buildDetailRow('Volume (mL)', result.inoculumVolume.isNotEmpty ? result.inoculumVolume : '1.000000'), const SizedBox(height: 5),
        _buildDetailRow('AI Count', '${result.colonyCount}'), const SizedBox(height: 5),
        _buildDetailRow('Added/Removed', '+${result.added}/−${result.removed}'), const SizedBox(height: 5),
        _buildDetailRow('Adjusted Count', '$adjustedCount'), const SizedBox(height: 5),
        _buildDetailRow('CFU Prorata', adjustedCount > 0 && adjustedCount < 30 ? 'TFTC' : adjustedCount <= 300 ? 'OK' : 'TNTC'), const SizedBox(height: 5),
        _buildDetailRow('min CFU Ø (mm)', minDiam), const SizedBox(height: 5),
        _buildDetailRow('mean CFU Ø (mm)', meanDiam), const SizedBox(height: 5),
        _buildDetailRow('max CFU Ø (mm)', maxDiam), const SizedBox(height: 5),
        _buildDetailRow('Comment', comment), const SizedBox(height: 5),
        _buildDetailRow('Counted By', 'PlateVisionAI'), const SizedBox(height: 5),
        const Divider(height: 16, color: AppColors.borderSubtle),
        _buildDetailRow('Review Signed By', '-'), const SizedBox(height: 5),
        _buildDetailRow('Review Date', '-'), const SizedBox(height: 5),
        _buildDetailRow('Rejection Signed By', 'N/A'), const SizedBox(height: 5),
        _buildDetailRow('Rejection Date', 'N/A'),
      ])
    );
  }

  Widget _buildDetailRow(String label, String value) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 140, child: Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted))), Expanded(child: Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.left, overflow: TextOverflow.ellipsis))]);

  List<DetectionResult> _getFilteredDetections(AnalysisResult result) { if (_classFilter == 'all') return result.detections; return result.detections.where((d) => d.className == _classFilter).toList(); }
  String _getSeverity(int c) { if (c > 300) return 'TNTC'; if (c >= 30) return 'IDEAL'; if (c > 0) return 'TFTC'; return 'NONE'; }
  Color _getSeverityColor(int c) { if (c > 300) return AppColors.error; if (c >= 30) return AppColors.success; if (c > 0) return AppColors.warning; return AppColors.info; }
  String _getValidityStatus(int c) { if (c < 30) return 'Too Few (<30)'; if (c > 300) return 'TNTC (>300)'; return 'Valid (30-300)'; }
  String _formatTimestamp(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}
