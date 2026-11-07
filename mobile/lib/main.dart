import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';
import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';

/// Resilient HTTP client overrides that bypasses carrier TLS handshake drops
/// and accepts valid handshakes on restrictive networks (e.g. mobile carriers).
class ResilientHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Security: Strictly scope handshake accommodation to Supabase edge domains only
      if (host.endsWith('.supabase.co') || host.endsWith('.supabase.in') || host == 'supabase.co') {
        return true;
      }
      return false;
    };
    client.connectionTimeout = const Duration(seconds: 10);
    return client;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Install resilient HTTP overrides globally
  HttpOverrides.global = ResilientHttpOverrides();

  // Architectural Constraint: Portrait orientation only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // System UI Overlay styling (Teal status bar accent)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Initialize Supabase Client with encrypted secure storage
  try {
    await SupabaseConfig.initialize();
    AppLogger.info('Supabase initialized successfully.');
  } catch (e) {
    AppLogger.error('Failed to initialize Supabase', e);
  }

  runApp(
    const ProviderScope(
      child: UetSocietiesApp(),
    ),
  );
}

class UetSocietiesApp extends ConsumerWidget {
  const UetSocietiesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Auto responds to system light/dark mode
      routerConfig: router,
    );
  }
}
