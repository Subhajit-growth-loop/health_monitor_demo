import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/theme/app_theme.dart';
import 'features/neu/presentation/screens/neu_splash_screen.dart';

class HealthMonitorApp extends StatelessWidget {
  const HealthMonitorApp({super.key});

  /// Lets the notification layer route (e.g. the 48h catch-up prompt) without a
  /// BuildContext.
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Design reference size (iPhone X logical points). ScreenUtil scales the
    // .w / .h / .r / .sp extension units relative to the actual device.
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        title: 'Health Monitor',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: child,
      ),
      child: const NeuSplashScreen(),
    );
  }
}
