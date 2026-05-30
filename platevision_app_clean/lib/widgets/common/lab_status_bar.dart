import 'dart:async';
import 'package:flutter/material.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_typography.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/theme/app_theme.dart';

/// Clean status bar showing connection state and app info.
enum ConnectionStatus { online, offline, warning, processing }

class LabStatusBar extends StatefulWidget {
  final ConnectionStatus connectionStatus;

  const LabStatusBar({
    super.key,
    this.connectionStatus = ConnectionStatus.online,
  });

  @override
  State<LabStatusBar> createState() => _LabStatusBarState();
}

class _LabStatusBarState extends State<LabStatusBar> {
  final _time = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _updateTime();
    Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    _time.value =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: AppColors.bgSecondary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              // App name
              Text(
                'PLATEVISION AI',
                style: AppTypography.status.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Connection status
              AppTheme.statusDot(
                widget.connectionStatus == ConnectionStatus.online
                    ? AppColors.statusOnline
                    : widget.connectionStatus == ConnectionStatus.warning
                        ? AppColors.statusWarning
                        : AppColors.statusOffline,
                size: 6,
              ),
              AppSpacing.hXs,
              Text(
                widget.connectionStatus == ConnectionStatus.online
                    ? 'ONLINE'
                    : widget.connectionStatus == ConnectionStatus.warning
                        ? 'WARNING'
                        : 'OFFLINE',
                style: AppTypography.status.copyWith(
                  color: widget.connectionStatus == ConnectionStatus.online
                      ? AppColors.statusOnline
                      : widget.connectionStatus == ConnectionStatus.warning
                          ? AppColors.statusWarning
                          : AppColors.statusOffline,
                ),
              ),
              AppSpacing.hMd,
              // Time
              ValueListenableBuilder<String>(
                valueListenable: _time,
                builder: (_, t, __) => Text(
                  t,
                  style: AppTypography.status,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
