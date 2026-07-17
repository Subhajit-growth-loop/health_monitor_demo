import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/daily_point.dart';
import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/health_record.dart';
import '../../domain/entities/sync_status.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/trend_chart.dart';

enum _ChartPeriod {
  week(label: 'Week'),
  month(label: 'Month'),
  year(label: 'Year');

  const _ChartPeriod({required this.label});
  final String label;
}

class MetricDetailScreen extends ConsumerStatefulWidget {
  const MetricDetailScreen({super.key, required this.type});

  final HealthMetricType type;

  @override
  ConsumerState<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

class _MetricDetailScreenState extends ConsumerState<MetricDetailScreen> {
  _ChartPeriod _period = _ChartPeriod.week;

  bool get _isBP =>
      widget.type == HealthMetricType.bloodPressureSystolic;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DailyPoint>> series;
    final String Function(DateTime) labelFormatter;
    String Function(DateTime)? subLabelFormatter;
    final String periodLabel;

    switch (_period) {
      case _ChartPeriod.week:
        series = ref.watch(dailySeriesProvider((type: widget.type, days: 7)));
        labelFormatter = Fmt.dayShort;
        subLabelFormatter = Fmt.dayNum;
        periodLabel = 'Last 7 days';
      case _ChartPeriod.month:
        series =
            ref.watch(dailySeriesProvider((type: widget.type, days: 30)));
        labelFormatter = Fmt.dayNum;
        periodLabel = 'Last 30 days';
      case _ChartPeriod.year:
        series = ref
            .watch(monthlySeriesProvider((type: widget.type, months: 12)));
        labelFormatter = Fmt.monthShort;
        periodLabel = 'Last 12 months';
    }

    // For blood pressure, load diastolic series alongside systolic.
    final AsyncValue<List<DailyPoint>>? diastolicSeries = _isBP
        ? switch (_period) {
            _ChartPeriod.week => ref.watch(
                dailySeriesProvider((type: HealthMetricType.bloodPressureDiastolic, days: 7))),
            _ChartPeriod.month => ref.watch(
                dailySeriesProvider((type: HealthMetricType.bloodPressureDiastolic, days: 30))),
            _ChartPeriod.year => ref.watch(
                monthlySeriesProvider((type: HealthMetricType.bloodPressureDiastolic, months: 12))),
          }
        : null;

