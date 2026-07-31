import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/session/current_user.dart';
import '../../../../core/theme/neu_colors.dart';
import '../../../../core/theme/neu_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/health_metric_type.dart';
import '../view_model/dashboard_view_model.dart';
import '../view_model/sync_controller.dart';
import '../widgets/static_sparkline.dart';
import 'metric_detail_screen.dart';
import 'your_vitals_screen.dart';

// ── Today Screen ──────────────────────────────────────────────────────────────

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
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
              padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 0),
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
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                        style: NeuTypography.sans(
                          fontSize: 20.sp,
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
              child: InsightCard(isDark: isDark),
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
              child: VitalsMiniGrid(isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Insight card (gauge + scores) ─────────────────────────────────────────────

class InsightCard extends ConsumerWidget {
  const InsightCard({super.key, required this.isDark});
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

    // Always render the full layout — use an empty map while loading so the
    // card never swaps its structure for a spinner (no layout shift or flicker).
    final values = ref.watch(todaySummaryProvider).valueOrNull
        ?? const <HealthMetricType, double>{};

    final sleepVal = values[HealthMetricType.sleep] ?? 0.0;
    final sleepText = sleepVal > 0 ? _formatSleepHours(sleepVal) : '--';

    final nonZeroVals = values.values.where((v) => v > 0).toList();
    final overall = nonZeroVals.isEmpty
        ? 0.0
        : (nonZeroVals.reduce((a, b) => a + b) / nonZeroVals.length / 100)
            .clamp(0.0, 1.0);

    final glucoseVal = values[HealthMetricType.bloodGlucose] ?? 0.0;
    final stepsVal = values[HealthMetricType.steps] ?? 0.0;

    final glucoseScore = (glucoseVal / 200.0).clamp(0.0, 1.0);
    final stepsScore = (stepsVal / 10000.0).clamp(0.0, 1.0);
    final sleepScore = (sleepVal / 8.0).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? NeuColors.darkBorder : NeuColors.inputBorder,
        ),
      ),
      child: Column(
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
                    style: NeuTypography.serif(fontSize: 22.sp, color: fg),
                  ),
                  Text(
                    'Steady',
                    style: NeuTypography.sans(fontSize: 13.sp, color: subtle),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
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
                        style: NeuTypography.serif(fontSize: 24.sp, color: fg),
                      ),
                      Text(
                        'Time in range',
                        style: NeuTypography.sans(fontSize: 12.sp, color: subtle),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Divider(color: isDark ? NeuColors.darkBorder : NeuColors.inputBorder),
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

class VitalsMiniGrid extends ConsumerWidget {
  const VitalsMiniGrid({super.key, required this.isDark});
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
          VitalMiniCard(
            type: type,
            summaryValue: values[type] ?? 0,
            isDark: isDark,
            isSample: demoTypes.contains(type),
          ),
      ],
    );
  }
}

class VitalMiniCard extends StatelessWidget {
  const VitalMiniCard({
    super.key,
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
