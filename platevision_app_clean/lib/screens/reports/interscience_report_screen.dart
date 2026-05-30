import 'dart:html' as html;
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/models/detection_result.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/providers/analysis_provider.dart';
import 'package:platevision_ai/widgets/lab_indicators/detection_overlay.dart';
import 'package:provider/provider.dart';

class InterscienceReportScreen extends StatelessWidget {
  final AnalysisResult result;
  const InterscienceReportScreen({super.key, required this.result});

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
          IconButton(icon: const Icon(Icons.download_rounded), onPressed: () => _exportReport(), tooltip: 'Export'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildReportPaper(),
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
    final hasImage = result.imagePath.isNotEmpty;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On narrow screens, stack vertically
          final isNarrow = constraints.maxWidth < 500;
          return Flex(
            direction: isNarrow ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isNarrow ? 0 : 1,
                child: _buildImageBox(label: 'ORIGINAL', isAnnotated: false, hasImage: hasImage),
              ),
              SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
              Expanded(
                flex: isNarrow ? 0 : 1,
                child: _buildImageBox(label: 'ANALYZED', isAnnotated: true, hasImage: hasImage),
              ),
            ],
          );
        },
      ),
    );
  }

  ImageProvider? _getImageProvider() {
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
                    child: DetectionOverlay(
                      imageProvider: imageProvider,
                      detections: result.detections,
                      showConfidence: true,
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
                    Text('${result.colonyCount} CFU', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
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
                    Text('${result.colonyCount} CFU', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
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
            ? '${result.colonyCount} colonies detected - ${result.totalDetections} objects'
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
        _greenRow('Sample ID', result.id, 'Count', '${result.colonyCount}'),
        _dataRow('Added', '0', 'Removed', '0'),
        _dataRow('Dilution', '1', 'V (mL)', '1.000000'),
        _dataRow('CFU/mL', _cfuML(), 'Area (%)', '100.000000'),
        _dataRow('CFU Prorata', result.colonyCount > 0 && result.colonyCount < 30 ? 'TFTC' : 'N/A', 'min CFU O (mm)', _minDiam(colonies)),
        _dataRow('mean CFU O (mm)', _meanDiam(colonies), 'max CFU O (mm)', _maxDiam(colonies)),
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
      _greenRow('Color Classification', 'N/A', 'Parameters', 'Total Count AI'),
      _dataRow('Sensitivity', 'N/A', 'Limitation O UFC', '0.00 i-'),
      _dataRow('AI Model', result.modelVersion, 'Counted by', 'PlateVisionAI'),
      _dataRow('Date Time', _fmtDT(result.timestamp), 'Media Type', 'PCA'),
      _dataRow('Comment', _comment(), 'Confidence', '${(result.averageConfidence*100).toStringAsFixed(1)}%'),
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
      _actionBtn(Icons.picture_as_pdf_outlined, 'PDF', AppColors.error, () => _exportReport()),
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
  String _cfuML() { if (result.colonyCount == 0) return '0'; final cfu = result.colonyCount.toDouble(); final exp = (math.log(cfu)/math.ln10).floor(); final m = cfu/math.pow(10, exp); return '${m.toStringAsFixed(3)}E+${exp.toString().padLeft(2,'0')}'; }
  String _minDiam(List<DetectionResult> c) => c.isEmpty ? '0.00' : (c.map((d) => d.boxWidth).reduce(math.min)/10).toStringAsFixed(2);
  String _meanDiam(List<DetectionResult> c) => c.isEmpty ? '0.00' : (c.map((d) => d.boxWidth).reduce((a,b) => a+b)/c.length/10).toStringAsFixed(2);
  String _maxDiam(List<DetectionResult> c) => c.isEmpty ? '0.00' : (c.map((d) => d.boxWidth).reduce(math.max)/10).toStringAsFixed(2);
  String _comment() { if (result.colonyCount == 0) return 'No colonies'; if (result.colonyCount < 30) return 'TFTC'; if (result.colonyCount <= 300) return 'OK'; return 'TNTC'; }
  String _fmtDT(DateTime dt) => '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';

  void _exportReport() {
    final b = StringBuffer();
    b.writeln('PLATEVISION AI - Colony Count Report');
    b.writeln('Sample ID: ${result.id}');
    b.writeln('Count: ${result.colonyCount}');
    b.writeln('CFU/mL: ${_cfuML()}');
    b.writeln('Date: ${_fmtDT(result.timestamp)}');
    b.writeln('Model: ${result.modelVersion}');
    b.writeln('Comment: ${_comment()}');
    final blob = html.Blob([b.toString()], 'text/plain');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)..setAttribute('download', 'platevision_report_${result.id}.txt')..click();
    html.Url.revokeObjectUrl(url);
  }

  void _shareReport() {
    html.window.navigator.clipboard?.writeText('PlateVisionAI Report\nSample: ${result.id}\nCount: ${result.colonyCount} CFU\n${_comment()}\n${_fmtDT(result.timestamp)}');
  }
}
