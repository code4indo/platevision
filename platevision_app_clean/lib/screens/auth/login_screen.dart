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
import 'package:platevision_ai/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _labIdController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _labIdController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  Future<void> _handleDemoMode() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.login(
      username: 'analyst',
      password: 'analyst123',
    );

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [
              Color(0xFF0F1F3A),
              Color(0xFF0A1628),
              Color(0xFF070E1A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Status bar
              const LabStatusBar(
                connectionStatus: ConnectionStatus.online,
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: AppSpacing.xl),
                            _buildLoginForm(authProvider),
                            const SizedBox(height: AppSpacing.lg),
                            _buildDemoHint(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentPrimary.withOpacity(0.08),
            border: Border.all(
              color: AppColors.accentPrimary.withOpacity(0.25),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Icon(
            Icons.biotech_rounded,
            size: 32,
            color: AppColors.accentPrimary,
          ),
        ),

        const SizedBox(height: 20),

        // Brand name
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'PLATE',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: AppColors.textPrimary,
                ),
              ),
              TextSpan(
                text: 'VISION',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: AppColors.accentPrimary,
                ),
              ),
              TextSpan(
                text: 'AI',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppColors.accentSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'LABORATORY AUTHENTICATION',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.5,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(AuthProvider authProvider) {
    return LabPanel(
      title: 'SYSTEM ACCESS',
      icon: Icons.login_rounded,
      ledColor: authProvider.isLoading
          ? AppColors.statusProcessing
          : AppColors.statusOnline,
      ledActive: true,
      padding: const EdgeInsets.all(AppSpacing.panelPaddingLg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Connection status LED row
            _buildConnectionIndicator(authProvider),
            const SizedBox(height: AppSpacing.lg),

            // Username
            LabInput(
              label: 'Username',
              hint: 'Enter your username',
              controller: _usernameController,
              prefixIcon: Icons.person_outline_rounded,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.none,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Username is required';
                }
                return null;
              },
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Password
            LabInput(
              label: 'Password',
              hint: 'Enter your password',
              controller: _passwordController,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleLogin(),
            ),

            // Show/hide password toggle
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                child: Text(
                  _obscurePassword ? 'SHOW' : 'HIDE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Lab ID (optional)
            LabInput(
              label: 'Lab ID (Optional)',
              hint: 'e.g., LAB-001',
              controller: _labIdController,
              prefixIcon: Icons.science_outlined,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Error message
            if (authProvider.hasError)
              _buildErrorDisplay(authProvider.errorMessage!),

            if (authProvider.hasError)
              const SizedBox(height: AppSpacing.md),

            // Login button
            LabButton(
              label: 'LOGIN',
              variant: LabButtonVariant.primary,
              size: LabButtonSize.lg,
              icon: Icons.login_rounded,
              isLoading: authProvider.isLoading,
              onPressed: _handleLogin,
            ),
            const SizedBox(height: AppSpacing.md),

            // Demo mode button
            LabButton(
              label: 'DEMO MODE',
              variant: LabButtonVariant.secondary,
              size: LabButtonSize.md,
              icon: Icons.science_rounded,
              isLoading: authProvider.isLoading,
              onPressed: _handleDemoMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator(AuthProvider authProvider) {
    final isOnline = !authProvider.isLoading;
    final ledColor = isOnline
        ? AppColors.statusOnline
        : AppColors.statusProcessing;
    final statusText = isOnline ? 'READY' : 'AUTHENTICATING';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: AppSpacing.panelBorderWidth,
        ),
      ),
      child: Row(
        children: [
          AppTheme.buildLed(
            color: ledColor,
            isActive: true,
            size: AppSpacing.ledSize,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'AUTH: $statusText',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: ledColor,
            ),
          ),
          const Spacer(),
          Text(
            'PORT: 443',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.error,
                letterSpacing: 0.3,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.read<AuthProvider>().clearError(),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.error.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoHint() {
    return LabPanel(
      title: 'DEMO CREDENTIALS',
      icon: Icons.info_outline_rounded,
      ledColor: AppColors.statusStandby,
      ledActive: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDemoRow('admin', 'admin123', 'Administrator'),
          const SizedBox(height: AppSpacing.sm),
          _buildDemoRow('supervisor', 'super123', 'Supervisor'),
          const SizedBox(height: AppSpacing.sm),
          _buildDemoRow('analyst', 'analyst123', 'Analis'),
        ],
      ),
    );
  }

  Widget _buildDemoRow(String username, String password, String role) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$username / $password',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        Text(
          role,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.borderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'PlateVisionAI v${AppConfig.appVersion}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 1,
            height: 10,
            color: AppColors.borderSubtle,
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'MODEL: YOLOv8-v4',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
