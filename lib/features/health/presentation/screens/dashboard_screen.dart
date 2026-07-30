import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/session/app_error_handler.dart';
import '../../../../core/session/current_user.dart';
import '../../../../core/session/token_manager.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/neu_colors.dart';
import '../../../../core/theme/neu_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/health_metric_type.dart';
import '../providers/dashboard_providers.dart';
import '../providers/health_providers.dart';
import '../providers/permission_controller.dart';
import '../providers/sync_controller.dart';
import '../widgets/static_sparkline.dart';
import 'metric_detail_screen.dart';
import 'sync_settings_screen.dart';
import 'your_vitals_screen.dart';
import '../../../neu/presentation/screens/neu_login_screen.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';

// ── Export helpers ────────────────────────────────────────────────────────────

Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
  final mode = await showModalBottomSheet<_ExportMode>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Export health data (JSON)',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text('Share'),
            subtitle: const Text('Send via the share sheet or Save to Files'),
            onTap: () => Navigator.of(ctx).pop(_ExportMode.share),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: const Text('Save to device'),
            subtitle: const Text('Write the file to your device storage'),
            onTap: () => Navigator.of(ctx).pop(_ExportMode.save),
          ),
          SizedBox(height: 8.h),
        ],
      ),
    ),
  );

  if (mode == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(healthExportServiceProvider);
  messenger.showSnackBar(const SnackBar(content: Text('Preparing export…')));
  try {
    final export = mode == _ExportMode.share
        ? await service.share()
        : await service.save();
    messenger.hideCurrentSnackBar();
    if (export == null) return;
    if (export.recordCount == 0) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'No health data to export. Grant access and refresh first.'),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(
          mode == _ExportMode.save
              ? 'Saved ${export.recordCount} records (${export.sizeLabel}) to device.'
              : 'Exported ${export.recordCount} records (${export.sizeLabel}).',
        ),
      ));
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

enum _ExportMode { share, save }

// ── Logout ────────────────────────────────────────────────────────────────────

