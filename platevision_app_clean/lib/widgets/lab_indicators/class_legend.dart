import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/config/app_config.dart';

/// Layout direction for the class legend.
enum ClassLegendLayout {
  horizontal,
  vertical,
}

/// Legend showing detection classes with colors, styled like lab instrument
/// mode indicators. Each class is shown as: color dot + class name + count.
class ClassLegend extends StatelessWidget {
  /// Map of class names to their detection counts.
  final Map<String, int> classCounts;

  /// Layout direction: horizontal or vertical.
  final ClassLegendLayout layout;

  /// Callback when a class item is tapped. Provides the class name.
  final ValueChanged<String>? onTap;

  /// Optional: currently selected class for highlight state.
  final String? selectedClass;

  const ClassLegend({
    super.key,
    required this.classCounts,
    this.layout = ClassLegendLayout.horizontal,
    this.onTap,
    this.selectedClass,
  });

  @override
  Widget build(BuildContext context) {
    final entries = classCounts.entries.toList();

    if (entries.isEmpty) {
      return _buildEmptyState();
    }

    if (layout == ClassLegendLayout.horizontal) {
      return _buildHorizontal(entries);
    } else {
      return _buildVertical(entries);
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        'NO DETECTIONS',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 2.0,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildHorizontal(List<MapEntry<String, int>> entries) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: entries.map((entry) => _buildClassItem(entry)).toList(),
    );
  }

  Widget _buildVertical(List<MapEntry<String, int>> entries) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: _buildClassItem(entry),
        );
      }).toList(),
    );
  }

  Widget _buildClassItem(MapEntry<String, int> entry) {
    final className = entry.key;
    final count = entry.value;
    final color = AppColors.getDetectionColor(className);
    final label = AppConfig.formatClassName(className);
    final isSelected = selectedClass == className;

    return GestureDetector(
      onTap: () => onTap?.call(className),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppSpacing.animationFast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.6)
                : color.withOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color dot with LED glow
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(isSelected ? 0.7 : 0.3),
                    blurRadius: isSelected ? 8 : 4,
                    spreadRadius: isSelected ? 1 : 0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),

            // Class name
            Text(
              label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 1.2,
                color: isSelected ? color : color.withOpacity(0.85),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),

            // Count badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
