import 'package:flutter/material.dart';

/// Responsive breakpoints and helpers for PlateVisionAI.
///
/// Mobile-first: default is mobile layout; tablet/desktop use wider layout.
class Responsive {
  static const double _mobile = 600;
  static const double _tablet = 900;

  /// Whether the screen is mobile width (< 600px).
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < _mobile;

  /// Whether the screen is tablet width (600–900px).
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= _mobile && w < _tablet;
  }

  /// Whether the screen is desktop width (>= 900px).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= _tablet;

  /// Returns cross-axis count for grid layouts based on screen width.
  static int gridColumns(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 3}) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  /// Adaptive horizontal padding — less on mobile, more on desktop.
  static double horizontalPadding(BuildContext context) =>
      isMobile(context) ? 12.0 : (isDesktop(context) ? 24.0 : 16.0);

  /// Returns a layout: row on desktop/tablet, column on mobile.
  static Widget rowOrColumn({
    required BuildContext context,
    required List<Widget> children,
    double gap = 16,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    if (isMobile(context)) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        children: _intersperse(children, SizedBox(height: gap)),
      );
    }
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: _intersperse(children, SizedBox(width: gap)),
    );
  }

  /// Helps spacing— inserts separators between list items.
  static List<Widget> _intersperse(List<Widget> list, Widget separator) {
    if (list.length <= 1) return list;
    final result = <Widget>[];
    for (int i = 0; i < list.length; i++) {
      result.add(list[i]);
      if (i < list.length - 1) result.add(separator);
    }
    return result;
  }

  /// Responsive bottom nav label behavior.
  static bool showNavLabels(BuildContext context) => !isMobile(context);

  /// Grid cross-axis count for readout cards.
  /// Desktop: 4 in a row, Tablet: 4 in a row, Mobile: 2 in a row
  static int readoutCardColumns(BuildContext context) =>
      isMobile(context) ? 2 : 4;

  /// Aspect ratio for readout cards.
  static double readoutCardAspectRatio(BuildContext context) =>
      isMobile(context) ? 2.2 : 3.0;

  /// Whether to show side-by-side layout or stack vertically.
  static bool useSideBySide(BuildContext context) => !isMobile(context);

  /// Compact gap size based on screen size.
  static double compactGap(BuildContext context) =>
      isMobile(context) ? 8.0 : 12.0;
}
