import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Professional typography system for PlateVisionAI.
///
/// Single font family (Inter) for a clean, consistent, professional look.
/// Mono font (JetBrains Mono) reserved for data values and code only.
class AppTypography {
  AppTypography._();

  // ============================================================
  // Font families
  // ============================================================
  static const String fontFamily = 'Inter';
  static const String monoFamily = 'JetBrains Mono';

  // ============================================================
  // Sizes
  // ============================================================
  static const double sizeXs = 10;
  static const double sizeSm = 12;
  static const double sizeBase = 14;
  static const double sizeMd = 16;
  static const double sizeLg = 18;
  static const double sizeXl = 22;
  static const double sizeXxl = 28;
  static const double sizeDisplay = 34;

  // ============================================================
  // Weights
  // ============================================================
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // ============================================================
  // Readable text styles (Inter)
  // ============================================================

  /// Page / section titles
  static TextStyle get pageTitle => GoogleFonts.inter(
        fontSize: sizeXl,
        fontWeight: semibold,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  /// Card / panel titles
  static TextStyle get cardTitle => GoogleFonts.inter(
        fontSize: sizeSm,
        fontWeight: semibold,
        color: AppColors.textSecondary,
        height: 1.3,
      );

  /// Large data value (e.g., colony count)
  static TextStyle get dataLarge => GoogleFonts.jetBrainsMono(
        fontSize: sizeXxl,
        fontWeight: bold,
        color: AppColors.textPrimary,
        height: 1.1,
      );

  /// Medium data value
  static TextStyle get dataMedium => GoogleFonts.jetBrainsMono(
        fontSize: sizeLg,
        fontWeight: semibold,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  /// Small data value
  static TextStyle get dataSmall => GoogleFonts.jetBrainsMono(
        fontSize: sizeBase,
        fontWeight: medium,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  /// Data unit / label
  static TextStyle get dataLabel => GoogleFonts.jetBrainsMono(
        fontSize: sizeXs,
        fontWeight: medium,
        color: AppColors.textTertiary,
        height: 1.2,
        letterSpacing: 0.5,
      );

  /// Body text
  static TextStyle get body => GoogleFonts.inter(
        fontSize: sizeBase,
        fontWeight: regular,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  /// Body small
  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: sizeSm,
        fontWeight: regular,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  /// Body extra small (captions)
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: sizeXs,
        fontWeight: regular,
        color: AppColors.textTertiary,
        height: 1.3,
      );

  /// Button label
  static TextStyle get button => GoogleFonts.inter(
        fontSize: sizeBase,
        fontWeight: medium,
        color: Colors.white,
        height: 1.2,
      );

  /// Small button label
  static TextStyle get buttonSmall => GoogleFonts.inter(
        fontSize: sizeSm,
        fontWeight: medium,
        color: Colors.white,
        height: 1.2,
      );

  /// Status text (mono for technical feel)
  static TextStyle get status => GoogleFonts.jetBrainsMono(
        fontSize: sizeXs,
        fontWeight: medium,
        color: AppColors.textTertiary,
        height: 1.2,
        letterSpacing: 0.3,
      );

  // ============================================================
  // TextTheme for Material
  // ============================================================
  static TextTheme get textTheme => TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: sizeDisplay,
          fontWeight: bold,
          color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: sizeXxl,
          fontWeight: semibold,
          color: AppColors.textPrimary,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: sizeXl,
          fontWeight: semibold,
          color: AppColors.textPrimary,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: sizeLg,
          fontWeight: semibold,
          color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: sizeMd,
          fontWeight: semibold,
          color: AppColors.textPrimary,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: sizeBase,
          fontWeight: semibold,
          color: AppColors.textSecondary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: sizeMd,
          fontWeight: semibold,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: sizeBase,
          fontWeight: medium,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: sizeSm,
          fontWeight: medium,
          color: AppColors.textSecondary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: sizeMd,
          fontWeight: regular,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: sizeBase,
          fontWeight: regular,
          color: AppColors.textPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: sizeSm,
          fontWeight: regular,
          color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: sizeBase,
          fontWeight: medium,
          color: Colors.white,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: sizeSm,
          fontWeight: medium,
          color: AppColors.textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: sizeXs,
          fontWeight: medium,
          color: AppColors.textTertiary,
        ),
      );
}
