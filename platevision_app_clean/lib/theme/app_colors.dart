import 'package:flutter/material.dart';

/// Professional color palette for PlateVisionAI.
///
/// Inspired by modern lab instrument software (Interscience, Thermo Fisher).
/// Clean, calm, and authoritative — not a gaming dashboard.
class AppColors {
  AppColors._();

  // ============================================================
  // Background — Dark slate (not navy/gaming)
  // ============================================================
  static const Color bgPrimary = Color(0xFF141820);
  static const Color bgSecondary = Color(0xFF1A1F2E);
  static const Color bgCard = Color(0xFF1E2538);
  static const Color bgCardAlt = Color(0xFF232B40);
  static const Color bgInput = Color(0xFF12161F);
  static const Color bgScaffold = Color(0xFF141820);

  // ============================================================
  // Accent — Professional blue (not cyan/teal)
  // ============================================================
  static const Color accentPrimary = Color(0xFF4F8CFF);
  static const Color accentSecondary = Color(0xFF6C63FF);
  static const Color accentDim = Color(0xFF3A6FD8);
  static const Color accentMuted = Color(0xFF2A4A7F);

  // ============================================================
  // Text — Clean white-to-gray hierarchy
  // ============================================================
  static const Color textPrimary = Color(0xFFF0F2F8);
  static const Color textSecondary = Color(0xFFA0A8BF);
  static const Color textTertiary = Color(0xFF6B7394);
  static const Color textMuted = Color(0xFF454D6B);
  static const Color textOnAccent = Colors.white;

  // ============================================================
  // Detection class colors
  // ============================================================
  static const Color colonyColor = Color(0xFF4CAF50);
  static const Color bubbleColor = Color(0xFF42A5F5);
  static const Color dustColor = Color(0xFFFFA726);
  static const Color crackColor = Color(0xFFEF5350);

  static Color getDetectionColor(String className) {
    switch (className.toLowerCase()) {
      case 'colony':
        return colonyColor;
      case 'bubble':
        return bubbleColor;
      case 'dust':
        return dustColor;
      case 'crack':
        return crackColor;
      default:
        return accentPrimary;
    }
  }

  // ============================================================
  // Status
  // ============================================================
  static const Color statusOnline = Color(0xFF4CAF50);
  static const Color statusWarning = Color(0xFFFFA726);
  static const Color statusOffline = Color(0xFFEF5350);
  static const Color statusProcessing = Color(0xFF42A5F5);
  static const Color statusIdle = Color(0xFF6B7394);
  static const Color statusStandby = Color(0xFF6C63FF);

  // ============================================================
  // Semantic
  // ============================================================
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF42A5F5);

  // ============================================================
  // Borders
  // ============================================================
  static const Color borderSubtle = Color(0xFF2A3050);
  static const Color borderMedium = Color(0xFF353E60);
  static const Color borderAccent = Color(0xFF4F8CFF);
  static const Color borderError = Color(0xFFEF5350);

  // ============================================================
  // Chart colors — Professional, muted palette
  // ============================================================
  static const List<Color> chartColors = [
    Color(0xFF4F8CFF),
    Color(0xFF6C63FF),
    Color(0xFF42A5F5),
    Color(0xFF4CAF50),
    Color(0xFFFFA726),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF26C6DA),
  ];

  // ============================================================
  // Shadows — Subtle
  // ============================================================
  static const Color shadowLight = Color(0x08000000);
  static const Color shadowMedium = Color(0x12000000);
  static const Color shadowHeavy = Color(0x20000000);

  // ============================================================
  // Misc
  // ============================================================
  static const Color disabled = Color(0xFF454D6B);
  static const Color disabledBackground = Color(0xFF12161F);
  static const Color scrim = Color(0x99141820);
  static const Color overlay = Color(0x0DF0F2F8);
  static const Color bgOverlay = Color(0xCC141820); // legacy compat
  static const Color bgElevated = Color(0xFF232B40); // legacy compat
  static const Color bgCardHover = Color(0xFF283050); // legacy compat

  // Legacy gradients
  static const LinearGradient accentHorizontalGradient = LinearGradient(
    colors: [Color(0xFF4F8CFF), Color(0xFF6C63FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
