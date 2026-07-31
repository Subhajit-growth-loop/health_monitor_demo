import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/neu_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../view_model/permission_controller.dart';
import '../view_model/sync_controller.dart';
import 'learn_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'today_screen.dart';

// ── Main screen ───────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
      // Pull fresh HealthKit data every time the dashboard is opened.
      ref.read(syncControllerProvider.notifier).refreshData();
    });
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final alreadyRequested =
        prefs.getBool('neu_health_permissions_requested') ?? false;
    if (alreadyRequested) return;
    if (!mounted) return;
    _showPermissionDialog();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Health Access Required'),
        content: const Text(
            'Allow access to your health data to see your metrics.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(permissionControllerProvider.notifier)
                  .requestAll();
              // Mark as requested so the dialog never shows again
              await ref
                  .read(sharedPreferencesProvider)
                  .setBool('neu_health_permissions_requested', true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: NeuColors.primary,
            ),
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final unselected =
        isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? NeuColors.darkBackground : NeuColors.screenBackground,
      floatingActionButton: Container(
        decoration: isDark
            ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: NeuColors.primary.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              )
            : null,
        child: FloatingActionButton(
          onPressed: () => setState(() => _tabIndex = 0),
          backgroundColor: NeuColors.primary,
          elevation: isDark ? 0 : 4,
          shape: const CircleBorder(),
          child: Image.asset(
            'assets/icons/logo_white.png',
            width: 40.r,
            height: 40.r,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const _WaveNotchedShape(),
        notchMargin: 6.0,
        color: isDark ? NeuColors.darkSurface : Colors.white,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 56.h,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.space_dashboard_rounded,
                label: 'Today',
                selected: _tabIndex == 0,
                unselectedColor: unselected,
                onTap: () => setState(() => _tabIndex = 0),
              ),
              _NavItem(
                icon: Icons.school_rounded,
                label: 'Learn',
                selected: _tabIndex == 1,
                unselectedColor: unselected,
                onTap: () => setState(() => _tabIndex = 1),
              ),
              SizedBox(width: 60.w),
              _NavItem(
                icon: Icons.monitor_heart_rounded,
                label: 'Progress',
                selected: _tabIndex == 2,
                unselectedColor: unselected,
                onTap: () => setState(() => _tabIndex = 2),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: _tabIndex == 3,
                unselectedColor: unselected,
                onTap: () => setState(() => _tabIndex = 3),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          TodayScreen(),
          LearnScreen(),
          ProgressScreen(),
          ProfileScreen(),
        ],
      ),
    );
  }
}

// ── Custom wave-notch shape for BottomAppBar ──────────────────────────────────

class _WaveNotchedShape extends NotchedShape {
  const _WaveNotchedShape();

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !host.overlaps(guest)) {
      return Path()..addRect(host);
    }

    final r = guest.width / 2 + 6.0; // notch radius (FAB radius + small gap)
    final cx = guest.center.dx;
    final top = host.top;
    final halfW = r * 2.4; // wave spread from center
    final depth = r * 1.05; // how deep the trough goes

    return Path()
      ..moveTo(host.left, top)
      ..lineTo(cx - halfW, top)
      // Left shoulder → trough
      ..cubicTo(
        cx - halfW * 0.5, top,
        cx - r, top + depth,
        cx, top + depth,
      )
      // Trough → right shoulder
      ..cubicTo(
        cx + r, top + depth,
        cx + halfW * 0.5, top,
        cx + halfW, top,
      )
      ..lineTo(host.right, top)
      ..lineTo(host.right, host.bottom)
      ..lineTo(host.left, host.bottom)
      ..close();
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.unselectedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NeuColors.primary : unselectedColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22.r),
            SizedBox(height: 3.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: color,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
