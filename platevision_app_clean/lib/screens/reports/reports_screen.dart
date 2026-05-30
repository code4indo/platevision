import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/theme/app_theme.dart';
import 'package:platevision_ai/widgets/common/lab_button.dart';
import 'package:platevision_ai/widgets/common/lab_panel.dart';
import 'package:platevision_ai/widgets/common/lab_readout.dart';
import 'package:platevision_ai/widgets/common/lab_status_bar.dart';
import 'package:platevision_ai/models/detection_result.dart';
import 'package:platevision_ai/providers/analysis_provider.dart';
import 'package:platevision_ai/providers/dashboard_provider.dart';
import 'package:platevision_ai/screens/reports/interscience_report_screen.dart';
import 'package:provider/provider.dart';
import 'package:platevision_ai/widgets/common/app_scaffold.dart';

enum ReportType { daily, weekly, monthly, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportType _selectedReportType = ReportType.weekly;
  DateTimeRange? _customDateRange;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final analysisProvider = context.watch<AnalysisProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();

    return AppScaffold(
      currentIndex: 3,
      body: Container(
        color: AppColors.bgScaffold,
        child: SafeArea(
          child: Column(
            children: [
              // Status bar
              const LabStatusBar(
                connectionStatus: ConnectionStatus.online,
              ),

              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Report history (paling atas)
                      _buildReportHistory(analysisProvider),
                      const SizedBox(height: AppSpacing.lg),

                      // Report type selector
                      _buildReportTypeSelector(),
                      const SizedBox(height: AppSpacing.lg),

                      // Summary cards
                      _buildSummaryCards(dashboardProvider),
                      const SizedBox(height: AppSpacing.lg),

                      // Trend chart
                      _buildTrendChart(analysisProvider),
                      const SizedBox(height: AppSpacing.lg),

                      // Export buttons
                      _buildExportButtons(),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
          Expanded(
            child: Text(
              'REPORTS',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          AppTheme.buildLed(
            color: AppColors.statusOnline,
            isActive: true,
            size: AppSpacing.ledSize,
            label: _selectedReportType.name.toUpperCase(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    return LabPanel(
      title: 'REPORT PERIOD',
      icon: Icons.calendar_today_rounded,
      ledColor: AppColors.accentSecondary,
      ledActive: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: ReportType.values.map((type) {
              final isSelected = _selectedReportType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedReportType = type),
                  child: AnimatedContainer(
                    duration: AppSpacing.animationFast,
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentPrimary.withOpacity(0.12)
                          : AppColors.bgInput,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentPrimary.withOpacity(0.4)
                            : AppColors.borderSubtle,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        type.name.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: 1.0,
                          color: isSelected
                              ? AppColors.accentPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedReportType == ReportType.custom) ...[
            const SizedBox(height: AppSpacing.md),
            LabButton(
              label: _customDateRange != null
                  ? '${_formatDate(_customDateRange!.start)} - ${_formatDate(_customDateRange!.end)}'
                  : 'SELECT DATE RANGE',
              variant: LabButtonVariant.secondary,
              size: LabButtonSize.md,
              icon: Icons.date_range_rounded,
              onPressed: _selectDateRange,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: AppTheme.darkTheme,
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _customDateRange = picked);
    }
  }

  Widget _buildSummaryCards(DashboardProvider dashboardProvider) {
    final stats = _getRelevantStats(dashboardProvider);
    final totalSamples = stats.sampleSize;
    final avgColonies = stats.averageCount;
    final passRate = _calculatePassRate(stats);

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.6,
      children: [
        LabReadout(
          label: 'Total Samples',
          value: totalSamples.toString(),
          status: LabReadoutStatus.ok,
          size: LabReadoutSize.sm,
        ),
        LabReadout(
          label: 'Avg Colonies',
          value: avgColonies.toStringAsFixed(1),
          unit: 'CFU',
          status: avgColonies > AppConfig.colonyCountHigh
              ? LabReadoutStatus.warn
              : LabReadoutStatus.ok,
          size: LabReadoutSize.sm,
        ),
        LabReadout(
          label: 'Pass Rate',
          value: '${passRate.toStringAsFixed(0)}',
          unit: '%',
          status: passRate >= 80
              ? LabReadoutStatus.ok
              : passRate >= 50
                  ? LabReadoutStatus.warn
                  : LabReadoutStatus.err,
          size: LabReadoutSize.sm,
          color: passRate >= 80
              ? AppColors.success
              : passRate >= 50
                  ? AppColors.warning
                  : AppColors.error,
        ),
      ],
    );
  }

  ColonyStats _getRelevantStats(DashboardProvider dashboardProvider) {
    switch (_selectedReportType) {
      case ReportType.daily:
        return dashboardProvider.todayColonyStats;
      case ReportType.weekly:
        return dashboardProvider.weekColonyStats;
      case ReportType.monthly:
        return dashboardProvider.monthColonyStats;
      case ReportType.custom:
        return dashboardProvider.allTimeColonyStats;
    }
  }

  double _calculatePassRate(ColonyStats stats) {
    if (stats.sampleSize == 0) return 0.0;
    if (stats.averageCount <= AppConfig.colonyCountMedium) return 95.0;
    if (stats.averageCount <= AppConfig.colonyCountHigh) return 60.0;
    return 25.0;
  }

  Widget _buildTrendChart(AnalysisProvider analysisProvider) {
    final colonyCountsByDay = analysisProvider.getColonyCountsByDay(days: 7);
    final sortedDates = colonyCountsByDay.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(
        i.toDouble(),
        colonyCountsByDay[sortedDates[i]]!.toDouble(),
      ));
    }

    final maxY = spots.isEmpty
        ? 10.0
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2);

    return LabPanel(
      title: 'COLONY COUNT TREND',
      icon: Icons.show_chart_rounded,
      ledColor: AppColors.accentPrimary,
      ledActive: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: 240,
        child: spots.isEmpty
            ? _buildNoDataChart()
            : LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    drawHorizontalLine: true,
                    horizontalInterval: _calculateYAxisInterval(maxY),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.borderSubtle.withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sortedDates.length) {
                            return const SizedBox.shrink();
                          }
                          final date = sortedDates[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${date.day}/${date.month}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textMuted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: _calculateYAxisInterval(maxY),
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            value.toInt().toString(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              color: AppColors.textMuted,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                      left: BorderSide(
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                      top: BorderSide.none,
                      right: BorderSide.none,
                    ),
                  ),
                  minX: 0,
                  maxX: (sortedDates.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppColors.accentPrimary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.accentPrimary,
                            strokeWidth: 2,
                            strokeColor: AppColors.bgCard,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentPrimary.withOpacity(0.15),
                            AppColors.accentPrimary.withOpacity(0.02),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: AppSpacing.radiusSm,
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      getTooltipColor: (_) => AppColors.bgElevated,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toInt()} CFU',
                            GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentPrimary,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNoDataChart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 40,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'NO TREND DATA',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateYAxisInterval(double maxValue) {
    if (maxValue <= 0) return 1;
    if (maxValue <= 5) return 1;
    if (maxValue <= 20) return 5;
    if (maxValue <= 50) return 10;
    if (maxValue <= 100) return 20;
    if (maxValue <= 500) return 100;
    return 200;
  }

  Widget _buildExportButtons() {
    return LabPanel(
      title: 'EXPORT DATA',
      icon: Icons.file_download_rounded,
      ledColor: AppColors.warning,
      ledActive: true,
      accentColor: AppColors.warning,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _buildExportButton(
              icon: Icons.picture_as_pdf_rounded,
              label: 'PDF',
              color: AppColors.error,
              onTap: () => _showExportMessage('PDF'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _buildExportButton(
              icon: Icons.table_chart_rounded,
              label: 'EXCEL',
              color: AppColors.success,
              onTap: () => _showExportMessage('Excel'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _buildExportButton(
              icon: Icons.code_rounded,
              label: 'CSV',
              color: AppColors.info,
              onTap: () => _showExportMessage('CSV'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportMessage(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$format export will be available in a future update'),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // REPORT HISTORY — with delete functionality
  // ============================================================

  Widget _buildReportHistory(AnalysisProvider analysisProvider) {
    final history = analysisProvider.history;

    return LabPanel(
      title: 'REPORT HISTORY',
      icon: Icons.history_rounded,
      ledColor: AppColors.accentPrimary,
      ledActive: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      headerActions: history.isEmpty
          ? null
          : [
              if (_isSelectionMode) ...[
                // Delete selected button
                if (_selectedIds.isNotEmpty)
                  _buildActionChip(
                    icon: Icons.delete_sweep_rounded,
                    label: 'Hapus (${_selectedIds.length})',
                    color: AppColors.error,
                    onTap: () => _confirmDeleteSelected(analysisProvider),
                  ),
                if (_selectedIds.isNotEmpty)
                  const SizedBox(width: 4),
                // Select All toggle
                _buildActionChip(
                  icon: _selectedIds.length == history.length ? Icons.deselect_rounded : Icons.select_all_rounded,
                  label: _selectedIds.length == history.length ? 'Deselect' : 'All',
                  color: AppColors.accentSecondary,
                  onTap: () => setState(() {
                    if (_selectedIds.length == history.length) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.clear();
                      _selectedIds.addAll(history.map((a) => a.id));
                    }
                  }),
                ),
                const SizedBox(width: 4),
                // Select by Number
                _buildActionChip(
                  icon: Icons.pin_rounded,
                  label: 'No.',
                  color: AppColors.warning,
                  onTap: () => _showSelectByNumberDialog(history, analysisProvider),
                ),
                const SizedBox(width: 4),
                // Cancel selection
                _buildActionChip(
                  icon: Icons.close_rounded,
                  label: 'Batal',
                  color: AppColors.textTertiary,
                  onTap: () => setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  }),
                ),
              ] else ...[
                // Delete all button
                _buildActionChip(
                  icon: Icons.delete_forever_rounded,
                  label: 'Hapus Semua',
                  color: AppColors.error,
                  onTap: () => _confirmDeleteAll(analysisProvider),
                ),
                const SizedBox(width: 6),
                // Select mode toggle
                _buildActionChip(
                  icon: Icons.checklist_rounded,
                  label: 'Pilih',
                  color: AppColors.accentPrimary,
                  onTap: () => setState(() => _isSelectionMode = true),
                ),
              ],
            ],
      child: history.isEmpty
          ? _buildEmptyHistory()
          : Column(
              children: [
                // Header row
                _buildHistoryHeader(),
                const Divider(height: 1, color: AppColors.borderSubtle),
                ...history.take(10).toList().asMap().entries.map((entry) {
                  return _buildReportCard(entry.value, analysisProvider, index: entry.key);
                }),
              ],
            ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assessment_outlined,
              size: 32,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'NO REPORT DATA',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          const SizedBox(width: 22 + 6), // spacer for index badge
          Expanded(
            flex: 3,
            child: Text(
              'SAMPLE ID',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Text(
              'TYPE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Text(
              'PLATE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Text(
              'TIME',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 42,
            child: Text(
              'CONF',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 4 + 24), // spacer for delete icon
        ],
      ),
    );
  }

  Widget _buildReportCard(AnalysisResult analysis, AnalysisProvider analysisProvider, {int index = 0}) {
    final isSelected = _selectedIds.contains(analysis.id);

    return Dismissible(
      key: Key(analysis.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDeleteSingle(analysis),
      onDismissed: (direction) {
        analysisProvider.deleteAnalysis(analysis.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Riwayat ${analysis.sampleId.isNotEmpty ? analysis.sampleId : analysis.id.substring(0, 8)} dihapus'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 20),
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(analysis.id);
              } else {
                _selectedIds.add(analysis.id);
              }
            });
          } else {
            // Load the analysis result with image and navigate to analysis result screen
            analysisProvider.loadFromHistory(analysis);
            Navigator.of(context).pushNamed('/analysis_result');
          }
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm + 2,
          ),
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentPrimary.withOpacity(0.08)
                : AppColors.bgInput,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: isSelected
                ? Border.all(color: AppColors.accentPrimary.withOpacity(0.3))
                : null,
          ),
          child: Row(
            children: [
              // Index number badge
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.borderSubtle,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: _isSelectionMode
                    ? (isSelected
                        ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                        : Text('${index + 1}', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textTertiary)))
                    : Text('${index + 1}', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ),

              // ── Col 1: Sample ID ──
              Expanded(
                flex: 3,
                child: Text(
                  analysis.sampleId.isNotEmpty
                      ? analysis.sampleId
                      : analysis.id.substring(0, 8),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),

              // ── Col 2: Sample Type ──
              Expanded(
                flex: 2,
                child: Text(
                  analysis.sampleType.isNotEmpty
                      ? analysis.sampleType
                      : '-',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),

              // ── Col 3: Plate Number ──
              Expanded(
                flex: 2,
                child: Text(
                  analysis.plateReplicate.isNotEmpty
                      ? analysis.plateReplicate
                      : '-',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),

              // ── Col 4: Waktu ──
              Expanded(
                flex: 2,
                child: Text(
                  _formatDateTime(analysis.timestamp),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // ── Col 5: Avg Confidence ──
              Container(
                width: 42,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.accentPrimary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${(analysis.averageConfidence * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),

              // Delete icon (only when NOT in selection mode)
              if (!_isSelectionMode) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _confirmAndDeleteSingle(analysis, analysisProvider),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.analytics_outlined,
                  size: 16,
                  color: AppColors.accentPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DELETE CONFIRMATION DIALOGS
  // ============================================================

  /// Confirm and delete a single item immediately
  Future<void> _confirmAndDeleteSingle(AnalysisResult analysis, AnalysisProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        title: 'Hapus Riwayat',
        message: 'Hapus riwayat analisis ${analysis.sampleId.isNotEmpty ? '"${analysis.sampleId}"' : 'ini'}? Tindakan ini tidak dapat dibatalkan.',
        confirmLabel: 'HAPUS',
        confirmColor: AppColors.error,
      ),
    );

    if (confirmed == true && mounted) {
      await provider.deleteAnalysis(analysis.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Riwayat berhasil dihapus'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// ConfirmDismiss for swipe-to-delete
  Future<bool?> _confirmDeleteSingle(AnalysisResult analysis) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        title: 'Hapus Riwayat',
        message: 'Hapus riwayat analisis ${analysis.sampleId.isNotEmpty ? '"${analysis.sampleId}"' : 'ini'}? Tindakan ini tidak dapat dibatalkan.',
        confirmLabel: 'HAPUS',
        confirmColor: AppColors.error,
      ),
    );
  }

  /// Confirm delete all history
  Future<void> _confirmDeleteAll(AnalysisProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        title: 'Hapus Semua Riwayat',
        message: 'Hapus SELURUH riwayat analisis? Semua data akan hilang dan tidak dapat dikembalikan.',
        confirmLabel: 'HAPUS SEMUA',
        confirmColor: AppColors.error,
      ),
    );

    if (confirmed == true && mounted) {
      await provider.clearHistory();
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Semua riwayat berhasil dihapus'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Confirm delete selected items
  Future<void> _confirmDeleteSelected(AnalysisProvider provider) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        title: 'Hapus $count Riwayat Terpilih',
        message: 'Hapus $count riwayat analisis yang dipilih? Tindakan ini tidak dapat dibatalkan.',
        confirmLabel: 'HAPUS $count',
        confirmColor: AppColors.error,
      ),
    );

    if (confirmed == true && mounted) {
      for (final id in _selectedIds.toList()) {
        await provider.deleteAnalysis(id);
      }
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count riwayat berhasil dihapus'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Reusable confirmation dialog
  Widget _buildConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: confirmColor.withOpacity(0.3)),
      ),
      title: Row(children: [
        Icon(Icons.warning_amber_rounded, color: confirmColor, size: 22),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ]),
      content: Text(message, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('BATAL', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 0,
          ),
          child: Text(confirmLabel, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ),
      ],
    );
  }

  // ============================================================
  // SELECT BY NUMBER DIALOG
  // ============================================================

  /// Shows a dialog to select items by entering their numbers
  Future<void> _showSelectByNumberDialog(List<AnalysisResult> history, AnalysisProvider provider) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: AppColors.warning.withOpacity(0.3)),
        ),
        title: Row(children: [
          Icon(Icons.pin_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Text('Pilih Nomor', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan nomor urut riwayat yang ingin dipilih, pisahkan dengan koma.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Contoh: 1,3,5  atau  1-3  atau  1,2,4-6',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.jetBrainsMono(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '1,3,5 atau 1-3',
                hintStyle: GoogleFonts.jetBrainsMono(fontSize: 14, color: AppColors.textMuted.withOpacity(0.5)),
                filled: true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.warning, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: (value) => Navigator.of(ctx).pop(value),
            ),
            const SizedBox(height: 8),
            // Show available range
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 13, color: AppColors.info),
                const SizedBox(width: 6),
                Text(
                  'Tersedia: 1-${history.length}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.info),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('BATAL', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: Text('PILIH', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final indices = _parseNumberInput(result, history.length);
      if (indices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nomor tidak valid. Gunakan format: 1,3,5 atau 1-3'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      setState(() {
        for (final idx in indices) {
          if (idx >= 0 && idx < history.length) {
            _selectedIds.add(history[idx].id);
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${indices.length} item dipilih'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Parses number input string like "1,3,5" or "1-3" or "1,2,4-6"
  /// Returns list of 0-based indices
  List<int> _parseNumberInput(String input, int maxCount) {
    final indices = <int>[];
    final parts = input.split(',');

    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;

      if (part.contains('-')) {
        // Range like "1-3"
        final rangeParts = part.split('-');
        if (rangeParts.length != 2) continue;
        final start = int.tryParse(rangeParts[0].trim());
        final end = int.tryParse(rangeParts[1].trim());
        if (start == null || end == null) continue;
        for (var i = start; i <= end; i++) {
          if (i >= 1 && i <= maxCount) {
            indices.add(i - 1); // Convert to 0-based
          }
        }
      } else {
        // Single number like "3"
        final num = int.tryParse(part);
        if (num != null && num >= 1 && num <= maxCount) {
          indices.add(num - 1); // Convert to 0-based
        }
      }
    }

    return indices.toSet().toList()..sort();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month ${dt.year} $hour:$minute';
  }
}
