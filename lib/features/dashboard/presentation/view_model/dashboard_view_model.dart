import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo/demo_health_data.dart';
import '../../domain/entities/daily_point.dart';
import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/health_record.dart';
import 'health_view_model.dart';

/// All read providers below re-run whenever [healthChangesProvider] fires,
/// keeping the UI bound to the local database as its single source of truth.
///
/// Each one falls back to [DemoHealthData] when the database has nothing for a
/// metric, so an un-permissioned or empty device still shows a populated
/// dashboard. The fallback is applied here — at read time — and never written
/// back, so sync and export continue to see real records only.

/// Collapses rapid DB-change events (multiple writes during a platform sync
/// batch) into a single notification. Without this, every individual record
/// written triggers a re-query, causing the UI to rebuild dozens of times per
/// sync cycle and appear to "flicker" as values update repeatedly.
final _healthChangesDebouncedProvider = StreamProvider<void>((ref) {
  final controller = StreamController<void>.broadcast();
  Timer? timer;

  ref.listen<AsyncValue<void>>(healthChangesProvider, (_, next) {
    if (next is AsyncData) {
      timer?.cancel();
      timer = Timer(
        const Duration(milliseconds: 350),
        () => controller.add(null),
      );
    }
  });

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// The date shown on the dashboard. Defaults to today (midnight).
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Summary straight from the database, with no demo substitution. Use this when
/// you need to know what is genuinely recorded.
final rawTodaySummaryProvider =
    FutureProvider<Map<HealthMetricType, double>>((ref) async {
  ref.watch(_healthChangesDebouncedProvider);
  final date = ref.watch(selectedDateProvider);
  return ref.watch(healthRepositoryProvider).summaryForDate(date);
});

/// Summary for the currently selected dashboard date, with sample values filled
/// in for dashboard metrics that have none.
final todaySummaryProvider =
    FutureProvider<Map<HealthMetricType, double>>((ref) async {
  final raw = await ref.watch(rawTodaySummaryProvider.future);
  if (!DemoHealthData.enabled) return raw;

  final filled = Map<HealthMetricType, double>.from(raw);
  for (final type in HealthMetricType.values) {
    if ((filled[type] ?? 0) <= 0) {
      filled[type] = DemoHealthData.summaryValue(type);
    }
  }
  return filled;
});

/// The metrics currently showing sample rather than recorded data, so the UI can
/// label them honestly.
final demoFilledTypesProvider =
    FutureProvider<Set<HealthMetricType>>((ref) async {
  if (!DemoHealthData.enabled) return const {};
  final raw = await ref.watch(rawTodaySummaryProvider.future);
  return {
    for (final type in HealthMetricType.values)
      if ((raw[type] ?? 0) <= 0) type,
  };
});

final dailySeriesProvider = FutureProvider.family<List<DailyPoint>,
    ({HealthMetricType type, int days})>((ref, arg) async {
  ref.watch(_healthChangesDebouncedProvider);
  final series = await ref
      .watch(healthRepositoryProvider)
      .dailySeries(arg.type, days: arg.days);
  if (!DemoHealthData.isSeriesEmpty(series)) return series;
  return DemoHealthData.dailySeries(arg.type, length: arg.days);
});

final monthlySeriesProvider = FutureProvider.family<List<DailyPoint>,
    ({HealthMetricType type, int months})>((ref, arg) async {
  ref.watch(_healthChangesDebouncedProvider);
  final series = await ref
      .watch(healthRepositoryProvider)
      .monthlySeries(arg.type, months: arg.months);
  if (!DemoHealthData.isSeriesEmpty(series)) return series;
  // Sample data only spans a few days, so a monthly view gets one populated
  // bucket (this month) rather than a fabricated year of history.
  final daily = DemoHealthData.dailySeries(arg.type, length: 1);
  return [
    for (var i = 0; i < series.length; i++)
      DailyPoint(day: series[i].day, value: i == 0 && daily.isNotEmpty ? daily.first.value : 0),
  ];
});

final recordsForTypeProvider =
    FutureProvider.family<List<HealthRecord>, HealthMetricType>(
        (ref, type) async {
  ref.watch(_healthChangesDebouncedProvider);
  final records = await ref.watch(healthRepositoryProvider).recordsForType(type);
  if (records.isNotEmpty) return records;
  return DemoHealthData.records(type);
});

/// Weekly aggregates: groups [weeks] × 7 daily points into one value per week.
/// The representative date for each week is the first day of that 7-day bucket.
final weeklySeriesProvider = FutureProvider.family<List<DailyPoint>,
    ({HealthMetricType type, int weeks})>((ref, arg) async {
  // Built on the daily provider so it inherits the same demo fallback rather
  // than duplicating the check.
  final daily = await ref.watch(
    dailySeriesProvider((type: arg.type, days: arg.weeks * 7)).future,
  );

  final result = <DailyPoint>[];
  for (var w = 0; w < arg.weeks; w++) {
    final from = w * 7;
    if (from >= daily.length) break;
    final to = math.min(from + 7, daily.length);
    final slice = daily.sublist(from, to);
    final nonZero = slice.where((p) => p.value > 0).toList();

    double value = 0;
    if (nonZero.isNotEmpty) {
      final sum = nonZero.fold(0.0, (s, p) => s + p.value);
      value = arg.type.aggregation == Aggregation.sum
          ? sum
          : sum / nonZero.length;
    }
    result.add(DailyPoint(day: slice.first.day, value: value));
  }
  return result;
});
