import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/theme/app_theme.dart';
import 'package:platevision_ai/widgets/common/lab_button.dart';
import 'package:platevision_ai/widgets/common/lab_input.dart';
import 'package:platevision_ai/widgets/common/lab_panel.dart';
import 'package:platevision_ai/widgets/common/lab_status_bar.dart';
import 'package:platevision_ai/providers/analysis_provider.dart';
import 'package:platevision_ai/providers/auth_provider.dart';
import 'package:platevision_ai/providers/dashboard_provider.dart';
import 'package:platevision_ai/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:platevision_ai/widgets/common/app_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _confidenceThreshold;
  late double _iouThreshold;
  late String _defaultMediaType;
  late String _defaultDilution;
  late String _defaultLabName;
  late String _apiEndpoint;
  late bool _autoSave;
  late bool _showConfidence;
  late bool _showBoundingBoxes;
  late bool _chartAnimations;

  bool _isTestingConnection = false;
  String? _connectionTestResult;
  Color? _connectionTestColor;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final prefs = StorageService.instance.loadPreferences();
    _confidenceThreshold = prefs.confidenceThreshold;
    _iouThreshold = prefs.iouThreshold;
    _defaultMediaType = prefs.defaultMediaType;
    _defaultDilution = prefs.defaultDilution;
    _defaultLabName = prefs.defaultLabName;
    _apiEndpoint = AppConfig.apiBaseUrl;
    _autoSave = prefs.autoSaveResults;
    _showConfidence = prefs.showConfidenceLabels;
    _showBoundingBoxes = prefs.showBoundingBoxes;
    _chartAnimations = true;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return AppScaffold(
      currentIndex: 4,
      body: Container(
        color: AppColors.bgScaffold,
        child: SafeArea(
          child: Column(
            children: [
              // Status bar
              const LabStatusBar(
                connectionStatus: ConnectionStatus.online,
              ),

              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Account section
                      _buildAccountSection(authProvider),
                      const SizedBox(height: AppSpacing.lg),

                      // Analysis section
                      _buildAnalysisSection(),
                      const SizedBox(height: AppSpacing.lg),

                      // API section
                      _buildApiSection(),
                      const SizedBox(height: AppSpacing.lg),

                      // Display section
                      _buildDisplaySection(),
                      const SizedBox(height: AppSpacing.lg),

                      // About section
                      _buildAboutSection(),
                      const SizedBox(height: AppSpacing.lg),

                      // Danger zone
                      _buildDangerZone(authProvider),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
          Expanded(
            child: Text(
              'SETTINGS',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          AppTheme.buildLed(
            color: AppColors.statusOnline,
            isActive: true,
            size: AppSpacing.ledSize,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Account Section
  // ============================================================

  Widget _buildAccountSection(AuthProvider authProvider) {
    final user = authProvider.currentUser;

    return LabPanel(
      title: 'ACCOUNT',
      icon: Icons.person_outline_rounded,
      ledColor: AppColors.accentPrimary,
      ledActive: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // User info
          _buildSettingRow(
            label: 'USERNAME',
            value: user?.username ?? '--',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'FULL NAME',
            value: user?.fullName ?? '--',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'EMAIL',
            value: user?.email ?? '--',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'ROLE',
            value: user?.roleLabel ?? '--',
            valueColor: user?.roleColor,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'LABORATORY',
            value: user?.laboratory ?? '--',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'LAST LOGIN',
            value: user?.lastLoginLabel ?? '--',
          ),
          const SizedBox(height: AppSpacing.md),

          // Change password (placeholder)
          SizedBox(
            width: double.infinity,
            child: LabButton(
              label: 'CHANGE PASSWORD',
              variant: LabButtonVariant.secondary,
              size: LabButtonSize.sm,
              icon: Icons.lock_outline_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password change coming soon'),
                    backgroundColor: AppColors.info,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Analysis Section
  // ============================================================

  Widget _buildAnalysisSection() {
    return LabPanel(
      title: 'ANALYSIS',
      icon: Icons.tune_rounded,
      ledColor: AppColors.warning,
      ledActive: true,
      accentColor: AppColors.warning,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence threshold slider
          _buildSliderSetting(
            label: 'CONFIDENCE THRESHOLD',
            value: _confidenceThreshold,
            min: 0.05,
            max: 1.0,
            divisions: 19,
            displayValue:
                '${(_confidenceThreshold * 100).toStringAsFixed(0)}%',
            onChanged: (val) {
              setState(() => _confidenceThreshold = val);
              context.read<AnalysisProvider>().setConfidenceThreshold(val);
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // IoU threshold slider
          _buildSliderSetting(
            label: 'IOU THRESHOLD',
            value: _iouThreshold,
            min: 0.1,
            max: 0.95,
            divisions: 17,
            displayValue:
                '${(_iouThreshold * 100).toStringAsFixed(0)}%',
            onChanged: (val) {
              setState(() => _iouThreshold = val);
              context.read<AnalysisProvider>().setIouThreshold(val);
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Default media type
          LabInput(
            label: 'Default Media Type',
            hint: 'e.g., PCA, PDA, NA',
            controller: TextEditingController(text: _defaultMediaType),
            prefixIcon: Icons.science_outlined,
            textCapitalization: TextCapitalization.characters,
            onChanged: (val) {
              _defaultMediaType = val;
              StorageService.instance.savePreferences(
                StorageService.instance.loadPreferences().copyWith(
                  defaultMediaType: val,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Default dilution
          LabInput(
            label: 'Default Dilution',
            hint: 'e.g., 10^-1, 10^-3',
            controller: TextEditingController(text: _defaultDilution),
            prefixIcon: Icons.water_drop_outlined,
            onChanged: (val) {
              _defaultDilution = val;
              StorageService.instance.savePreferences(
                StorageService.instance.loadPreferences().copyWith(
                  defaultDilution: val,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
                color: AppColors.textTertiary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                border: Border.all(
                  color: AppColors.accentPrimary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                displayValue,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.accentPrimary,
            inactiveTrackColor: AppColors.bgInput,
            thumbColor: AppColors.accentPrimary,
            overlayColor: AppColors.accentPrimary.withOpacity(0.12),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 8,
              elevation: 2,
            ),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // API Section
  // ============================================================

  Widget _buildApiSection() {
    return LabPanel(
      title: 'API CONNECTION',
      icon: Icons.dns_rounded,
      ledColor: AppColors.accentSecondary,
      ledActive: true,
      accentColor: AppColors.accentSecondary,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // API endpoint
          LabInput(
            label: 'Endpoint URL',
            hint: 'https://api.example.com',
            controller: TextEditingController(text: _apiEndpoint),
            prefixIcon: Icons.link_rounded,
            onChanged: (val) {
              _apiEndpoint = val;
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Health endpoint
          _buildSettingRow(
            label: 'HEALTH ENDPOINT',
            value: AppConfig.apiHealthEndpoint,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Predict endpoint
          _buildSettingRow(
            label: 'PREDICT ENDPOINT',
            value: AppConfig.apiPredictEndpoint,
          ),
          const SizedBox(height: AppSpacing.md),

          // Connection test result
          if (_connectionTestResult != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: _connectionTestColor!.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: _connectionTestColor!.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _connectionTestColor == AppColors.success
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 16,
                    color: _connectionTestColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _connectionTestResult!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _connectionTestColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Test connection button
          SizedBox(
            width: double.infinity,
            child: LabButton(
              label: 'TEST CONNECTION',
              variant: LabButtonVariant.secondary,
              size: LabButtonSize.md,
              icon: Icons.wifi_find_rounded,
              isLoading: _isTestingConnection,
              onPressed: _testConnection,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
    });

    try {
      final dashboardProvider = context.read<DashboardProvider>();
      await dashboardProvider.checkSystemStatus();

      final status = dashboardProvider.systemStatus;
      setState(() {
        _isTestingConnection = false;
        if (status.isOperational) {
          _connectionTestResult =
              'Connected! Response: ${status.apiResponseTime?.inMilliseconds ?? 0}ms';
          _connectionTestColor = AppColors.success;
        } else {
          _connectionTestResult =
              'API offline. ${status.errorMessage ?? 'Server not responding'}';
          _connectionTestColor = AppColors.error;
        }
      });
    } catch (e) {
      setState(() {
        _isTestingConnection = false;
        _connectionTestResult = 'Connection failed: $e';
        _connectionTestColor = AppColors.error;
      });
    }
  }

  // ============================================================
  // Display Section
  // ============================================================

  Widget _buildDisplaySection() {
    return LabPanel(
      title: 'DISPLAY',
      icon: Icons.display_settings_rounded,
      ledColor: AppColors.info,
      ledActive: true,
      accentColor: AppColors.info,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _buildToggleRow(
            label: 'AUTO-SAVE RESULTS',
            subtitle: 'Automatically save analysis results to history',
            value: _autoSave,
            onChanged: (val) {
              setState(() => _autoSave = val);
              StorageService.instance.setAutoSaveResults(val);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildToggleRow(
            label: 'SHOW CONFIDENCE LABELS',
            subtitle: 'Display confidence % on bounding boxes',
            value: _showConfidence,
            onChanged: (val) {
              setState(() => _showConfidence = val);
              StorageService.instance.setShowConfidenceLabels(val);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildToggleRow(
            label: 'SHOW BOUNDING BOXES',
            subtitle: 'Draw detection bounding boxes on images',
            value: _showBoundingBoxes,
            onChanged: (val) {
              setState(() => _showBoundingBoxes = val);
              StorageService.instance.setShowBoundingBoxes(val);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildToggleRow(
            label: 'CHART ANIMATIONS',
            subtitle: 'Animate chart entry transitions',
            value: _chartAnimations,
            onChanged: (val) {
              setState(() => _chartAnimations = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.accentPrimary,
          activeTrackColor: AppColors.accentDim,
        ),
      ],
    );
  }

  // ============================================================
  // About Section
  // ============================================================

  Widget _buildAboutSection() {
    return LabPanel(
      title: 'ABOUT',
      icon: Icons.info_outline_rounded,
      ledColor: AppColors.textTertiary,
      ledActive: true,
      accentColor: AppColors.textTertiary,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _buildSettingRow(
            label: 'APP VERSION',
            value: 'v${AppConfig.appVersion}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'MODEL',
            value: 'YOLOv8-v4',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'mAP@50',
            value: '${(AppConfig.map50 * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'mAP@50-95',
            value: '${(AppConfig.map5095 * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'PRECISION',
            value: '${(AppConfig.precision * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'RECALL',
            value: '${(AppConfig.recall * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingRow(
            label: 'DETECTION CLASSES',
            value: AppConfig.detectionClasses.join(', '),
          ),
          const SizedBox(height: AppSpacing.md),

          // Reset defaults
          SizedBox(
            width: double.infinity,
            child: LabButton(
              label: 'RESET TO DEFAULTS',
              variant: LabButtonVariant.secondary,
              size: LabButtonSize.sm,
              icon: Icons.restore_rounded,
              onPressed: _resetDefaults,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Danger Zone
  // ============================================================

  Widget _buildDangerZone(AuthProvider authProvider) {
    return LabPanel(
      title: 'DANGER ZONE',
      icon: Icons.warning_amber_rounded,
      ledColor: AppColors.error,
      ledActive: true,
      accentColor: AppColors.error,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(
            'These actions cannot be undone. Proceed with caution.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Clear history
          SizedBox(
            width: double.infinity,
            child: LabButton(
              label: 'CLEAR ANALYSIS HISTORY',
              variant: LabButtonVariant.secondary,
              size: LabButtonSize.sm,
              icon: Icons.delete_sweep_outlined,
              onPressed: () => _confirmClearHistory(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Logout
          SizedBox(
            width: double.infinity,
            child: LabButton(
              label: 'LOGOUT',
              variant: LabButtonVariant.danger,
              size: LabButtonSize.md,
              icon: Icons.logout_rounded,
              onPressed: () => _handleLogout(authProvider),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Helpers
  // ============================================================

  Widget _buildSettingRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _resetDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.borderMedium, width: 1),
        ),
        title: Text(
          'RESET TO DEFAULTS?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'All analysis settings will be restored to their default values.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'CANCEL',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          LabButton(
            label: 'RESET',
            variant: LabButtonVariant.danger,
            size: LabButtonSize.sm,
            onPressed: () {
              context.read<AnalysisProvider>().resetThresholds();
              setState(() {
                _confidenceThreshold = AppConfig.confidenceThreshold;
                _iouThreshold = AppConfig.iouThreshold;
                _defaultMediaType = 'PCA';
                _defaultDilution = '10^-1';
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Settings reset to defaults'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.borderMedium, width: 1),
        ),
        title: Text(
          'CLEAR ALL HISTORY?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'This will permanently delete all analysis history. This cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'CANCEL',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          LabButton(
            label: 'CLEAR',
            variant: LabButtonVariant.danger,
            size: LabButtonSize.sm,
            onPressed: () {
              context.read<AnalysisProvider>().clearHistory();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Analysis history cleared'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.borderMedium, width: 1),
        ),
        title: Text(
          'LOGOUT?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'You will be signed out and redirected to the login screen.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          LabButton(
            label: 'LOGOUT',
            variant: LabButtonVariant.danger,
            size: LabButtonSize.sm,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}
