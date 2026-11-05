import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';
import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
