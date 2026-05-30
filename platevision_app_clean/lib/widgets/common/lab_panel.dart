import 'package:flutter/material.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_typography.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/theme/app_theme.dart';

/// A clean card container for dashboard content.
///
/// Professional — no LEDs, no accent bars, no inner shadows.
/// Just clean content presentation with an optional header.
class LabPanel extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Widget>? headerActions;
  final Widget? footer;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;

  // Deprecated legacy params — kept for backward compatibility
  final Color? ledColor;
  final bool ledActive;
  final Color? accentColor;

  const LabPanel({
    super.key,
    this.title,
    this.icon,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.headerActions,
    this.footer,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = AppSpacing.radiusMd,
    // Deprecated
    this.ledColor,
    this.ledActive = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || icon != null;

    return Container(
      decoration: AppTheme.cardDecoration(
        color: backgroundColor,
        borderColor: borderColor,
        radius: borderRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader) _buildHeader(),
          Padding(padding: padding, child: child),
          if (footer != null) _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 2,
        AppSpacing.sm,
        AppSpacing.sm - 2,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textSecondary),
            AppSpacing.hSm,
          ],
          if (title != null)
            Expanded(
              child: Text(
                title!.toUpperCase(),
                style: AppTypography.cardTitle,
              ),
            ),
          if (headerActions != null && headerActions!.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: headerActions!),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: DefaultTextStyle(
        style: AppTypography.caption,
        child: footer!,
      ),
    );
  }
}