    final records = ref.watch(recordsForTypeProvider(widget.type));
    final AsyncValue<List<HealthRecord>>? diastolicRecords =
        _isBP ? ref.watch(recordsForTypeProvider(HealthMetricType.bloodPressureDiastolic)) : null;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(widget.type.icon, color: widget.type.color, size: 22.r),
            SizedBox(width: 8.w),
            Text(widget.type.label),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
          children: [
            // Period selector
            Row(
              children: [
                for (final period in _ChartPeriod.values) ...[
                  if (period != _ChartPeriod.values.first)
                    SizedBox(width: 8.w),
                  ChoiceChip(
                    label: Text(period.label),
                    selected: _period == period,
                    onSelected: (selected) {
                      if (selected) setState(() => _period = period);
                    },
                  ),
                ],
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              periodLabel,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12.h),
            Card(
              child: Padding(
                padding: EdgeInsets.fromLTRB(8.w, 20.h, 16.w, 8.h),
                child: series.when(
                  loading: () => SizedBox(
                    height: 220.h,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SizedBox(
                    height: 220.h,
                    child: Center(child: Text('$e')),
                  ),
                  data: (points) {
                    final diaPoints = diastolicSeries?.valueOrNull;
                    return TrendChart(
                      type: widget.type,
                      points: points,
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
            if (_isBP) _BpLegend(scheme: scheme),
            SizedBox(height: 24.h),
            Row(
              children: [
                Text(
                  'Recent readings',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'source · sync',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            _isBP
                ? _buildBpReadings(records, diastolicRecords, scheme)
                : records.when(
                    loading: () => Padding(
                      padding: EdgeInsets.only(top: 40.h),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (list) {
                      if (list.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.only(top: 40.h),
                          child:
                              const Center(child: Text('No readings yet')),
                        );
                      }
                      return Column(
                        children: [
                          for (final r in list.take(60))
                            _ReadingTile(
                              value: Fmt.metricValue(widget.type, r.value),
                              unit: widget.type.unit,
                              source: r.source,
                              time: Fmt.dateTime(r.timestamp),
                              status: r.syncStatus,
                              color: widget.type.color,
                            ),
                        ],
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBpReadings(
    AsyncValue<List<HealthRecord>> sysAsync,
    AsyncValue<List<HealthRecord>>? diaAsync,
    ColorScheme scheme,
  ) {
    final sysList = sysAsync.valueOrNull ?? [];
    final diaList = diaAsync?.valueOrNull ?? [];

    if (sysAsync.isLoading || diaAsync?.isLoading == true) {
      return Padding(
        padding: EdgeInsets.only(top: 40.h),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (sysList.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 40.h),
        child: const Center(child: Text('No readings yet')),
      );
    }

    // Pair by timestamp proximity (within 5 minutes).
    final paired = <(HealthRecord, HealthRecord?)>[];
    final diaRemaining = List<HealthRecord>.from(diaList);
    for (final sys in sysList.take(60)) {
      HealthRecord? match;
      for (var i = 0; i < diaRemaining.length; i++) {
        final diff = sys.timestamp.difference(diaRemaining[i].timestamp).abs();
        if (diff.inMinutes <= 5) {
          match = diaRemaining.removeAt(i);
          break;
        }
      }
      paired.add((sys, match));
    }

    return Column(
      children: [
        for (final (sys, dia) in paired)
          _ReadingTile(
            value: dia != null
                ? '${Fmt.metricValue(widget.type, sys.value)}/${Fmt.metricValue(HealthMetricType.bloodPressureDiastolic, dia.value)}'
                : Fmt.metricValue(widget.type, sys.value),
            unit: widget.type.unit,
            source: sys.source,
            time: Fmt.dateTime(sys.timestamp),
            status: sys.syncStatus,
            color: widget.type.color,
          ),
      ],
    );
  }
}

class _BpLegend extends StatelessWidget {
  const _BpLegend({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final type = HealthMetricType.bloodPressureSystolic;
    return Padding(
      padding: EdgeInsets.only(top: 12.h, left: 8.w),
      child: Row(
        children: [
          _dot(type.color),
          SizedBox(width: 6.w),
          Text('Systolic',
              style: TextStyle(fontSize: 12.sp, color: scheme.onSurfaceVariant)),
          SizedBox(width: 16.w),
          _dot(HealthMetricType.bloodPressureDiastolic.color,
              dashed: true),
          SizedBox(width: 6.w),
          Text('Diastolic',
              style: TextStyle(fontSize: 12.sp, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _dot(Color color, {bool dashed = false}) => Container(
        width: 24.w,
        height: 3.h,
        decoration: dashed
            ? null
            : BoxDecoration(color: color, borderRadius: BorderRadius.circular(2.r)),
        child: dashed
            ? CustomPaint(
                painter: _DashedLinePainter(color: color),
              )
            : null,
      );
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2),
          Offset((x + 5).clamp(0, size.width), size.height / 2), paint);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({
    required this.value,
    required this.unit,
    required this.source,
    required this.time,
    required this.status,
    required this.color,
  });

  final String value;
  final String unit;
  final String source;
  final String time;
  final SyncStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color c) = switch (status) {
      SyncStatus.synced => (Icons.cloud_done_rounded, scheme.primary),
      SyncStatus.pending => (Icons.cloud_upload_rounded, Colors.orange),
      SyncStatus.failed => (Icons.error_outline_rounded, scheme.error),
    };
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Container(
            width: 8.r,
            height: 8.r,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value $unit',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              source,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, color: scheme.onSurfaceVariant),
            ),
          ),
          SizedBox(width: 10.w),
          Icon(icon, size: 16.r, color: c),
        ],
      ),
    );
  }
}