/// Ends the session: `POST /auth/logout` with the stored refresh token, then
/// clears local credentials and returns to the login screen.
///
/// The local session is cleared even when the network call fails — a user who
/// asked to log out must not stay signed in on the device because the server
/// was unreachable. The API error is still surfaced.
Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
          "You'll need to sign in again to see your health data."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: NeuColors.primary),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(onboardingRepositoryProvider);
  final refreshToken = TokenManager.instance.refreshToken;

  String? apiError;
  try {
    if (refreshToken != null) {
      await repo.logout(refreshToken);
    }
    // No refresh token stored — nothing for the server to revoke, so the local
    // clear below is the whole logout.
  } catch (e) {
    apiError = AppErrorHandler.instance.handle(e, context: 'Logout');
  }

  await TokenManager.instance.clearToken();
  await CurrentUser.instance.clear();
  final prefs = ref.read(sharedPreferencesProvider);
  await Future.wait([
    clearSyncPrefsOnLogout(prefs),
    prefs.remove('neu_health_permissions_requested'),
    ref.read(localDataSourceProvider).clearAll(),
  ]);

  if (!context.mounted) return;
  if (apiError != null) {
    messenger.showSnackBar(
      SnackBar(content: Text('Signed out locally — $apiError')),
    );
  }
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const NeuLoginScreen()),
    (_) => false,
  );
}

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
        children: [
          _TodayTab(isDark: isDark),
          _LearnTab(isDark: isDark),
          _ProgressTab(isDark: isDark),
          _ProfileTab(isDark: isDark),
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

// ── Today Tab ─────────────────────────────────────────────────────────────────

class _TodayTab extends ConsumerWidget {
  const _TodayTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final subtle = isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;
    final firstName = CurrentUser.instance.firstName;

    return SafeArea(
      child: RefreshIndicator(
        color: NeuColors.primary,
        onRefresh: () =>
            ref.read(syncControllerProvider.notifier).refreshData(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 32.h),
          children: [
            // ── Header row ───────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 40.r,
                    height: 40.r,
                    decoration: BoxDecoration(
                      color: isDark ? NeuColors.darkCard : NeuColors.accentYellow,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'N',
                        style: NeuTypography.sans(
                          fontSize: 14.sp,
                          color: NeuColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: NeuTypography.sans(
                          fontSize: 13.sp,
                          color: subtle,
                        ),
                      ),
                      // Read from the stored session, not the onboarding
                      // controller: watching that provider here re-ran the
                      // whole onboarding fetch (GET /onboarding + GET
                      // /patient/me/details) on every dashboard open, and the
                      // name popped in late once it resolved.
                      Text(
                        firstName.isEmpty ? 'Good day' : firstName,
                        style: NeuTypography.serif(
                          fontSize: 22.sp,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Bell icon with badge
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Notifications coming soon')),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40.r,
                          height: 40.r,
                          decoration: BoxDecoration(
                            color: isDark ? NeuColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isDark
                                  ? NeuColors.darkBorder
                                  : NeuColors.inputBorder,
                            ),
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            color: isDark ? Colors.white : NeuColors.textDark,
                            size: 20.r,
                          ),
                        ),
                        // Positioned(
                        //   top: 6.r,
                        //   right: 6.r,
                        //   child: Container(
                        //     width: 6.r,
                        //     height: 6.r,
                        //     decoration: const BoxDecoration(
                        //       color: Colors.red,
                        //       shape: BoxShape.circle,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // ── Banner placeholder ────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: SizedBox(
                height: 120.h,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? NeuColors.darkCard
                        : NeuColors.featureBackground,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // ── Insight card ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: _InsightCard(isDark: isDark),
            ),
            SizedBox(height: 16.h),

            // ── Morning check-in card ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: _MorningCheckinCard(isDark: isDark),
            ),
            SizedBox(height: 20.h),

            // ── Your vitals row ───────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Text(
                    'Your vitals',
                    style: NeuTypography.sans(
                      fontSize: 16.sp,
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const YourVitalsScreen()),
                    ),
                    child: Text(
                      'See all',
                      style: NeuTypography.sans(
                        fontSize: 13.sp,
                        color: NeuColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),

            // ── Mini vitals grid ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: _VitalsMiniGrid(isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Insight card (gauge + scores) ─────────────────────────────────────────────

class _InsightCard extends ConsumerWidget {
  const _InsightCard({required this.isDark});
  final bool isDark;

  String _formatSleepHours(double totalHours) {
    final h = totalHours.floor();
    final m = ((totalHours - h) * 60).round();
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = isDark ? NeuColors.darkCard : Colors.white;
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final subtle = isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;
    final trackColor =
        isDark ? NeuColors.darkBorder : const Color(0xFFEDE5DC);
    final summary = ref.watch(todaySummaryProvider);

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? NeuColors.darkBorder : NeuColors.inputBorder,
        ),
      ),
      child: summary.when(
        // Keep the last values on screen while a re-query runs. Without
        // skipLoadingOnReload an invalidation swaps the whole card for a
        // spinner, which read as a flash on every sync.
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => Center(
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: CircularProgressIndicator(
              color: NeuColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (e, _) => Text(
          'Unable to load scores',
          style: TextStyle(color: subtle, fontSize: 12.sp),
        ),
        data: (values) {
          final sleepVal = values[HealthMetricType.sleep] ?? 0.0;
          final sleepText = sleepVal > 0 ? _formatSleepHours(sleepVal) : '--';

          final nonZeroVals = values.values.where((v) => v > 0).toList();
          final overall = nonZeroVals.isEmpty
              ? 0.0
              : (nonZeroVals.reduce((a, b) => a + b) /
                      nonZeroVals.length /
                      100)
                  .clamp(0.0, 1.0);

          final glucoseVal = values[HealthMetricType.bloodGlucose] ?? 0.0;
          final stepsVal = values[HealthMetricType.steps] ?? 0.0;

          final glucoseScore = (glucoseVal / 200.0).clamp(0.0, 1.0);
          final stepsScore = (stepsVal / 10000.0).clamp(0.0, 1.0);
          final sleepScore = (sleepVal / 8.0).clamp(0.0, 1.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: sleep value + "On Track" pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sleepText,
                        style: NeuTypography.serif(
                          fontSize: 22.sp,
                          color: fg,
                        ),
                      ),
                      Text(
                        'Steady',
                        style: NeuTypography.sans(
                          fontSize: 13.sp,
                          color: subtle,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color:
                            const Color(0xFF2E7D32).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'On Track',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Gauge
              SizedBox(
                width: double.infinity,
                height: 110.r,
                child: CustomPaint(
                  painter: _GaugePainter(
                    progress: overall.clamp(0.0, 1.0),
                    trackColor: trackColor,
                    fillColor: NeuColors.primary,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(overall * 100).round()}%',
                            style: NeuTypography.serif(
                              fontSize: 24.sp,
                              color: fg,
                            ),
                          ),
                          Text(
                            'Time in range',
                            style: NeuTypography.sans(
                              fontSize: 12.sp,
                              color: subtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Divider(
                  color: isDark ? NeuColors.darkBorder : NeuColors.inputBorder),
              SizedBox(height: 12.h),

              // Score circles row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ScoreCircle(
                    label: 'Glucose',
                    score: glucoseScore,
                    color: NeuColors.primary,
                    trackColor: trackColor,
                    fg: fg,
                    subtle: subtle,
                  ),
                  _ScoreCircle(
                    label: 'Movement',
                    score: stepsScore,
                    color: const Color(0xFF8D9E39),
                    trackColor: trackColor,
                    fg: fg,
                    subtle: subtle,
                  ),
                  _ScoreCircle(
                    label: 'Sleep',
                    score: sleepScore,
                    color: const Color(0xFF4A7C59),
                    trackColor: trackColor,
                    fg: fg,
                    subtle: subtle,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 4;
    final radius = size.width / 2 - 8;

    final base = Paint()
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      math.pi,
      math.pi,
      false,
      base..color = trackColor,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        math.pi,
        math.pi * progress.clamp(0.0, 1.0),
        false,
        base..color = fillColor,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({
    required this.label,
    required this.score,
    required this.color,
    required this.trackColor,
    required this.fg,
    required this.subtle,
  });

  final String label;
  final double score;
  final Color color;
  final Color trackColor;
  final Color fg;
  final Color subtle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44.r,
          height: 44.r,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: score,
                strokeWidth: 5,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                '${(score * 100).round()}',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        Text(label, style: TextStyle(fontSize: 10.sp, color: subtle)),
      ],
    );
  }
}

// ── Morning check-in card ─────────────────────────────────────────────────────

class _MorningCheckinCard extends StatelessWidget {
  const _MorningCheckinCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? NeuColors.darkCard : const Color(0xFFFAF3EE);
    final subtle = isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark
              ? NeuColors.darkBorder
              : const Color(0xFFE6DED5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              color: NeuColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Center(
              child: Icon(
                Icons.favorite_rounded,
                color: NeuColors.primary,
                size: 22.r,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Morning Check-in',
                  style: NeuTypography.sans(
                    fontSize: 14.sp,
                    color: isDark ? Colors.white : NeuColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'A quick read on energy & stress',
                  style: NeuTypography.sans(
                    fontSize: 12.sp,
                    color: subtle,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon')),
              );
            },
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF18B5C),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'Start',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vitals mini grid ──────────────────────────────────────────────────────────

class _VitalsMiniGrid extends ConsumerWidget {
  const _VitalsMiniGrid({required this.isDark});
  final bool isDark;

  /// Fixed, not data-dependent. Picking cards by "which metrics have data"
  /// meant the grid swapped cards in and out as each provider resolved — the
  /// second half of the flicker. The set is now stable across every load.
  static const _kTypes = [
    HealthMetricType.bloodGlucose,
    HealthMetricType.steps,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider);
    // Always render — use an empty map while loading/error so the cards keep
    // their place in the layout instead of appearing late.
    final values = summary.valueOrNull ?? {};
    final demoTypes = ref.watch(demoFilledTypesProvider).valueOrNull ?? const {};

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12.r,
      crossAxisSpacing: 12.r,
      childAspectRatio: 0.95,
      children: [
        for (final type in _kTypes)
          _VitalMiniCard(
            type: type,
            summaryValue: values[type] ?? 0,
            isDark: isDark,
            isSample: demoTypes.contains(type),
          ),
      ],
    );
  }
}

class _VitalMiniCard extends StatelessWidget {
  const _VitalMiniCard({
    required this.type,
    required this.summaryValue,
    required this.isDark,
    this.isSample = false,
  });

  final HealthMetricType type;
  final double summaryValue;
  final bool isDark;

  /// The value came from [DemoHealthData], not the device.
  final bool isSample;

  bool get _hasData => summaryValue > 0;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? NeuColors.darkCard : Colors.white;
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final subtle = isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;
    final iconColor =
        _hasData ? NeuColors.primary : (isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary);
    final iconBg = _hasData
        ? NeuColors.primary.withValues(alpha: 0.15)
        : (isDark ? NeuColors.darkBorder.withValues(alpha: 0.4) : const Color(0xFFF0EEEC));

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MetricDetailScreen(type: type)),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(14.r, 14.r, 14.r, 8.r),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark ? NeuColors.darkBorder : NeuColors.inputBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 30.r,
                  height: 30.r,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(type.icon, color: iconColor, size: 16.r),
                ),
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(
                    type.label,
                    style: NeuTypography.sans(
                      fontSize: 12.sp,
                      color: _hasData ? fg : subtle,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // Sparkline or empty-state placeholder
            if (_hasData)
              StaticSparkline(type: type, height: 42.h)
            else
              _EmptySparkline(height: 42.h, isDark: isDark),
            SizedBox(height: 6.h),

            // Value
            if (type == HealthMetricType.steps && _hasData)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    Fmt.metricValue(type, summaryValue),
                    style: NeuTypography.serif(fontSize: 20.sp, color: fg),
                  ),
                  Text(
                    '/6,000',
                    style: NeuTypography.sans(fontSize: 11.sp, color: subtle),
                  ),
                ],
              )
            else if (_hasData && type.unit.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    Fmt.metricValue(type, summaryValue),
                    style: NeuTypography.serif(fontSize: 20.sp, color: fg),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    type.unit,
                    style: NeuTypography.sans(fontSize: 11.sp, color: subtle),
                  ),
                ],
              )
            else
              Text(
                _hasData ? Fmt.metricValue(type, summaryValue) : '—',
                style: NeuTypography.serif(
                  fontSize: 20.sp,
                  color: _hasData ? fg : subtle,
                ),
              ),
            if (!_hasData && type != HealthMetricType.steps && type.unit.isNotEmpty)
              Text(
                'No data yet',
                style: TextStyle(fontSize: 11.sp, color: subtle),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptySparkline extends StatelessWidget {
  const _EmptySparkline({required this.height, required this.isDark});
  final double height;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final dotColor = isDark
        ? NeuColors.darkBorder
        : const Color(0xFFE2DDD8);
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          12,
          (i) => Container(
            width: 3.r,
            height: 3.r + (i % 3) * 2.r,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Learn Tab ─────────────────────────────────────────────────────────────────

class _LearnTab extends StatelessWidget {
  const _LearnTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final subtle =
        isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learn',
              style: NeuTypography.serif(fontSize: 24.sp, color: fg),
            ),
            SizedBox(height: 40.h),
            Center(
              child: Text(
                'Articles and insights coming soon.',
                style: TextStyle(color: subtle, fontSize: 14.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress Tab ──────────────────────────────────────────────────────────────

class _ProgressTab extends StatelessWidget {
  const _ProgressTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final subtle = isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress',
              style: NeuTypography.serif(fontSize: 24.sp, color: fg),
            ),
            SizedBox(height: 40.h),
            Center(
              child: Text(
                'Progress coming soon.',
                style: TextStyle(color: subtle, fontSize: 14.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final cardBg = isDark ? NeuColors.darkCard : Colors.white;
    final cardBorder =
        isDark ? NeuColors.darkBorder : NeuColors.inputBorder;
    final subtle =
        isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 40.h),
        children: [
          Text(
            'Profile',
            style: NeuTypography.serif(fontSize: 24.sp, color: fg),
          ),
          SizedBox(height: 24.h),
          _SectionLabel(label: 'Appearance', isDark: isDark),
          SizedBox(height: 10.h),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: cardBorder),
            ),
            child: _ProfileTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark mode',
              isDark: isDark,
              trailing: Switch(
                value: isDarkMode,
                onChanged: (v) => ref
                    .read(themeModeProvider.notifier)
                    .setMode(v ? ThemeMode.dark : ThemeMode.light),
                activeThumbColor: NeuColors.primary,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          _SectionLabel(label: 'Data', isDark: isDark),
          SizedBox(height: 10.h),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.sync_rounded,
                  title: 'Sync settings',
                  isDark: isDark,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: subtle,
                    size: 20.r,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SyncSettingsScreen()),
                  ),
                ),
                Divider(height: 0, color: cardBorder, indent: 52.w),
                _ProfileTile(
                  icon: Icons.download_rounded,
                  title: 'Export health data',
                  isDark: isDark,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: subtle,
                    size: 20.r,
                  ),
                  onTap: () => _handleExport(context, ref),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _SectionLabel(label: 'Account', isDark: isDark),
          SizedBox(height: 10.h),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              children: [
                if (CurrentUser.instance.email.isNotEmpty)
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            color: NeuColors.primary, size: 20.r),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (CurrentUser.instance.name.isNotEmpty)
                                Text(
                                  CurrentUser.instance.name,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: fg,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              Text(
                                CurrentUser.instance.email,
                                style:
                                    TextStyle(fontSize: 12.sp, color: subtle),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (CurrentUser.instance.email.isNotEmpty)
                  Divider(height: 0, color: cardBorder, indent: 52.w),
                _ProfileTile(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  isDark: isDark,
                  titleColor: const Color(0xFFD63031),
                  iconColor: const Color(0xFFD63031),
                  onTap: () => _handleLogout(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: isDark ? NeuColors.darkTextMuted : NeuColors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.isDark,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final bool isDark;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Overrides for destructive actions (log out).
  final Color? titleColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final fg = titleColor ?? (isDark ? Colors.white : NeuColors.textDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? NeuColors.primary, size: 20.r),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

