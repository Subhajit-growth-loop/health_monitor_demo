import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/neu/presentation/screens/neu_splash_screen.dart';

class HealthMonitorApp extends ConsumerWidget {
  const HealthMonitorApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        title: 'Neu Health',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        // Ambient status-bar style for every screen without an AppBar. Screens
        // with their own AnnotatedRegion (the image-backed auth/splash screens)
        // still win, since the nearest region applies.
        builder: (_, navigator) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlayStyle(isDark),
          child: navigator ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
      child: const NeuSplashScreen(),
    );
  }
}
