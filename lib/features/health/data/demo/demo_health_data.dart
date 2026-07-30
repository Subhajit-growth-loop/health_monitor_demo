import '../../domain/entities/daily_point.dart';
import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/health_record.dart';
import '../../domain/entities/sync_status.dart';

/// Placeholder health data for metrics the device has nothing real for.
///
/// **Display-only.** Nothing here is ever written to SQLite, so demo readings
/// cannot be uploaded by the sync layer or end up in a JSON export — those both
/// read the database, which only ever holds genuine samples. The substitution
/// happens in the dashboard providers, at the point of rendering.
///
/// Values are deterministic: the same type and day always produce the same
/// number, so charts don't reshuffle between rebuilds. Set [enabled] to `false`
/// to go back to real empty states everywhere.
abstract final class DemoHealthData {
  static const bool enabled = true;

  /// How many trailing days carry sample readings.
  static const int days = 6;

  /// Readings generated per day (2 or 3, varying by day so it doesn't look
  /// mechanical).
  static int _readingsForDay(int dayOffset) => 2 + (dayOffset % 2);

  static const String source = 'Sample data';

  /// Deterministic pseudo-random in [0,1) from two ints — a small integer hash,
  /// so no global RNG state and identical output across rebuilds and isolates.
  static double _noise(int a, int b) {
    var h = 0x811c9dc5 ^ (a * 0x01000193);
    h = (h ^ (b + 0x9e3779b9)) * 0x85ebca6b;
    h ^= h >> 13;
    h = (h * 0xc2b2ae35) & 0x7fffffff;
    return (h % 10000) / 10000.0;
  }

  /// Plausible centre and spread per metric, in the type's own unit.
  static (double centre, double spread) _range(HealthMetricType type) =>
      switch (type) {
        HealthMetricType.bloodGlucose => (104, 22),
        HealthMetricType.heartRate => (72, 14),
        HealthMetricType.restingHeartRate => (61, 6),
        HealthMetricType.heartRateVariability => (42, 12),
        HealthMetricType.bloodPressureSystolic => (118, 10),
        HealthMetricType.bloodPressureDiastolic => (76, 7),
        HealthMetricType.bloodOxygen => (97, 2),
        HealthMetricType.respiratoryRate => (15, 3),
        HealthMetricType.bodyTemperature => (36.7, 0.4),
        // Per-reading, so the daily sum lands around 6–8k steps.
        HealthMetricType.steps => (2600, 900),
        HealthMetricType.activeEnergy => (150, 70),
        HealthMetricType.basalEnergy => (620, 90),
        HealthMetricType.totalCalories => (780, 140),
        HealthMetricType.flightsClimbed => (3, 2),
        HealthMetricType.weight => (68.5, 1.2),
        HealthMetricType.height => (166, 0),
        HealthMetricType.bodyFat => (31, 2),
        HealthMetricType.leanBodyMass => (45, 1.5),
        // Sleep is summed per day, so keep each block a partial night.
        HealthMetricType.sleep => (2.5, 0.7),
        HealthMetricType.sleepDeep => (0.7, 0.3),
        HealthMetricType.sleepLight => (1.6, 0.5),
        HealthMetricType.sleepRem => (0.8, 0.3),
        HealthMetricType.sleepAwake => (0.2, 0.1),
        HealthMetricType.menstruationFlow => (2, 1),
      };

  static double _valueFor(HealthMetricType type, int dayOffset, int reading) {
    final (centre, spread) = _range(type);
    if (spread == 0) return centre;
    // Centred in [-1, 1], plus a gentle day-over-day drift so trends read as
    // trends rather than noise. Drift is scaled by [spread] — an absolute drift
    // swamped narrow-range metrics like deep sleep and pushed them to zero.
    final jitter = (_noise(type.index, dayOffset * 10 + reading) - 0.5) * 2;
    final drift =
        (_noise(type.index, 999) - 0.5) * 0.15 * spread * (days - dayOffset);
    final raw = centre + jitter * spread + drift;
    // Floor well above zero: a sample reading of 0 renders as "no data".
    final floor = centre * 0.4;
    final value = raw < floor ? floor : raw;
    // Whole numbers where a fraction would look wrong (steps, bpm, floors).
    return type.decimals == 0 ? value.roundToDouble() : value;
  }

  /// [days] × 2-3 readings, newest first, spread across each day's waking hours.
  /// Timestamps are derived from [now] so the series always ends today.
  static List<HealthRecord> records(HealthMetricType type, {DateTime? now}) {
    if (!enabled) return const [];
    final today = now ?? DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);

    final out = <HealthRecord>[];
    for (var d = 0; d < days; d++) {
      final day = midnight.subtract(Duration(days: d));
      final count = _readingsForDay(d);
      for (var r = 0; r < count; r++) {
        // Spread readings between 08:00 and 21:00.
        final hour = 8 + ((13 / count) * r).round();
        final ts = DateTime(day.year, day.month, day.day, hour, (r * 17) % 60);
        if (ts.isAfter(today)) continue;
        out.add(
          HealthRecord(
            id: HealthRecord.buildId(type: type, timestamp: ts, source: source),
            type: type,
            value: _valueFor(type, d, r),
            unit: type.unit,
            source: source,
            timestamp: ts,
            syncStatus: SyncStatus.synced,
          ),
        );
      }
    }
    out.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return out;
  }

  /// Daily aggregate series matching the shape the real providers return:
  /// oldest→newest is *not* assumed — this mirrors the repository, which returns
  /// newest first, and pads to [length] with zero-valued older days.
  static List<DailyPoint> dailySeries(
    HealthMetricType type, {
    required int length,
    DateTime? now,
  }) {
    if (!enabled) return const [];
    final today = now ?? DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);

    return List<DailyPoint>.generate(length, (d) {
      final day = midnight.subtract(Duration(days: d));
      return DailyPoint(day: day, value: d < days ? _aggregateDay(type, d) : 0);
    });
  }

  /// Today's value in the same units the dashboard summary uses.
  static double summaryValue(HealthMetricType type) =>
      enabled ? _aggregateDay(type, 0) : 0;

  static double _aggregateDay(HealthMetricType type, int dayOffset) {
    final count = _readingsForDay(dayOffset);
    final values = List<double>.generate(
      count,
      (r) => _valueFor(type, dayOffset, r),
    );
    return switch (type.aggregation) {
      Aggregation.sum => values.reduce((a, b) => a + b),
      Aggregation.average => values.reduce((a, b) => a + b) / values.length,
      Aggregation.latest => values.last,
    };
  }

  /// True when [series] holds nothing worth charting.
  static bool isSeriesEmpty(List<DailyPoint> series) =>
      series.isEmpty || series.every((p) => p.value <= 0);
}