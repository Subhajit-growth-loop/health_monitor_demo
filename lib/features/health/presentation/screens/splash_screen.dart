import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/notifications/notification_service.dart';
import '../providers/permission_controller.dart';
import 'dashboard_screen.dart';
import 'sync_settings_screen.dart';

/// Startup screen. While it is shown we request health permissions and run the
/// first acquisition + sync, then route straight to the dashboard — no login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _status = 'Starting up…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 1200));

    setState(() => _status = 'Requesting health access…');
    await ref.read(permissionControllerProvider.notifier).requestAll();

    setState(() => _status = 'Loading your health data…');
    await minSplash;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );

    // If a catch-up notification cold-started the app, route to the manual sync
    // page on top of the dashboard and let it run the look-back.
    final payload = await NotificationService.takeLaunchPayload();
    if (payload == NotificationService.catchUpPayload && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SyncSettingsScreen(autoLookBack: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96.r,
              height: 96.r,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.monitor_heart_rounded,
                  size: 52.r, color: scheme.primary),
            ),
            SizedBox(height: 24.h),
            Text('Health Monitor',
                style: TextStyle(
                    fontSize: 24.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 8.h),
            Text('Offline-first health tracking',
                style: TextStyle(
                    fontSize: 14.sp, color: scheme.onSurfaceVariant)),
            SizedBox(height: 40.h),
            SizedBox(
              width: 22.r,
              height: 22.r,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: scheme.primary),
            ),
            SizedBox(height: 16.h),
            Text(_status,
                style: TextStyle(
                    fontSize: 13.sp, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
