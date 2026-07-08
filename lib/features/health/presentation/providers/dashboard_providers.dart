import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/daily_point.dart';
import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/health_record.dart';
import 'health_providers.dart';

/// All read providers below re-run whenever [healthChangesProvider] fires,
/// keeping the UI bound to the local database as its single source of truth.

final todaySummaryProvider =
    FutureProvider<Map<HealthMetricType, double>>((ref) async {
  ref.watch(healthChangesProvider);
  return ref.watch(healthRepositoryProvider).todaySummary();
});

final dailySeriesProvider = FutureProvider.family<List<DailyPoint>,
    ({HealthMetricType type, int days})>((ref, arg) async {
  ref.watch(healthChangesProvider);
  return ref
      .watch(healthRepositoryProvider)
      .dailySeries(arg.type, days: arg.days);
});

final recordsForTypeProvider =
    FutureProvider.family<List<HealthRecord>, HealthMetricType>(
        (ref, type) async {
  ref.watch(healthChangesProvider);
  return ref.watch(healthRepositoryProvider).recordsForType(type);
});
