import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/theme/app_theme.dart';
import 'package:platevision_ai/services/api_service.dart';
import 'package:platevision_ai/services/storage_service.dart';
import 'package:platevision_ai/providers/analysis_provider.dart';
import 'package:platevision_ai/providers/auth_provider.dart';
import 'package:platevision_ai/providers/dashboard_provider.dart';
import 'package:platevision_ai/screens/splash/splash_screen.dart';
import 'package:platevision_ai/screens/auth/login_screen.dart';
import 'package:platevision_ai/screens/dashboard/dashboard_screen.dart';
import 'package:platevision_ai/screens/capture/capture_screen.dart';
import 'package:platevision_ai/screens/analysis/analysis_result_screen.dart';
import 'package:platevision_ai/screens/samples/samples_screen.dart';
import 'package:platevision_ai/screens/reports/reports_screen.dart';
import 'package:platevision_ai/screens/reports/interscience_report_screen.dart';
import 'package:platevision_ai/screens/settings/settings_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage service
  await StorageService.instance.init();

  runApp(const PlateVisionApp());
}

class PlateVisionApp extends StatelessWidget {
  const PlateVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // API Service (singleton)
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),

        // Storage Service (singleton)
        Provider<StorageService>(
          create: (_) => StorageService.instance,
        ),

        // Auth Provider
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            apiService: context.read<ApiService>(),
            storageService: context.read<StorageService>(),
          ),
        ),

        // Analysis Provider
        ChangeNotifierProvider<AnalysisProvider>(
          create: (context) => AnalysisProvider(
            apiService: context.read<ApiService>(),
            storageService: context.read<StorageService>(),
          ),
        ),

        // Dashboard Provider
        ChangeNotifierProvider<DashboardProvider>(
          create: (context) => DashboardProvider(
            apiService: context.read<ApiService>(),
            storageService: context.read<StorageService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        locale: const Locale('en', 'US'),
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('id', 'ID'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/capture': (context) => const CaptureScreen(),
          '/analysis_result': (context) => const AnalysisResultScreen(),
          '/samples': (context) => const SamplesScreen(),
          '/reports': (context) => const ReportsScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
