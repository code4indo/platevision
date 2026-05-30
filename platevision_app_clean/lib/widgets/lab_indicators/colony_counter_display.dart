import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_typography.dart';
import 'package:platevision_ai/theme/app_spacing.dart';

/// Clean colony count display — large number with label.
class ColonyCounterDisplay extends StatefulWidget {
  final int count;
  final String label;
  final Color? color;
  final String? subtitle;

  const ColonyCounterDisplay({
    super.key,
    required this.count,
    this.label = 'COLONY COUNT',
    this.color,
    this.subtitle,
  });

  @override
  State<ColonyCounterDisplay> createState() => _ColonyCounterDisplayState();
}

class _ColonyCounterDisplayState extends State<ColonyCounterDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  int _displayCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _animateCount();
  }

  void _animateCount() {
    final target = widget.count;
    if (target == 0) {
      _displayCount = 0;
      return;
    }
    final step = max(1, target ~/ 30);
    _displayCount = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 20), (t) {
      _displayCount = min(_displayCount + step, target);
      if (_displayCount >= target) {
        _displayCount = target;
        t.cancel();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(ColonyCounterDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _controller.reset();
      _controller.forward();
      _animateCount();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? AppColors.accentPrimary;

    return FadeTransition(
      opacity: _fadeIn,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _displayCount.toString(),
            style: AppTypography.dataLarge.copyWith(
              color: accent,
              fontSize: 42,
            ),
          ),
          AppSpacing.vXs,
          Text(
            widget.label,
            style: AppTypography.dataLabel.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          if (widget.subtitle != null) ...[
            AppSpacing.vXs,
            Text(
              widget.subtitle!,
              style: AppTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}
