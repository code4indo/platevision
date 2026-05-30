import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/theme/app_responsive.dart';

/// Navigation item definition
class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

/// Shared navigation items for the entire app
const List<AppNavItem> kAppNavItems = [
  AppNavItem(
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    label: 'Dashboard',
    route: '/dashboard',
  ),
  AppNavItem(
    icon: Icons.camera_alt_outlined,
    activeIcon: Icons.camera_alt_rounded,
    label: 'Analyze',
    route: '/capture',
  ),
  AppNavItem(
    icon: Icons.science_outlined,
    activeIcon: Icons.science_rounded,
    label: 'Samples',
    route: '/samples',
  ),
  AppNavItem(
    icon: Icons.assessment_outlined,
    activeIcon: Icons.assessment_rounded,
    label: 'Reports',
    route: '/reports',
  ),
  AppNavItem(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    label: 'Settings',
    route: '/settings',
  ),
];

/// Consistent app scaffold with bottom navigation bar.
///
/// Use this on every page to ensure consistent navigation across the app.
/// Each page just provides its [currentIndex] and [body] content.
///
/// Usage:
/// ```dart
/// return AppScaffold(
///   currentIndex: 0,
///   body: MyPageContent(),
/// );
/// ```
class AppScaffold extends StatelessWidget {
  /// Index of the current page in [kAppNavItems]
  final int currentIndex;

  /// The page content (rendered above the nav bar)
  final Widget body;

  /// Optional floating action button
  final Widget? floatingActionButton;

  /// Optional FloatingActionButton location
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final navHeight = isMobile ? 58.0 : 52.0;

    return Container(
      height: navHeight,
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(kAppNavItems.length, (index) {
          return _buildNavItem(context, index);
        }),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final item = kAppNavItems[index];
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.accentPrimary : AppColors.textTertiary;
    final showLabel = Responsive.showNavLabels(context);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isSelected) return; // Already on this page
            Navigator.of(context).pushNamedAndRemoveUntil(
              item.route,
              (route) => route.isFirst, // Keep splash/login, remove everything else
            );
          },
          splashColor: AppColors.accentPrimary.withOpacity(0.1),
          highlightColor: AppColors.accentPrimary.withOpacity(0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Active indicator bar
              AnimatedContainer(
                duration: AppSpacing.animationFast,
                width: isSelected ? 28 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              // Icon
              AnimatedSwitcher(
                duration: AppSpacing.animationFast,
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  key: ValueKey(isSelected),
                  size: isSelected ? 22 : 20,
                  color: color,
                ),
              ),
              // Label
              if (showLabel) ...[
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: AppSpacing.animationFast,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: isSelected ? 10 : 9,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  child: Text(item.label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
