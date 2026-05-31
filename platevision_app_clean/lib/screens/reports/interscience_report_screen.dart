import 'dart:html' as html;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/models/detection_result.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/screens/analysis/analysis_result_screen.dart';

class InterscienceReportScreen extends StatelessWidget {
  final AnalysisResult result;
  final Uint8List? imageBytes;
  final GlobalKey _reportKey = GlobalKey();
  final GlobalKey _originalImageKey = GlobalKey();
  final GlobalKey _analyzedImageKey = GlobalKey();
  
  InterscienceReportScreen({super.key, required this.result, this.imageBytes});

  static const Color _greenHeader = Color(0xFF2E7D32);
  static const Color _greenLight = Color(0xFF4CAF50);
  static const Color _greenBg = Color(0xFFE8F5E9);
  static const Color _greenLabel = Color(0xFF2E7D32);
  static const Color _paperBg = Color(0xFFFAFAFA);
  static const Color _borderColor = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgScaffold,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        title: Text('ANALYSIS REPORT', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.print_rounded), onPressed: () => html.window.print(), tooltip: 'Print'),
          IconButton(icon: const Icon(Icons.download_rounded), onPressed: () => _exportReportPdf(context), tooltip: 'Export'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: RepaintBoundary(
              key: _reportKey,
              child: _buildReportPaper(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  Widget _buildReportPaper() {
    return Container(
      decoration: BoxDecoration(
        color: _paperBg,
        border: Border.all(color: _borderColor, width: 2),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(2, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLogoHeader(),
          const Divider(height: 1, color: _borderColor),
          _buildPlateImages(),
          const Divider(height: 1, color: _borderColor),
          _buildDataTable(),
          const Divider(height: 1, color: _borderColor),
          _buildColonySizeSection(),
          const Divider(height: 1, color: _borderColor),
          _buildClassificationSection(),
          const Divider(height: 1, color: _borderColor),
          _buildReviewSection(),
          const Divider(height: 1, color: _borderColor),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(children: [
        RichText(text: TextSpan(children: [
          TextSpan(text: 'PLATE', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w300, color: _greenLight, letterSpacing: 2)),
          TextSpan(text: 'VISION', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: _greenHeader, letterSpacing: 2)),
          TextSpan(text: ' AI', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w300, color: Colors.grey, letterSpacing: 1)),
        ])),
        const Spacer(),
        Text('Colony Count Report', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.grey, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  // ============================================================
  // PLATE IMAGES — Now with REAL images + Detection Overlay
  // ============================================================

  Widget _buildPlateImages() {
    final hasImage = imageBytes != null || result.imagePath.isNotEmpty;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          return Flex(
            direction: isNarrow ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isNarrow ? 0 : 1,
                child: RepaintBoundary(
                  key: _originalImageKey,
                  child: _buildImageBox(label: 'ORIGINAL', isAnnotated: false, hasImage: hasImage),
                ),
              ),
              SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
              Expanded(
                flex: isNarrow ? 0 : 1,
                child: RepaintBoundary(
                  key: _analyzedImageKey,
                  child: _buildImageBox(label: 'ANALYZED', isAnnotated: true, hasImage: hasImage),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  ImageProvider? _getImageProvider() {
    if (imageBytes != null) {
      return MemoryImage(imageBytes!);
    }
    if (result.imagePath.isEmpty) return null;
    if (result.imagePath.startsWith('http')) {
      return NetworkImage(result.imagePath);
    }
    return FileImage(File(result.imagePath));
  }

  Widget _buildImageBox({required String label, required bool isAnnotated, required bool hasImage}) {
    final imageProvider = _getImageProvider();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Label header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: _greenHeader,
        child: Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.5)),
      ),

      // Image area
      Container(
        height: 280,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border.all(color: Colors.grey[400]!, width: 1),
        ),
        child: hasImage && imageProvider != null
            ? Stack(fit: StackFit.expand, children: [
                // Show actual image
                if (isAnnotated)
                  // ANALYZED: image with detection overlay
                  ClipRect(
                    child: CustomPaint(
                      foregroundPainter: DetectionOverlayPainter(
                        detections: result.detections,
                        imageWidth: result.imageWidth,
                        imageHeight: result.imageHeight,
                      ),
                      child: Image(
                        image: imageProvider,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  // ORIGINAL: plain image
                  ClipRect(
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.contain,
                    ),
                  ),

                // Colony count badge (on analyzed image)
                if (isAnnotated) Positioned(top: 8, right: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _greenHeader, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(1, 2))]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.biotech, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('${result.adjustedCount} CFU', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                )),

                // "ORIGINAL" watermark-style label
                if (!isAnnotated) Positioned(bottom: 8, left: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(3)),
                  child: Text('${result.imageWidth}x${result.imageHeight}px', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.white70)),
                )),
              ])
            // No image — show placeholder
            : Stack(fit: StackFit.expand, children: [
                Container(color: Colors.grey[100], child: Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_rounded, size: 48, color: _greenLight.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    Text('No image', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500])),
                  ],
                ))),
                if (isAnnotated) Positioned(top: 8, right: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _greenHeader, borderRadius: BorderRadius.circular(4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.biotech, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('${result.adjustedCount} CFU', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                )),
              ]),
      ),

      // Footer info
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        color: Colors.grey[100],
        child: Text(
          isAnnotated
            ? '${result.adjustedCount} colonies detected'
            : '${result.imageWidth}x${result.imageHeight}px',
          style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.grey[600]),
        ),
      ),
    ]);
  }

  Widget _buildDataTable() {
    final colonies = result.detections.where((d) => d.className == 'colony').toList();
    return Container(color: Colors.white, child: Table(
      columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(2.8), 2: FlexColumnWidth(2.2), 3: FlexColumnWidth(2.8)},
      children: [
        _greenRow('Sample ID', result.sampleId.isNotEmpty ? result.sampleId : result.id, 'Count', '${result.adjustedCount}'),
        _dataRow('Count (AI)', '${result.colonyCount}', 'Added/Removed', '+${result.added}/−${result.removed}'),
        _dataRow('Dilution', result.dilution.isNotEmpty ? result.dilution : '-', 'V (mL)', result.inoculumVolume.isNotEmpty ? result.inoculumVolume : '-'),
        _dataRow('CFU/mL', result.adjustedCfuPerMLLabel, 'Media Type', result.mediaType.isNotEmpty ? result.mediaType : '-'),
        _dataRow('Analyst', result.analystName.isNotEmpty ? result.analystName : '-', 'Sample Type', result.sampleType.isNotEmpty ? result.sampleType : '-'),
        _dataRow('min Ø (mm)', _minDiam(colonies), 'mean Ø (mm)', _meanDiam(colonies)),
        _dataRow('max Ø (mm)', _maxDiam(colonies), '', ''),
      ],
    ));
  }

  TableRow _greenRow(String l1, String v1, String l2, String v2) => TableRow(children: [
    _cell(l1, isLabel: true, isHeader: true), _cell(v1, isValue: true, isHeader: true),
    _cell(l2, isLabel: true, isHeader: true), _cell(v2, isValue: true, isHeader: true),
  ]);

  TableRow _dataRow(String l1, String v1, String l2, String v2) => TableRow(children: [
    _cell(l1, isLabel: true), _cell(v1, isValue: true),
    _cell(l2, isLabel: true), _cell(v2, isValue: true),
  ]);

  Widget _cell(String text, {bool isLabel = false, bool isValue = false, bool isHeader = false}) {
    Color bg; TextStyle s;
    if (isHeader && isLabel) { bg = _greenHeader; s = GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5); }
    else if (isHeader && isValue) { bg = _greenBg; s = GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _greenHeader); }
    else if (isLabel) { bg = _greenBg; s = GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w500, color: _greenLabel); }
    else { bg = Colors.white; s = GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87); }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, border: Border.all(color: Colors.grey[300]!, width: 0.5)),
      child: Text(text, style: s));
  }

  Widget _buildColonySizeSection() {
    final colonies = result.detections.where((d) => d.className == 'colony').toList();
    final small = colonies.where((c) => c.boxWidth < 20).length;
    final medium = colonies.where((c) => c.boxWidth >= 20 && c.boxWidth < 50).length;
    final large = colonies.where((c) => c.boxWidth >= 50).length;
    final total = colonies.length;
    return Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: _greenHeader,
        child: Text('COLONY SIZE DISTRIBUTION', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1))),
      const SizedBox(height: 8),
      if (colonies.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('No colony data', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)))
      else ...[
        _sizeBar('Small (<20px)', small, total, const Color(0xFF66BB6A)),
        const SizedBox(height: 4), _sizeBar('Medium (20-50px)', medium, total, const Color(0xFF43A047)),
        const SizedBox(height: 4), _sizeBar('Large (>50px)', large, total, const Color(0xFF2E7D32)),
      ],
    ]));
  }

  Widget _sizeBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(children: [
      SizedBox(width: 110, child: Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey[700]))),
      Expanded(child: Container(height: 12, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)),
        child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: pct, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)))))),
      const SizedBox(width: 8),
      SizedBox(width: 50, child: Text('$count (${(pct*100).toStringAsFixed(0)}%)', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: color))),
    ]);
  }

  Widget _buildClassificationSection() => Container(color: Colors.white, child: Table(
    columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(2.8), 2: FlexColumnWidth(2.2), 3: FlexColumnWidth(2.8)},
    children: [
      _greenRow('AI Model', result.modelVersion, 'Counted by', 'PlateVisionAI'),
      _dataRow('Date Time', _fmtDT(result.timestamp), 'Confidence', '${(result.averageConfidence*100).toStringAsFixed(1)}%'),
      _dataRow('Comment', _comment(), 'Plate Replicate', result.plateReplicate.isNotEmpty ? result.plateReplicate : '-'),
      _dataRow('Incubation', result.incubationTime.isNotEmpty ? '${result.incubationTime}h @ ${result.incubatorTemp}°C' : '-', 'Incubator ID', result.incubatorId.isNotEmpty ? result.incubatorId : '-'),
    ],
  ));

  Widget _buildReviewSection() => Container(color: Colors.white, child: Table(
    columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(2.8), 2: FlexColumnWidth(2.2), 3: FlexColumnWidth(2.8)},
    children: [
      _greenRow('Review signed by', '-', 'Date Time', '-'),
      _dataRow('Rejection signed by', 'N/A', 'Date Time', 'N/A'),
    ],
  ));

  Widget _buildFooter() => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.grey[100], child: Column(children: [
    Row(children: [
      Text('PlateVision AI, version ${AppConfig.appVersion}', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.grey[600])),
      const Spacer(),
      Text('Session: ${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.grey[600])),
    ]),
    const SizedBox(height: 4),
    Row(children: [
      Text('Model: ${result.modelVersion}', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.grey[600])),
      const Spacer(),
      Text('Generated on ${_fmtDT(DateTime.now())}', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.grey[600])),
      const SizedBox(width: 12),
      Text('1 / 1', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.grey[700])),
    ]),
  ]));

  Widget _buildBottomActions(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(color: AppColors.bgSecondary, border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1))),
    child: Row(children: [
      _actionBtn(Icons.picture_as_pdf_outlined, 'PDF', AppColors.error, () => _exportReportPdf(context)),
      const SizedBox(width: 8), _actionBtn(Icons.print_rounded, 'PRINT', _greenHeader, () => html.window.print()),
      const SizedBox(width: 8), _actionBtn(Icons.share_rounded, 'SHARE', AppColors.accentPrimary, () => _shareReport()),
      const Spacer(),
      _actionBtn(Icons.arrow_back_rounded, 'BACK', AppColors.textSecondary, () => Navigator.of(context).pop()),
    ]),
  );

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(6),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2), width: 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color), const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );

  // Calculations
  String _minDiam(List<DetectionResult> c) => c.isEmpty ? '0.00' : (c.map((d) => d.boxWidth).reduce(math.min)/10).toStringAsFixed(2);
  String _meanDiam(List<DetectionResult> c) => c.isEmpty ? '0.00' : (c.map((d) => d.boxWidth).reduce((a,b) => a+b)/c.length/10).toStringAsFixed(2);
  String _maxDiam(List<DetectionResult> c) => c.isEmpty ? '0.00' : (c.map((d) => d.boxWidth).reduce(math.max)/10).toStringAsFixed(2);
  String _comment() { if (result.adjustedCount == 0) return 'No colonies'; if (result.adjustedCount < 30) return 'TFTC'; if (result.adjustedCount <= 300) return 'OK'; return 'TNTC'; }
  String _fmtDT(DateTime dt) => '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';

  /// Capture a widget subtree as PNG bytes using its GlobalKey + RepaintBoundary.
  Future<Uint8List?> _captureWidgetImage(GlobalKey key, {double pixelRatio = 2.0}) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Export a native PDF (vector text + embedded plate images).
  Future<void> _exportReportPdf(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Menyiapkan dokumen PDF...', style: GoogleFonts.inter(fontSize: 12)),
        duration: const Duration(seconds: 2),
      ));

      // Allow the UI to settle before capturing images
      await Future.delayed(const Duration(milliseconds: 600));

      // Capture plate images from the widget tree (includes detection overlay)
      final origBytes = await _captureWidgetImage(_originalImageKey);
      final analBytes = await _captureWidgetImage(_analyzedImageKey);

      // ── Build native PDF ──
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          build: (_) => <pw.Widget>[
            _buildPdfHeader(),
            pw.SizedBox(height: 14),

            // Plate images side‑by‑side
            if (origBytes != null && analBytes != null) ...[
              _buildPdfPlateImages(origBytes, analBytes),
              pw.SizedBox(height: 14),
            ],

            // Sample data table
            _buildPdfSectionTitle('SAMPLE DATA'),
            pw.SizedBox(height: 6),
            _buildPdfDataTable(),
            pw.SizedBox(height: 14),

            // Colony size distribution
            _buildPdfSectionTitle('COLONY SIZE DISTRIBUTION'),
            pw.SizedBox(height: 6),
            _buildPdfColonyBars(),
            pw.SizedBox(height: 14),

            // Classification
            _buildPdfSectionTitle('CLASSIFICATION'),
            pw.SizedBox(height: 6),
            _buildPdfClassificationTable(),
            pw.SizedBox(height: 14),

            // Review signature
            _buildPdfSectionTitle('REVIEW'),
            pw.SizedBox(height: 6),
            _buildPdfReviewTable(),
            pw.SizedBox(height: 20),

            // Footer
            _buildPdfFooter(),
          ],
        ),
      );

      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'PlateVision_Report_${result.id}.pdf')
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal membuat PDF: $e', style: GoogleFonts.inter(fontSize: 12)),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // ==================================================================
  // Native PDF builder helpers (use package:pdf widgets directly)
  // ==================================================================

  pw.Widget _buildPdfHeader() {
    return pw.Row(children: [
      pw.Text('PLATE', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 22, fontWeight: pw.FontWeight.normal, color: PdfColors.green600, letterSpacing: 2)),
      pw.Text('VISION', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green800, letterSpacing: 2)),
      pw.Text(' AI', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 22, fontWeight: pw.FontWeight.normal, color: PdfColors.grey500, letterSpacing: 1)),
      pw.Spacer(),
      pw.Text('Colony Count Report', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
    ]);
  }

  pw.Widget _buildPdfSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: PdfColors.green800,
      child: pw.Text(title, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1)),
    );
  }

  pw.Widget _buildPdfPlateImages(Uint8List origBytes, Uint8List analBytes) {
    return pw.Row(children: [
      pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: PdfColors.green800,
          child: pw.Text('ORIGINAL', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1)),
        ),
        pw.Container(
          height: 200,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
          child: pw.Center(child: pw.Image(pw.MemoryImage(origBytes), fit: pw.BoxFit.contain)),
        ),
      ])),
      pw.SizedBox(width: 8),
      pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: PdfColors.green800,
          child: pw.Text('ANALYZED', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1)),
        ),
        pw.Container(
          height: 200,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
          child: pw.Center(child: pw.Image(pw.MemoryImage(analBytes), fit: pw.BoxFit.contain)),
        ),
      ])),
    ]);
  }

  pw.Widget _buildPdfDataTable() {
    final colonies = result.detections.where((d) => d.className == 'colony').toList();
    return pw.Table(
      columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(3)},
      children: [
        _pdfGreenRow('Sample ID', result.sampleId.isNotEmpty ? result.sampleId : result.id, 'Count', '${result.adjustedCount}'),
        _pdfDataRow('Count (AI)', '${result.colonyCount}', 'Added/Removed', '+${result.added}/−${result.removed}'),
        _pdfDataRow('Dilution', result.dilution.isNotEmpty ? result.dilution : '-', 'V (mL)', result.inoculumVolume.isNotEmpty ? result.inoculumVolume : '-'),
        _pdfDataRow('CFU/mL', result.adjustedCfuPerMLLabel, 'Media Type', result.mediaType.isNotEmpty ? result.mediaType : '-'),
        _pdfDataRow('Analyst', result.analystName.isNotEmpty ? result.analystName : '-', 'Sample Type', result.sampleType.isNotEmpty ? result.sampleType : '-'),
        _pdfDataRow('min Ø (mm)', _minDiam(colonies), 'mean Ø (mm)', _meanDiam(colonies)),
        _pdfDataRow('max Ø (mm)', _maxDiam(colonies), '', ''),
      ],
    );
  }

  pw.TableRow _pdfGreenRow(String l1, String v1, String l2, String v2) => pw.TableRow(children: [
    _pdfCell(l1, isLabel: true, isHeader: true),
    _pdfCell(v1, isValue: true, isHeader: true),
    _pdfCell(l2, isLabel: true, isHeader: true),
    _pdfCell(v2, isValue: true, isHeader: true),
  ]);

  pw.TableRow _pdfDataRow(String l1, String v1, String l2, String v2) => pw.TableRow(children: [
    _pdfCell(l1, isLabel: true),
    _pdfCell(v1, isValue: true),
    _pdfCell(l2, isLabel: true),
    _pdfCell(v2, isValue: true),
  ]);

  pw.Widget _pdfCell(String text, {bool isLabel = false, bool isValue = false, bool isHeader = false}) {
    final PdfColor? bg;
    final pw.TextStyle s;
    if (isHeader && isLabel) {
      bg = PdfColors.green800;
      s = pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    } else if (isHeader && isValue) {
      bg = PdfColors.green50;
      s = pw.TextStyle(font: pw.Font.courier(), fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800);
    } else if (isLabel) {
      bg = PdfColors.green50;
      s = pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, fontWeight: pw.FontWeight.normal, color: PdfColors.green800);
    } else {
      bg = PdfColors.white;
      s = pw.TextStyle(font: pw.Font.courier(), fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black);
    }
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(color: bg, border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Text(text, style: s),
    );
  }

  pw.Widget _buildPdfColonyBars() {
    final colonies = result.detections.where((d) => d.className == 'colony').toList();
    final small = colonies.where((c) => c.boxWidth < 20).length;
    final medium = colonies.where((c) => c.boxWidth >= 20 && c.boxWidth < 50).length;
    final large = colonies.where((c) => c.boxWidth >= 50).length;
    final total = colonies.length;

    if (colonies.isEmpty) {
      return pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('No colony data', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 9, color: PdfColors.grey500)));
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _pdfSizeBar('Small (<20px)', small, total, PdfColors.green400),
      pw.SizedBox(height: 3),
      _pdfSizeBar('Medium (20-50px)', medium, total, PdfColors.green600),
      pw.SizedBox(height: 3),
      _pdfSizeBar('Large (>50px)', large, total, PdfColors.green800),
    ]);
  }

  pw.Widget _pdfSizeBar(String label, int count, int total, PdfColor color) {
    final pct = total > 0 ? count / total : 0.0;
    final barFlex = (pct * 100).round().clamp(0, 100);
    final remainFlex = 100 - barFlex;
    return pw.Row(children: [
      pw.SizedBox(width: 100, child: pw.Text(label, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: PdfColors.grey700))),
      pw.Expanded(child: pw.Row(children: [
        pw.Expanded(flex: barFlex, child: pw.Container(height: 10, decoration: pw.BoxDecoration(color: color, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2))))),
        if (remainFlex > 0) pw.Expanded(flex: remainFlex, child: pw.Container(height: 10, decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2))))),
      ])),
      pw.SizedBox(width: 6),
      pw.SizedBox(width: 55, child: pw.Text('$count (${(pct*100).toStringAsFixed(0)}%)', style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8, fontWeight: pw.FontWeight.bold, color: color))),
    ]);
  }

  pw.Widget _buildPdfClassificationTable() {
    return pw.Table(
      columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(3)},
      children: [
        _pdfGreenRow('AI Model', result.modelVersion, 'Counted by', 'PlateVisionAI'),
        _pdfDataRow('Date Time', _fmtDT(result.timestamp), 'Confidence', '${(result.averageConfidence*100).toStringAsFixed(1)}%'),
        _pdfDataRow('Comment', _comment(), 'Plate Replicate', result.plateReplicate.isNotEmpty ? result.plateReplicate : '-'),
        _pdfDataRow('Incubation', result.incubationTime.isNotEmpty ? '${result.incubationTime}h @ ${result.incubatorTemp}°C' : '-', 'Incubator ID', result.incubatorId.isNotEmpty ? result.incubatorId : '-'),
      ],
    );
  }

  pw.Widget _buildPdfReviewTable() {
    return pw.Table(
      columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(3)},
      children: [
        _pdfGreenRow('Review signed by', '-', 'Date Time', '-'),
        _pdfDataRow('Rejection signed by', '-', 'Date Time', '-'),
      ],
    );
  }

  pw.Widget _buildPdfFooter() {
    final timestamp = DateTime.now();
    final sessionId = timestamp.millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return pw.Column(children: [
      pw.Row(children: [
        pw.Text('PlateVision AI, version ${AppConfig.appVersion}', style: pw.TextStyle(font: pw.Font.courier(), fontSize: 7, color: PdfColors.grey600)),
        pw.Spacer(),
        pw.Text('Session: $sessionId', style: pw.TextStyle(font: pw.Font.courier(), fontSize: 7, color: PdfColors.grey600)),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Text('Model: ${result.modelVersion}', style: pw.TextStyle(font: pw.Font.courier(), fontSize: 7, color: PdfColors.grey600)),
        pw.Spacer(),
        pw.Text('Generated on ${_fmtDT(timestamp)}', style: pw.TextStyle(font: pw.Font.courier(), fontSize: 7, color: PdfColors.grey600)),
      ]),
    ]);
  }

  void _shareReport() {
    html.window.navigator.clipboard?.writeText('PlateVisionAI Report\nSample: ${result.id}\nCount: ${result.adjustedCount} CFU\n${_comment()}\n${_fmtDT(result.timestamp)}');
  }
}
