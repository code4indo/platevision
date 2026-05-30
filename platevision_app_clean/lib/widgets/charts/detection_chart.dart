import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/config/app_config.dart';

/// Bar chart for detection class distribution, styled with the lab
/// instrument dark theme. Uses fl_chart with teal/cyan gradient bars,
/// Indonesian labels, animated entry, and class counts with percentages.
class DetectionChart extends StatefulWidget {
  /// Map of class names to their detection counts.
  final Map<String, int> classCounts;

  /// Whether to animate the chart entry.
  final bool animated;

  /// Chart height. Defaults to 220.
  final double height;

  /// Optional callback when a bar is tapped. Provides the class name.
  final ValueChanged<String>? onBarTap;

  const DetectionChart({
    super.key,
    required this.classCounts,
    this.animated = true,
    this.height = 220,
    this.onBarTap,
  });

  @override
  State<DetectionChart> createState() => _DetectionChartState();
}

class _DetectionChartState extends State<DetectionChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    if (widget.animated) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant DetectionChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classCounts != widget.classCounts && widget.animated) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<_ChartEntry> get _entries {
    final total = widget.classCounts.values.fold<int>(0, (a, b) => a + b);
    final entries = <_ChartEntry>[];

    // Use a fixed order based on AppConfig.detectionClasses
    for (final className in AppConfig.detectionClasses) {
      final count = widget.classCounts[className] ?? 0;
      if (count > 0) {
        final percentage = total > 0 ? (count / total * 100) : 0.0;
        entries.add(_ChartEntry(
          className: className,
          label: AppConfig.formatClassName(className),
          count: count,
          percentage: percentage,
          color: AppColors.getDetectionColor(className),
        ));
      }
    }

    // Add any additional classes not in the standard set
    for (final entry in widget.classCounts.entries) {
      if (!AppConfig.detectionClasses.contains(entry.key) && entry.value > 0) {
        final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
        entries.add(_ChartEntry(
          className: entry.key,
          label: AppConfig.formatClassName(entry.key),
          count: entry.value,
          percentage: percentage,
          color: AppColors.getDetectionColor(entry.key),
        ));
      }
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;

    if (entries.isEmpty) {
      return _buildEmptyState();
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: Column(
            children: [
              // Chart area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: AppSpacing.md,
                    bottom: AppSpacing.xs,
                  ),
                  child: BarChart(
                    _buildChartData(entries),
                    duration: widget.animated
                        ? AppSpacing.animationNormal
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),

              // Legend / stats row
              const SizedBox(height: AppSpacing.xs),
              _buildStatsRow(entries),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: widget.height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'NO DATA',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartData _buildChartData(List<_ChartEntry> entries) {
    final maxValue = entries
        .map((e) => e.count.toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxValue > 0 ? (maxValue * 1.2) : 10,
      barTouchData: BarTouchData(
        enabled: true,
        touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
          if (response != null && response.spot != null) {
            final touchedBarIndex = response.spot!.touchedBarGroupIndex;
            if (touchedBarIndex >= 0 && touchedBarIndex < entries.length) {
              if (event is FlTapUpEvent) {
                widget.onBarTap?.call(entries[touchedBarIndex].className);
              }
            }
          }
          setState(() {
            _touchedIndex = response?.spot?.touchedBarGroupIndex ?? -1;
          });
        },
        handleBuiltInTouches: true,
        touchTooltipData: BarTouchTooltipData(
          tooltipRoundedRadius: AppSpacing.radiusSm,
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          tooltipMargin: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            if (groupIndex >= entries.length) return null;
            final entry = entries[groupIndex];
            return BarTooltipItem(
              '${entry.label}\n${entry.count} (${entry.percentage.toStringAsFixed(1)}%)',
              GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
                height: 1.4,
              ),
            );
          },
          getTooltipColor: (_) => AppColors.bgElevated,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= entries.length) {
                return const SizedBox.shrink();
              }
              final entry = entries[index];
              final isTouched = index == _touchedIndex;
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
                child: Text(
                  entry.label.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: isTouched ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 1.0,
                    color: isTouched
                        ? entry.color
                        : AppColors.textTertiary,
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
            interval: _calculateYAxisInterval(maxValue),
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox.shrink();
              return Text(
                value.toInt().toString(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
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
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        drawHorizontalLine: true,
        horizontalInterval: _calculateYAxisInterval(maxValue),
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppColors.borderSubtle.withOpacity(0.5),
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
      ),
      barGroups: _buildBarGroups(entries),
    );
  }

  List<BarChartGroupData> _buildBarGroups(List<_ChartEntry> entries) {
    return entries.asMap().entries.map((mapEntry) {
      final index = mapEntry.key;
      final entry = mapEntry.value;
      final isTouched = index == _touchedIndex;
      final animValue = _animation.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.count.toDouble() * animValue,
            fromY: 0,
            width: _barWidth(entries.length),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppSpacing.radiusXs),
              topRight: Radius.circular(AppSpacing.radiusXs),
            ),
            gradient: LinearGradient(
              colors: [
                entry.color,
                entry.color.withOpacity(0.6),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),

          ),
        ],
        showingTooltipIndicators: isTouched ? [0] : [],
      );
    }).toList();
  }

  double _barWidth(int count) {
    if (count <= 2) return 32;
    if (count <= 4) return 24;
    if (count <= 6) return 18;
    return 14;
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

  Widget _buildStatsRow(List<_ChartEntry> entries) {
    final total = entries.fold<int>(0, (sum, e) => sum + e.count);

    return Row(
      children: [
        // Total count
        Text(
          'TOTAL: $total',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),

        // Per-class mini indicators
        ...entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${entry.count}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: entry.color,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ChartEntry {
  final String className;
  final String label;
  final int count;
  final double percentage;
  final Color color;

  const _ChartEntry({
    required this.className,
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
  });
}
