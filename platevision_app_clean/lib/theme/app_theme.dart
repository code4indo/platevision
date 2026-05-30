import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// Professional dark theme for PlateVisionAI.
///
/// Clean, minimal, instrument-grade — no LEDs, no glows, no gaming aesthetic.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _colorScheme,
        textTheme: AppTypography.textTheme,
        scaffoldBackgroundColor: AppColors.bgScaffold,
        canvasColor: AppColors.bgSecondary,
        cardColor: AppColors.bgCard,
        dividerColor: AppColors.borderSubtle,
        disabledColor: AppColors.disabled,
        hintColor: AppColors.textTertiary,
        hoverColor: AppColors.overlay,
        focusColor: AppColors.accentPrimary.withOpacity(0.15),
        highlightColor: AppColors.overlay,
        splashColor: Colors.transparent,
        splashFactory: NoSplash(),
        visualDensity: VisualDensity.compact,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        appBarTheme: _appBarTheme,
        cardTheme: _cardTheme,
        elevatedButtonTheme: _elevatedButtonTheme,
        outlinedButtonTheme: _outlinedButtonTheme,
        textButtonTheme: _textButtonTheme,
        inputDecorationTheme: _inputDecorationTheme,
        bottomNavigationBarTheme: _bottomNavTheme,
        chipTheme: _chipTheme,
        dialogTheme: _dialogTheme,
        snackBarTheme: _snackBarTheme,
        dividerTheme: _dividerTheme,
        switchTheme: _switchTheme,
        progressIndicatorTheme: _progressTheme,
        iconTheme: _iconTheme,
      );

  // ============================================================
  // Color Scheme
  // ============================================================
  static const ColorScheme _colorScheme = ColorScheme.dark(
    primary: AppColors.accentPrimary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.accentDim,
    onPrimaryContainer: Colors.white,
    secondary: AppColors.accentSecondary,
    onSecondary: Colors.white,
    surface: AppColors.bgCard,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.bgCardAlt,
    onSurfaceVariant: AppColors.textSecondary,
    error: AppColors.error,
    onError: Colors.white,
    outline: AppColors.borderMedium,
    outlineVariant: AppColors.borderSubtle,
    shadow: AppColors.shadowMedium,
  );

  // ============================================================
  // AppBar — Minimal
  // ============================================================
  static const AppBarTheme _appBarTheme = AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 1,
    centerTitle: false,
    backgroundColor: AppColors.bgSecondary,
    foregroundColor: AppColors.textPrimary,
    surfaceTintColor: Colors.transparent,
    titleSpacing: AppSpacing.md,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    titleTextStyle: TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: AppTypography.sizeLg,
      fontWeight: AppTypography.semibold,
      color: AppColors.textPrimary,
    ),
  );

  // ============================================================
  // Card — Clean, no decoration overload
  // ============================================================
  static final CardThemeData _cardTheme = CardThemeData(
    elevation: 0,
    color: AppColors.bgCard,
    shadowColor: AppColors.shadowMedium,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      side: const BorderSide(color: AppColors.borderSubtle, width: 1),
    ),
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
  );

  // ============================================================
  // Buttons — Clean
  // ============================================================
  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: AppColors.accentPrimary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.disabledBackground,
      disabledForegroundColor: AppColors.disabled,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 4,
        vertical: AppSpacing.sm + 4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      textStyle: AppTypography.button,
    ),
  );

  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.accentPrimary,
      side: const BorderSide(color: AppColors.borderMedium),
      disabledForegroundColor: AppColors.disabled,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 4,
        vertical: AppSpacing.sm + 4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      textStyle: AppTypography.button,
    ),
  );

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.accentPrimary,
      disabledForegroundColor: AppColors.disabled,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      textStyle: AppTypography.button,
    ),
  );

  // ============================================================
  // Input
  // ============================================================
  static final InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
    filled: true,
    fillColor: AppColors.bgInput,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm + 4,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.borderSubtle),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.borderSubtle),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.borderAccent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    labelStyle: AppTypography.bodySmall,
    hintStyle: AppTypography.caption,
    errorStyle: const TextStyle(color: AppColors.error),
  );

  // ============================================================
  // Bottom Nav
  // ============================================================
  static final BottomNavigationBarThemeData _bottomNavTheme =
      BottomNavigationBarThemeData(
    backgroundColor: AppColors.bgSecondary,
    elevation: 0,
    selectedItemColor: AppColors.accentPrimary,
    unselectedItemColor: AppColors.textTertiary,
    type: BottomNavigationBarType.fixed,
    selectedLabelStyle: AppTypography.caption.copyWith(
      fontWeight: AppTypography.medium,
    ),
    unselectedLabelStyle: AppTypography.caption,
  );

  // ============================================================
  // Chip
  // ============================================================
  static final ChipThemeData _chipTheme = ChipThemeData(
    backgroundColor: AppColors.bgCardAlt,
    labelStyle: AppTypography.caption.copyWith(color: AppColors.textSecondary),
    side: const BorderSide(color: AppColors.borderSubtle),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
    ),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
  );

  // ============================================================
  // Dialog
  // ============================================================
  static final DialogThemeData _dialogTheme = DialogThemeData(
    backgroundColor: AppColors.bgCard,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      side: const BorderSide(color: AppColors.borderSubtle),
    ),
  );

  // ============================================================
  // SnackBar
  // ============================================================
  static final SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    backgroundColor: AppColors.bgCardAlt,
    contentTextStyle: AppTypography.bodySmall.copyWith(color: Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    behavior: SnackBarBehavior.floating,
  );

  // ============================================================
  // Misc
  // ============================================================
  static const DividerThemeData _dividerTheme = DividerThemeData(
    color: AppColors.borderSubtle,
    thickness: 1,
    space: 1,
  );

  static final SwitchThemeData _switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.accentPrimary;
      return AppColors.textMuted;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.accentPrimary.withOpacity(0.3);
      }
      return AppColors.borderSubtle;
    }),
  );

  static final ProgressIndicatorThemeData _progressTheme =
      ProgressIndicatorThemeData(
    color: AppColors.accentPrimary,
    linearTrackColor: AppColors.borderSubtle,
    circularTrackColor: AppColors.borderSubtle,
  );

  static const IconThemeData _iconTheme = IconThemeData(
    color: AppColors.textSecondary,
    size: 20,
  );

  // ============================================================
  // Decoration helpers
  // ============================================================

  /// Standard card decoration (no header bar, no LED — just clean)
  static BoxDecoration cardDecoration({
    Color? color,
    Color? borderColor,
    double radius = AppSpacing.radiusMd,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.bgCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppColors.borderSubtle, width: 1),
    );
  }

  /// Subtle hover/focus highlight
  static BoxDecoration highlightDecoration({double radius = AppSpacing.radiusMd}) {
    return BoxDecoration(
      color: AppColors.overlay,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// Status dot
  static Widget statusDot(Color color, {double size = 8}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  /// Legacy LED indicator — delegates to statusDot
  @Deprecated('Use statusDot instead')
  static Widget buildLed({
    required Color color,
    bool isActive = true,
    double size = 8,
    String? label,
  }) {
    return statusDot(color, size: size);
  }
}

/// Suppresses splash/ripple for a cleaner feel
class NoSplash extends InteractiveInkFeatureFactory {
  const NoSplash();

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return NoSplashFeature(
      controller: controller,
      referenceBox: referenceBox,
      color: color,
    );
  }
}

class NoSplashFeature extends InteractiveInkFeature {
  NoSplashFeature({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Color color,
  }) : super(
          controller: controller,
          referenceBox: referenceBox,
          color: color,
        );

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    // No paint — no splash
  }
}
