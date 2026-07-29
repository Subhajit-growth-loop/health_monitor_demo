import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/daily_point.dart';
import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/health_record.dart';
import 'health_providers.dart';

/// All read providers below re-run whenever [healthChangesProvider] fires,
/// keeping the UI bound to the local database as its single source of truth.

/// The date shown on the dashboard. Defaults to today (midnight).
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Summary for the currently selected dashboard date.
final todaySummaryProvider =
    FutureProvider<Map<HealthMetricType, double>>((ref) async {
  ref.watch(healthChangesProvider);
  final date = ref.watch(selectedDateProvider);
  return ref.watch(healthRepositoryProvider).summaryForDate(date);
});

final dailySeriesProvider = FutureProvider.family<List<DailyPoint>,
    ({HealthMetricType type, int days})>((ref, arg) async {
  ref.watch(healthChangesProvider);
  return ref
      .watch(healthRepositoryProvider)
      .dailySeries(arg.type, days: arg.days);
});

final monthlySeriesProvider = FutureProvider.family<List<DailyPoint>,
    ({HealthMetricType type, int months})>((ref, arg) async {
  ref.watch(healthChangesProvider);
  return ref
      .watch(healthRepositoryProvider)
      .monthlySeries(arg.type, months: arg.months);
});

final recordsForTypeProvider =
    FutureProvider.family<List<HealthRecord>, HealthMetricType>(
        (ref, type) async {
  ref.watch(healthChangesProvider);
  return ref.watch(healthRepositoryProvider).recordsForType(type);
});

/// Weekly aggregates: groups [weeks] × 7 daily points into one value per week.
/// The representative date for each week is the first day of that 7-day bucket.
final weeklySeriesProvider = FutureProvider.family<List<DailyPoint>,
    ({HealthMetricType type, int weeks})>((ref, arg) async {
  ref.watch(healthChangesProvider);
  final daily = await ref
      .watch(healthRepositoryProvider)
      .dailySeries(arg.type, days: arg.weeks * 7);

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
