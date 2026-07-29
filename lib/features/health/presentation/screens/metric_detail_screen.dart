import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/neu_colors.dart';
import '../../../../core/theme/neu_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/daily_point.dart';
import '../../domain/entities/health_metric_type.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/trend_chart.dart';

enum _ChartPeriod {
  day(label: 'Day'),
  week(label: 'Week'),
  month(label: 'Month');

  const _ChartPeriod({required this.label});
  final String label;
}

class MetricDetailScreen extends ConsumerStatefulWidget {
  const MetricDetailScreen({super.key, required this.type});

  final HealthMetricType type;

  @override
  ConsumerState<MetricDetailScreen> createState() =>
      _MetricDetailScreenState();
}

class _MetricDetailScreenState extends ConsumerState<MetricDetailScreen> {
  _ChartPeriod _period = _ChartPeriod.day;

  bool get _isBP =>
      widget.type == HealthMetricType.bloodPressureSystolic;

  /// Percentage of points in [pts] whose value falls within [type]'s normal range.
  double _inRangePct(List<DailyPoint> pts) {
    if (pts.isEmpty) return 0;
    final range = _normalRange(widget.type);
    if (range == null) return 0;
    final inR = pts.where((p) => p.value >= range.$1 && p.value <= range.$2).length;
    return inR / pts.length * 100;
  }

  static (double, double)? _normalRange(HealthMetricType t) => switch (t) {
        HealthMetricType.bloodGlucose => (70.0, 180.0),
        HealthMetricType.heartRate => (60.0, 100.0),
        HealthMetricType.restingHeartRate => (50.0, 90.0),
        HealthMetricType.bloodPressureSystolic => (90.0, 130.0),
        HealthMetricType.bloodPressureDiastolic => (60.0, 80.0),
        HealthMetricType.bloodOxygen => (95.0, 100.0),
        HealthMetricType.heartRateVariability => (20.0, 200.0),
        _ => null,
      };

