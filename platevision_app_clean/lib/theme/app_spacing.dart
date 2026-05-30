import 'package:flutter/widgets.dart';

/// Clean spacing system — keeps it simple.
class AppSpacing {
  AppSpacing._();

  // 4px grid
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;

  // Legacy radii
  static const double radiusXs = 2;
  static const double radiusXxl = 24;
  static const double radiusFull = 999;

  // Panel dimensions (legacy, kept for compat)
  static const double panelPadding = 16;
  static const double panelPaddingSm = 12;
  static const double panelPaddingLg = 20;
  static const double panelBorderWidth = 1;

  // Legacy — kept for compatibility
  static const double ledSize = 8;
  static const double ledSizeLg = 12;
  static const double ledGlowRadius = 16;
  static const double chipRadius = 14;
  static const double bottomNavHeight = 64;
  static const double inputPaddingH = 16;
  static const double inputRadius = 8;

  // Bounding box constants (legacy)
  static const double boundingBoxBorderWidth = 2;
  static const double boundingBoxLabelPaddingH = 6;
  static const double boundingBoxLabelPaddingV = 2;
  static const double boundingBoxLabelRadius = 4;
  static const double boundingBoxMinSize = 8;

  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration ledPulseDuration = Duration(milliseconds: 1000);

  // Gaps
  static SizedBox get hXs => const SizedBox(width: xs);
  static SizedBox get hSm => const SizedBox(width: sm);
  static SizedBox get hMd => const SizedBox(width: md);
  static SizedBox get hLg => const SizedBox(width: lg);

  static SizedBox get vXs => const SizedBox(height: xs);
  static SizedBox get vSm => const SizedBox(height: sm);
  static SizedBox get vMd => const SizedBox(height: md);
  static SizedBox get vLg => const SizedBox(height: lg);
  static SizedBox get vXl => const SizedBox(height: xl);
}
