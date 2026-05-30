import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late AnimationController _fadeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _progressValue;
  late Animation<double> _fadeOpacity;

  int _statusIndex = 0;
  bool _navigated = false;

  static const List<String> _statusMessages = [
    'Initializing system...',
    'Loading model...',
    'Calibrating sensors...',
    'Connecting to API...',
    'System ready',
  ];

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _fadeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _startBootSequence();
  }

  void _startBootSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _progressController.forward();
    _cycleStatusMessages();

    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _navigateNext();
  }

  void _cycleStatusMessages() async {
    for (int i = 0; i < _statusMessages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 550));
      if (!mounted) return;
      setState(() {
        _statusIndex = i;
      });
    }
  }

  void _navigateNext() {
    if (_navigated) return;
    _navigated = true;

    final authProvider = context.read<AuthProvider>();
    final targetRoute =
        authProvider.isAuthenticated ? '/dashboard' : '/login';

    Navigator.of(context).pushReplacementNamed(targetRoute);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _logoController,
          _progressController,
          _fadeController,
        ]),
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  Color(0xFF0F1F3A),
                  Color(0xFF0A1628),
                  Color(0xFF070E1A),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Subtle grid pattern
                _buildGridPattern(),

                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 3),

                      // Logo area
                      _buildLogo(),

                      const SizedBox(height: 32),

                      // Progress indicator
                      _buildProgressBar(),

                      const SizedBox(height: 20),

                      // Status message
                      _buildStatusMessage(),

                      const Spacer(flex: 2),

                      // Version info
                      _buildVersionInfo(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),

                // Fade-out overlay
                if (_fadeOpacity.value > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: AppColors.bgScaffold
                            .withOpacity(_fadeOpacity.value),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridPattern() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.03,
        child: CustomPaint(
          painter: _GridPainter(),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Opacity(
      opacity: _logoOpacity.value,
      child: Transform.scale(
        scale: _logoScale.value,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with glow
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentPrimary.withOpacity(0.08),
                border: Border.all(
                  color: AppColors.accentPrimary.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentPrimary.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.biotech_rounded,
                size: 40,
                color: AppColors.accentPrimary,
              ),
            ),

            const SizedBox(height: 24),

            // App name
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'PLATE',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: 'VISION',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  TextSpan(
                    text: 'AI',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.accentSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              'COLONY COUNTER & DETECTION SYSTEM',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 3.0,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _progressValue.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar track
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: AppColors.borderSubtle,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                children: [
                  // Fill
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.accentHorizontalGradient,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentPrimary.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Percentage
          Text(
            '${(progress * 100).toInt()}%',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppColors.accentPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage() {
    final message =
        _statusIndex < _statusMessages.length
            ? _statusMessages[_statusIndex]
            : _statusMessages.last;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Blinking dot
        _BlinkingDot(
          color: _statusIndex == _statusMessages.length - 1
              ? AppColors.statusOnline
              : AppColors.statusProcessing,
        ),
        const SizedBox(width: 10),
        Text(
          message.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
            color: _statusIndex == _statusMessages.length - 1
                ? AppColors.statusOnline
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo() {
    return Opacity(
      opacity: _logoOpacity.value.clamp(0.0, 1.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 1,
            width: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.borderSubtle,
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'v${AppConfig.appVersion}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'MODEL: YOLOv8-v4',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'mAP@50: ${(AppConfig.map50 * 100).toStringAsFixed(1)}%',
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

class _BlinkingDot extends StatefulWidget {
  final Color color;

  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4 + _controller.value * 0.4),
                blurRadius: 6 + _controller.value * 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentPrimary
      ..strokeWidth = 0.5;

    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
