import 'package:flutter/material.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/theme/app_typography.dart';

/// Clean button variants for PlateVisionAI.
enum LabButtonVariant { primary, secondary, danger, ghost }
enum LabButtonSize { sm, md, lg }

class LabButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final LabButtonVariant variant;
  final LabButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback? onPressed;

  const LabButton({
    super.key,
    required this.label,
    this.icon,
    this.variant = LabButtonVariant.primary,
    this.size = LabButtonSize.md,
    this.isLoading = false,
    this.isDisabled = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = switch (variant) {
      LabButtonVariant.primary => ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.disabledBackground,
          disabledForegroundColor: AppColors.disabled,
          padding: _padding,
          shape: _shape,
          textStyle: _textStyle,
        ),
      LabButtonVariant.secondary => OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          side: const BorderSide(color: AppColors.borderMedium),
          disabledForegroundColor: AppColors.disabled,
          padding: _padding,
          shape: _shape,
          textStyle: _textStyle,
        ),
      LabButtonVariant.danger => ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.disabledBackground,
          disabledForegroundColor: AppColors.disabled,
          padding: _padding,
          shape: _shape,
          textStyle: _textStyle,
        ),
      LabButtonVariant.ghost => TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          disabledForegroundColor: AppColors.disabled,
          padding: _padding,
          shape: _shape,
          textStyle: _textStyle,
        ),
    };

    final child = isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == LabButtonVariant.primary
                  ? Colors.white
                  : AppColors.accentPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: size == LabButtonSize.sm ? 14 : 16),
                AppSpacing.hXs,
              ],
              Text(label),
            ],
          );

    final effectiveOnPressed =
        (isLoading || isDisabled) ? null : onPressed;

    return switch (variant) {
      LabButtonVariant.primary => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: child,
        ),
      LabButtonVariant.secondary => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: child,
        ),
      LabButtonVariant.ghost => TextButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: child,
        ),
      LabButtonVariant.danger => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: child,
        ),
    };
  }

  EdgeInsets get _padding {
    if (size == LabButtonSize.sm) {
      return const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 4,
        vertical: AppSpacing.xs + 2,
      );
    }
    return const EdgeInsets.symmetric(
      horizontal: AppSpacing.md + 4,
      vertical: AppSpacing.sm + 4,
    );
  }

  RoundedRectangleBorder get _shape {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    );
  }

  TextStyle get _textStyle {
    return size == LabButtonSize.sm ? AppTypography.buttonSmall : AppTypography.button;
  }
}
