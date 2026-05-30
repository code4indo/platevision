import 'package:flutter/material.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_typography.dart';
import 'package:platevision_ai/theme/app_spacing.dart';

/// Clean readout card — shows a label, value, and optional unit.
///
/// Professional, minimal — no badges, no LEDs, just data.

/// Legacy status enum — kept for backward compatibility.
enum LabReadoutStatus { ok, warn, err }

/// Legacy size enum — kept for backward compatibility.
enum LabReadoutSize { sm, md, lg }

class LabReadout extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;
  final IconData? icon;
  final Color? accentColor;

  // Deprecated legacy params
  final LabReadoutStatus? status;
  final Color? color;
  final LabReadoutSize size;

  const LabReadout({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    this.icon,
    this.accentColor,
    // Deprecated
    this.status,
    this.color,
    this.size = LabReadoutSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? AppColors.accentPrimary;
    final effectiveValueColor = valueColor ?? AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Label row
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: effectiveAccent),
                AppSpacing.hXs,
              ],
              Text(label.toUpperCase(), style: AppTypography.dataLabel),
            ],
          ),
          AppSpacing.vXs,
          // Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppTypography.dataMedium.copyWith(
                color: effectiveValueColor,
              )),
              if (unit != null) ...[
                AppSpacing.hXs,
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit!, style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  )),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