  /// Trim leading zero-value points so the chart starts from the first real
  /// reading. Always keeps at least [minLength] points from the end.
  static List<DailyPoint> _trim(List<DailyPoint> pts, int minLength) {
    final firstData = pts.indexWhere((p) => p.value > 0);
    if (firstData <= 0) return pts;
    final trimFrom = math.max(0, math.min(firstData, pts.length - minLength));
    return pts.sublist(trimFrom);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final subtle = isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    final AsyncValue<List<DailyPoint>> rawSeries;
    final String Function(DateTime) labelFormatter;
    String Function(DateTime)? subLabelFormatter;
    const int minDay = 30, minWeek = 10, minMonth = 12;

    switch (_period) {
      case _ChartPeriod.day:
        rawSeries = ref.watch(dailySeriesProvider((type: widget.type, days: 365)));
        labelFormatter = Fmt.dayShort;
        subLabelFormatter = Fmt.dayNum;
      case _ChartPeriod.week:
        rawSeries = ref.watch(weeklySeriesProvider((type: widget.type, weeks: 52)));
        labelFormatter = Fmt.weekLabel;
      case _ChartPeriod.month:
        rawSeries = ref.watch(monthlySeriesProvider((type: widget.type, months: 24)));
        labelFormatter = Fmt.monthShort;
    }

    final series = rawSeries.whenData((pts) => switch (_period) {
          _ChartPeriod.day => _trim(pts, minDay),
          _ChartPeriod.week => _trim(pts, minWeek),
          _ChartPeriod.month => _trim(pts, minMonth),
        });

    final AsyncValue<List<DailyPoint>>? diastolicSeries = _isBP
        ? switch (_period) {
            _ChartPeriod.day => ref.watch(dailySeriesProvider(
                (type: HealthMetricType.bloodPressureDiastolic, days: 365))),
            _ChartPeriod.week => ref.watch(weeklySeriesProvider(
                (type: HealthMetricType.bloodPressureDiastolic, weeks: 52))),
            _ChartPeriod.month => ref.watch(monthlySeriesProvider(
                (type: HealthMetricType.bloodPressureDiastolic, months: 24))),
          }
        : null;

    final double currentValue =
        series.valueOrNull?.lastWhere((p) => p.value > 0,
            orElse: () => DailyPoint(day: DateTime.now(), value: 0)).value ??
            0;

    final points =
        series.valueOrNull?.where((p) => p.value > 0).toList() ?? [];
    final double avgValue = points.isEmpty
        ? 0
        : points.map((p) => p.value).reduce((a, b) => a + b) / points.length;
    final double maxValue = points.isEmpty
        ? 0
        : points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final double inRangePct = _inRangePct(points);

    // Previous 5 readings from current period series (latest non-zero)
    final recentPoints = series.valueOrNull
            ?.where((p) => p.value > 0)
            .toList()
            .reversed
            .take(5)
            .toList() ??
        [];

    return Scaffold(
      backgroundColor:
          isDark ? NeuColors.darkBackground : NeuColors.screenBackground,
      body: SafeArea(
        child: ListView(
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36.r,
                      height: 36.r,
                      decoration: BoxDecoration(
                        color: isDark ? NeuColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isDark
                              ? NeuColors.darkBorder
                              : NeuColors.inputBorder,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: isDark ? Colors.white : NeuColors.textDark,
                        size: 20.r,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.type.label,
                        style: NeuTypography.serif(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, d MMMM').format(DateTime.now()),
                        style: NeuTypography.sans(
                          fontSize: 12.sp,
                          color: subtle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(
                color: isDark ? NeuColors.darkBorder : NeuColors.inputBorder),
            SizedBox(height: 16.h),

            // ── Large current value ──────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currentValue > 0
                        ? Fmt.metricValue(widget.type, currentValue)
                        : '—',
                    style: NeuTypography.serif(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  if (widget.type.unit.isNotEmpty) ...[
                    SizedBox(width: 6.w),
                    Text(
                      widget.type.unit,
                      style: NeuTypography.sans(
                        fontSize: 16.sp,
                        color: subtle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 8.h),

            // ── Status row ───────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Text(
                    'Steadiest day so far',
                    style: NeuTypography.sans(
                      fontSize: 13.sp,
                      color: subtle,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'In range',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // ── Period selector ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? NeuColors.darkBorder
                      : const Color(0xFFEDE5DC),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    for (final period in _ChartPeriod.values)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _period = period),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: EdgeInsets.symmetric(vertical: 9.h),
                            decoration: BoxDecoration(
                              color: _period == period
                                  ? (isDark
                                      ? NeuColors.darkCard
                                      : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9.r),
                              boxShadow: _period == period
                                  ? [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                period.label,
                                style: NeuTypography.sans(
                                  fontSize: 13.sp,
                                  color: _period == period
                                      ? (isDark
                                          ? Colors.white
                                          : NeuColors.textDark)
                                      : subtle,
                                  fontWeight: _period == period
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // ── Chart ────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? NeuColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isDark
                        ? NeuColors.darkBorder
                        : NeuColors.inputBorder,
                  ),
                ),
                padding: EdgeInsets.fromLTRB(8.w, 16.h, 8.w, 8.h),
                child: series.when(
                  loading: () => SizedBox(
                    height: 200.h,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: NeuColors.primary),
                    ),
                  ),
                  error: (e, _) => SizedBox(
                    height: 200.h,
                    child: Center(
                      child: Text('$e',
                          style: TextStyle(color: subtle, fontSize: 12.sp)),
                    ),
                  ),
                  data: (pts) {
                    final diaPoints = diastolicSeries?.valueOrNull;
                    return TrendChart(
                      type: widget.type,
                      points: pts,
                      bottomLabelFormatter: labelFormatter,
                      bottomSubLabelFormatter: subLabelFormatter,
                      secondaryPoints: diaPoints,
                      secondaryType: diaPoints != null
                          ? HealthMetricType.bloodPressureDiastolic
                          : null,
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // ── 3 stat pills (equal height via IntrinsicHeight) ──────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Expanded(
                    child: _StatPill(
                      label: 'Average',
                      value: avgValue,
                      type: widget.type,
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _InRangePill(
                      pct: inRangePct,
                      isDark: isDark,
                      hasRange: _normalRange(widget.type) != null,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _StatPill(
                      label: 'Highest',
                      value: maxValue,
                      type: widget.type,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            ),
            SizedBox(height: 24.h),

            // ── Previous 5 readings ──────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Text(
                    'Previous 5 readings',
                    style: NeuTypography.sans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Avg. in range',
                    style: NeuTypography.sans(
                      fontSize: 12.sp,
                      color: NeuColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            if (recentPoints.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 20.w, vertical: 20.h),
                child: Center(
                  child: Text(
                    'No recent readings',
                    style: TextStyle(color: subtle, fontSize: 13.sp),
                  ),
                ),
              )
            else
              for (var i = 0; i < recentPoints.length; i++) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 20.w, vertical: 8.h),
                  child: Row(
                    children: [
                      Container(
                        width: 8.r,
                        height: 8.r,
                        decoration: BoxDecoration(
                          color: NeuColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          _readingLabel(recentPoints[i].day),
                          style: NeuTypography.sans(
                            fontSize: 13.sp,
                            color: fg,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${Fmt.metricValue(widget.type, recentPoints[i].value)}'
                            '${widget.type.unit.isNotEmpty ? ' ${widget.type.unit}' : ''}',
                            style: NeuTypography.sans(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: fg,
                            ),
                          ),
                          if (_normalRange(widget.type) != null)
                            Text(
                              _pointInRangeLabel(recentPoints[i]),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: NeuColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (i < recentPoints.length - 1)
                  Divider(
                    indent: 20.w,
                    endIndent: 20.w,
                    color: isDark
                        ? NeuColors.darkBorder
                        : NeuColors.inputBorder,
                  ),
              ],

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  String _readingLabel(DateTime day) {
    switch (_period) {
      case _ChartPeriod.day:
        return DateFormat('MMMM d, EEEE').format(day);
      case _ChartPeriod.week:
        return Fmt.weekLabel(day);
      case _ChartPeriod.month:
        return DateFormat('MMMM yyyy').format(day);
    }
  }

  String _pointInRangeLabel(DailyPoint p) {
    final range = _normalRange(widget.type);
    if (range == null) return '';
    final inRange = p.value >= range.$1 && p.value <= range.$2;
    if (!inRange) return 'Out of range';
    // Score: closeness to center of range
    final center = (range.$1 + range.$2) / 2;
    final span = (range.$2 - range.$1) / 2;
    final score = span > 0
        ? ((1 - (p.value - center).abs() / span) * 100).clamp(0.0, 100.0)
        : 100.0;
    return '${score.round()}%';
  }
}

// ── Stat pill ──────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.type,
    required this.isDark,
  });

  final String label;
  final double value;
  final HealthMetricType type;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final subtle = isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: isDark ? NeuColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? NeuColors.darkBorder : NeuColors.inputBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value > 0
                ? '${Fmt.metricValue(type, value)}${type.unit.isNotEmpty ? ' ${type.unit}' : ''}'
                : '—',
            style: NeuTypography.serif(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: NeuTypography.sans(
              fontSize: 11.sp,
              color: subtle,
            ),
          ),
        ],
      ),
    );
  }
}

// ── In-range pill ─────────────────────────────────────────────────────────────

class _InRangePill extends StatelessWidget {
  const _InRangePill({
    required this.pct,
    required this.isDark,
    required this.hasRange,
  });

  final double pct;
  final bool isDark;
  final bool hasRange;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : NeuColors.textDark;
    final subtle = isDark ? NeuColors.darkTextMuted : NeuColors.textSecondary;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: isDark ? NeuColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? NeuColors.darkBorder : NeuColors.inputBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasRange ? '${pct.round()}%' : '—',
            style: NeuTypography.serif(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'In range',
            style: NeuTypography.sans(
              fontSize: 11.sp,
              color: subtle,
            ),
          ),
        ],
      ),
    );
  }
}
