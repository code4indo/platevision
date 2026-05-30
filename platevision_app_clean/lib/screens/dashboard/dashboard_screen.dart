import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:google_fonts/google_fonts.dart';
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/theme/app_typography.dart';
import 'package:platevision_ai/theme/app_responsive.dart';
import 'package:platevision_ai/widgets/common/lab_button.dart';
import 'package:platevision_ai/widgets/common/lab_panel.dart';
import 'package:platevision_ai/widgets/common/lab_status_bar.dart';
import 'package:platevision_ai/widgets/charts/detection_chart.dart';
import 'package:platevision_ai/widgets/lab_indicators/class_legend.dart';
import 'package:platevision_ai/providers/analysis_provider.dart';
import 'package:platevision_ai/providers/auth_provider.dart';
import 'package:platevision_ai/providers/dashboard_provider.dart';
import 'package:provider/provider.dart';
import 'package:platevision_ai/widgets/common/app_scaffold.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  Future<void> _refreshData() async {
    final dp = context.read<DashboardProvider>();
    final ap = context.read<AnalysisProvider>();
    dp.updateAnalysisHistory(ap.history);
    await dp.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();
    final analysisProvider = context.watch<AnalysisProvider>();

    return AppScaffold(
      currentIndex: 0,
      body: Container(
        color: AppColors.bgScaffold,
        child: SafeArea(
          child: Column(
            children: [
              LabStatusBar(
                connectionStatus: dashboardProvider.isSystemOperational
                    ? ConnectionStatus.online
                    : ConnectionStatus.offline,
              ),
              Expanded(
                child: RefreshIndicator(
                  key: _refreshKey,
                  color: AppColors.accentPrimary,
                  backgroundColor: AppColors.bgCard,
                  onRefresh: _refreshData,
                  child: _buildDashboardPage(dashboardProvider, analysisProvider, authProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // ============================================================
  // DASHBOARD — INTERSCIENCE INSTRUMENT STYLE
  // Dense, compact, information-rich. No big boxes for 1 number.
  // ============================================================

  Widget _buildDashboardPage(DashboardProvider dp, AnalysisProvider ap, AuthProvider auth) {
    final isDesktop = Responsive.isDesktop(context);
    final hPad = Responsive.horizontalPadding(context);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Instrument header bar ──
          _buildInstrumentHeader(dp, auth),
          const SizedBox(height: 6),

          // ── Row 2: Stats strip (all key metrics in ONE row) ──
          _buildStatsStrip(dp),
          const SizedBox(height: 6),

          // ── Row 3: QC alerts (if any) ──
          if (dp.hasQcAlerts) ...[
            _buildCompactAlerts(dp),
            const SizedBox(height: 6),
          ],

          // ── Row 4+: Main content area ──
          if (isDesktop)
            _buildDesktopLayout(dp)
          else
            _buildMobileLayout(dp),
        ],
      ),
    );
  }

  // ============================================================
  // Instrument Header — single compact line
  // ============================================================

  Widget _buildInstrumentHeader(DashboardProvider dp, AuthProvider auth) {
    final user = auth.currentUser;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          // App name
          Text('PLATEVISION', style: GoogleFonts.jetBrainsMono(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.accentPrimary, letterSpacing: 1.5,
          )),
          Text(' AI', style: GoogleFonts.jetBrainsMono(
            fontSize: 11, fontWeight: FontWeight.w400,
            color: AppColors.textTertiary,
          )),
          const SizedBox(width: 12),
          // Divider
          Container(width: 1, height: 14, color: AppColors.borderSubtle),
          const SizedBox(width: 12),
          // User
          Text('${user?.fullName ?? "User"}', style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          )),
          const Spacer(),
          // Model version
          _buildHeaderBadge('YOLOv8-v4', AppColors.accentDim),
          const SizedBox(width: 8),
          // System status
          _buildHeaderBadge(
            dp.isSystemOperational ? 'ONLINE' : 'OFFLINE',
            dp.isSystemOperational ? AppColors.statusOnline : AppColors.statusOffline,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(text, style: GoogleFonts.jetBrainsMono(
        fontSize: 9, fontWeight: FontWeight.w600, color: color,
      )),
    );
  }

  // ============================================================
  // Stats Strip — ALL key numbers in ONE horizontal strip
  // No big boxes. Each stat = icon + label + value inline.
  // ============================================================

  Widget _buildStatsStrip(DashboardProvider dp) {
    final todayStats = dp.todayColonyStats;
    final avgConf = dp.averageConfidence;
    final systemOk = dp.isSystemOperational;
    final backendTotal = dp.backendTotalAnalyses;
    final localTotal = dp.totalAnalysisCount;
    final showBackend = backendTotal > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _buildStatChip(
            icon: Icons.analytics_outlined,
            label: 'ANALYZED',
            value: showBackend ? backendTotal.toString() : localTotal.toString(),
            color: AppColors.accentPrimary,
          ),
          _buildStatChip(
            icon: Icons.biotech_outlined,
            label: 'COLONIES',
            value: '${dp.totalColonyCount}',
            unit: 'CFU',
            color: todayStats.totalCount > AppConfig.colonyCountHigh
                ? AppColors.statusWarning
                : AppColors.colonyColor,
          ),
          _buildStatChip(
            icon: Icons.biotech_outlined,
            label: 'TODAY',
            value: '${todayStats.totalCount}',
            unit: 'CFU',
            color: AppColors.accentSecondary,
          ),
          _buildStatChip(
            icon: Icons.trending_up_rounded,
            label: 'TREND',
            value: todayStats.trendPercentage,
            color: todayStats.trend == 'up' ? AppColors.statusWarning
                : todayStats.trend == 'down' ? AppColors.statusOnline
                : AppColors.textTertiary,
          ),
          _buildStatChip(
            icon: Icons.speed_outlined,
            label: 'CONF',
            value: '${(avgConf * 100).toStringAsFixed(1)}',
            unit: '%',
            color: avgConf >= 0.80 ? AppColors.statusOnline
                : avgConf >= 0.50 ? AppColors.statusWarning
                : AppColors.statusOffline,
          ),
          _buildStatChip(
            icon: Icons.timer_outlined,
            label: 'AVG TIME',
            value: dp.formattedAverageProcessingTime,
            color: AppColors.info,
          ),
          _buildStatChip(
            icon: Icons.dns_outlined,
            label: 'SYSTEM',
            value: systemOk ? 'OK' : 'DOWN',
            color: systemOk ? AppColors.statusOnline : AppColors.statusOffline,
          ),
        ],
      ),
    );
  }

  /// Compact stat chip: [icon LABEL value unit] — all in one line
  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    String? unit,
    Color color = AppColors.accentPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.jetBrainsMono(
            fontSize: 8, fontWeight: FontWeight.w500,
            color: AppColors.textTertiary, letterSpacing: 0.8,
          )),
          const SizedBox(width: 5),
          Text(value, style: GoogleFonts.jetBrainsMono(
            fontSize: 12, fontWeight: FontWeight.w700, color: color,
          )),
          if (unit != null) ...[
            const SizedBox(width: 2),
            Text(unit, style: GoogleFonts.inter(
              fontSize: 8, fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            )),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // Compact QC Alerts
  // ============================================================

  Widget _buildCompactAlerts(DashboardProvider dp) {
    final alerts = dp.qcAlerts.where((a) => a.type != QcAlertType.info).toList();
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.statusWarning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.statusWarning.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.statusWarning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              alerts.map((a) => a.title).join(' | '),
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.statusWarning),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Desktop Layout — 3 columns: Left(Chart) | Mid(Confidence+Class) | Right(System+Activity)
  // ============================================================

  Widget _buildDesktopLayout(DashboardProvider dp) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT: Colony Counter + Chart
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildColonyCounterPanel(dp),
              const SizedBox(height: 6),
              _buildChartPanel(dp),
            ],
          ),
        ),
        const SizedBox(width: 6),

        // MIDDLE: Confidence + Class breakdown
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildConfidencePanel(dp),
              const SizedBox(height: 6),
              _buildClassBreakdownPanel(dp),
            ],
          ),
        ),
        const SizedBox(width: 6),

        // RIGHT: System + Performance + Activity
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildSystemPanel(dp),
              const SizedBox(height: 6),
              _buildPerformancePanel(dp),
              const SizedBox(height: 6),
              _buildActivityPanel(dp),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Mobile Layout — single column
  // ============================================================

  Widget _buildMobileLayout(DashboardProvider dp) {
    return Column(
      children: [
        _buildColonyCounterPanel(dp),
        const SizedBox(height: 6),
        _buildChartPanel(dp),
        const SizedBox(height: 6),
        _buildConfidencePanel(dp),
        const SizedBox(height: 6),
        _buildSystemPanel(dp),
        const SizedBox(height: 6),
        _buildActivityPanel(dp),
      ],
    );
  }

  // ============================================================
  // Colony Counter Panel — compact, instrument-style
  // ============================================================

  Widget _buildColonyCounterPanel(DashboardProvider dp) {
    final todayStats = dp.todayColonyStats;
    // Determine TFTC/IDEAL/TNTC
    String status;
    Color statusColor;
    if (todayStats.totalCount == 0) {
      status = 'NO DATA';
      statusColor = AppColors.textTertiary;
    } else if (todayStats.totalCount < 30) {
      status = 'TFTC';
      statusColor = AppColors.statusWarning;
    } else if (todayStats.totalCount <= 300) {
      status = 'IDEAL';
      statusColor = AppColors.statusOnline;
    } else {
      status = 'TNTC';
      statusColor = AppColors.statusOffline;
    }

    return LabPanel(
      title: "TODAY'S COUNT",
      icon: Icons.biotech_outlined,
      child: Row(
        children: [
          // Big number + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${todayStats.totalCount}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 36, fontWeight: FontWeight.w800,
                        color: AppColors.accentPrimary, height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('CFU', style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      )),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(status, style: GoogleFonts.jetBrainsMono(
                          fontSize: 9, fontWeight: FontWeight.w700, color: statusColor,
                        )),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Sub-stats row
                Row(
                  children: [
                    _buildInlineStat('Samples', '${todayStats.sampleSize}'),
                    const SizedBox(width: 12),
                    _buildInlineStat('Average', todayStats.averageCount.toStringAsFixed(1)),
                    const SizedBox(width: 12),
                    _buildInlineStat('Max', '${todayStats.maxCount}'),
                    const SizedBox(width: 12),
                    _buildInlineStat('Trend', todayStats.trendPercentage),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.inter(
          fontSize: 9, fontWeight: FontWeight.w400,
          color: AppColors.textTertiary,
        )),
        const SizedBox(width: 3),
        Text(value, style: GoogleFonts.jetBrainsMono(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        )),
      ],
    );
  }

  // ============================================================
  // Chart Panel
  // ============================================================

  Widget _buildChartPanel(DashboardProvider dp) {
    return LabPanel(
      title: 'CLASS DISTRIBUTION',
      icon: Icons.bar_chart_outlined,
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: DetectionChart(
              classCounts: dp.classDistribution,
              animated: true,
              height: 140,
              onBarTap: (className) {},
            ),
          ),
          const SizedBox(height: 4),
          ClassLegend(
            classCounts: dp.classDistribution,
            layout: ClassLegendLayout.horizontal,
            selectedClass: null,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Confidence Panel — compact bars
  // ============================================================

  Widget _buildConfidencePanel(DashboardProvider dp) {
    final confDist = dp.confidenceDistribution;
    final total = confDist.values.fold<int>(0, (s, v) => s + v);

    return LabPanel(
      title: 'CONFIDENCE',
      icon: Icons.speed_outlined,
      child: Column(
        children: [
          if (total == 0)
            Center(child: Text('No data', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textTertiary)))
          else ...[
            _buildConfRow('HIGH >=80%', confDist['high'] ?? 0, total, AppColors.statusOnline),
            const SizedBox(height: 3),
            _buildConfRow('MED 50-79%', confDist['medium'] ?? 0, total, AppColors.statusWarning),
            const SizedBox(height: 3),
            _buildConfRow('LOW <50%', confDist['low'] ?? 0, total, AppColors.statusOffline),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('AVG ', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textTertiary)),
                Text(dp.formattedAverageConfidence, style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentPrimary,
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: GoogleFonts.jetBrainsMono(
          fontSize: 8, fontWeight: FontWeight.w500, color: AppColors.textTertiary,
        ))),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(2)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(width: 40, child: Text('${count} (${(pct*100).toStringAsFixed(0)}%)',
          style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w600, color: color),
          textAlign: TextAlign.right,
        )),
      ],
    );
  }

  // ============================================================
  // Class Breakdown Panel — inline rows
  // ============================================================

  Widget _buildClassBreakdownPanel(DashboardProvider dp) {
    final classDist = dp.classDistribution;
    final classColors = {
      'colony': AppColors.colonyColor,
      'bubble': AppColors.bubbleColor,
      'dust': AppColors.dustColor,
      'crack': AppColors.crackColor,
    };

    return LabPanel(
      title: 'DETECTIONS',
      icon: Icons.category_outlined,
      child: Column(
        children: classDist.entries.map((e) {
          final color = classColors[e.key.toLowerCase()] ?? AppColors.accentPrimary;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(width: 3, height: 12, decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(1),
                )),
                const SizedBox(width: 6),
                Text(e.key.toUpperCase(), style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
                )),
                const Spacer(),
                Text('${e.value}', style: GoogleFonts.jetBrainsMono(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color,
                )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // System Panel — compact key-value rows
  // ============================================================

  Widget _buildSystemPanel(DashboardProvider dp) {
    final status = dp.systemStatus;
    return LabPanel(
      title: 'SYSTEM',
      icon: Icons.dns_outlined,
      child: Column(
        children: [
          _buildKVRow('API', status.apiOnline ? 'Online' : 'Offline',
            status.apiOnline ? AppColors.statusOnline : AppColors.statusOffline, dot: true),
          _buildKVRow('Model', status.modelVersion, AppColors.textSecondary),
          _buildKVRow('Response',
            status.apiResponseTime != null ? '${status.apiResponseTime!.inMilliseconds}ms' : '--',
            status.apiResponseTime != null && status.apiResponseTime!.inMilliseconds < 500
                ? AppColors.statusOnline : AppColors.statusWarning),
          _buildKVRow('Uptime', _calculateUptime(), AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildKVRow(String key, String value, Color valueColor, {bool dot = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (dot) ...[
            Container(width: 5, height: 5, decoration: BoxDecoration(
              color: valueColor, shape: BoxShape.circle,
            )),
            const SizedBox(width: 4),
          ],
          Text(key, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textTertiary)),
          const Spacer(),
          Text(value, style: GoogleFonts.jetBrainsMono(
            fontSize: 10, fontWeight: FontWeight.w600, color: valueColor,
          )),
        ],
      ),
    );
  }

  // ============================================================
  // Performance Panel
  // ============================================================

  Widget _buildPerformancePanel(DashboardProvider dp) {
    return LabPanel(
      title: 'PERFORMANCE',
      icon: Icons.timer_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildPerfCell('AVG', dp.formattedAverageProcessingTime)),
              const SizedBox(width: 4),
              Expanded(child: _buildPerfCell('FAST',
                dp.minProcessingTimeMs > 0 ? '${dp.minProcessingTimeMs.toStringAsFixed(0)}ms' : '--')),
              const SizedBox(width: 4),
              Expanded(child: _buildPerfCell('SLOW',
                dp.maxProcessingTimeMs > 0 ? '${dp.maxProcessingTimeMs.toStringAsFixed(0)}ms' : '--')),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: LabButton(
              label: 'EXPORT CSV',
              variant: LabButtonVariant.secondary,
              size: LabButtonSize.sm,
              icon: Icons.file_download_outlined,
              onPressed: () => _exportCsv(dp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCardAlt,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.jetBrainsMono(
            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          )),
          Text(label, style: GoogleFonts.inter(
            fontSize: 8, fontWeight: FontWeight.w500, color: AppColors.textTertiary,
          )),
        ],
      ),
    );
  }

  // ============================================================
  // Activity Panel — compact list
  // ============================================================

  Widget _buildActivityPanel(DashboardProvider dp) {
    final activities = dp.recentActivity;
    return LabPanel(
      title: 'ACTIVITY',
      icon: Icons.history_outlined,
      child: activities.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No activity yet', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textTertiary)),
            ))
          : Column(
              children: activities.take(5).map((a) => _buildActivityRow(a)).toList(),
            ),
    );
  }

  Widget _buildActivityRow(ActivityItem activity) {
    final iconColor = _getActivityColor(activity.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(_getActivityIcon(activity.type), size: 12, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(activity.title,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(activity.timeAgo, style: GoogleFonts.jetBrainsMono(
            fontSize: 8, color: AppColors.textTertiary,
          )),
        ],
      ),
    );
  }

  // ============================================================
  // Helpers
  // ============================================================

  void _exportCsv(DashboardProvider dp) {
    final buf = StringBuffer();
    buf.writeln('PlateVisionAI - Analysis Report');
    buf.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buf.writeln('Total Analyses: ${dp.totalAnalysisCount}');
    buf.writeln('Total Colonies: ${dp.totalColonyCount}');
    buf.writeln('');
    buf.writeln('ID,Timestamp,Colonies,Total Objects,Processing Time (ms),Avg Confidence');
    final analyses = context.read<AnalysisProvider>().history;
    for (final a in analyses) {
      buf.writeln('${a.id},${a.timestamp.toIso8601String()},${a.colonyCount},${a.totalDetections},${a.processingTime.inMilliseconds},${(a.averageConfidence * 100).toStringAsFixed(1)}%');
    }
    final blob = html.Blob([buf.toString()], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'platevision_report_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'analysis': return Icons.analytics_rounded;
      case 'review': return Icons.rate_review_rounded;
      case 'approval': return Icons.check_circle_outline_rounded;
      case 'system': return Icons.dns_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'analysis': return AppColors.accentPrimary;
      case 'review': return AppColors.info;
      case 'approval': return AppColors.success;
      case 'system': return AppColors.warning;
      default: return AppColors.textTertiary;
    }
  }

  String _calculateUptime() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final uptime = now.difference(startOfDay);
    return '${uptime.inHours.toString().padLeft(2,'0')}:${(uptime.inMinutes % 60).toString().padLeft(2,'0')}h';
  }


}
