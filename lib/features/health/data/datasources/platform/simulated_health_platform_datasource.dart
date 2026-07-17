import 'dart:math';

import '../../../domain/entities/health_metric_type.dart';
import '../../../domain/entities/health_record.dart';
import '../../../domain/entities/permission_state.dart';
import '../../../domain/entities/sync_status.dart';
import '../../models/health_record_model.dart';
import 'health_platform_datasource.dart';

/// A stand-in for HealthKit / Health Connect used on simulators, desktop and
/// tests (neither platform exposes data on a simulator). It generates
/// realistic samples across multiple sources so the whole pipeline —
/// normalization, de-duplication, persistence, charts and sync — can be
/// exercised end-to-end. Swapping in a real platform implementation requires
/// no changes above this layer.
class SimulatedHealthPlatformDataSource implements HealthPlatformDataSource {
  SimulatedHealthPlatformDataSource({int seed = 7}) : _rng = Random(seed);

  final Random _rng;

  @override
  String get providerName => 'Simulated Health Platform';

  var _permissions = HealthPermissionState.allNotRequested();

  @override
  Future<HealthPermissionState> currentPermissions() async => _permissions;

  @override
  Future<HealthPermissionState> requestPermissions(
      List<HealthMetricType> types) async {
    // Simulate the system consent dialog resolving after a short delay.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _permissions = HealthPermissionState(grants: {
      for (final t in HealthMetricType.values)
        t: types.contains(t)
            ? PermissionGrant.granted
            : (_permissions.grants[t] ?? PermissionGrant.notRequested),
    });
    return _permissions;
  }

  @override
  Future<List<HealthRecordModel>> fetchSamplesSince(
    DateTime since,
    List<HealthMetricType> grantedTypes,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    // Never generate before "since"; cap a first backfill at 7 days so the
    // simulator behaves like a paginated, recent-first initial import.
    final earliest = now.subtract(const Duration(days: 7));
    var cursor = since.isBefore(earliest) ? earliest : since;

    final raw = <HealthRecordModel>[];
    for (final type in grantedTypes) {
      raw.addAll(_generate(type, cursor, now));
    }
    return _deduplicate(raw);
  }

  List<HealthRecordModel> _generate(
      HealthMetricType type, DateTime from, DateTime to) {
    switch (type) {
      case HealthMetricType.steps:
        return _hourly(type, from, to, () => 80 + _rng.nextInt(650),
            sources: const ['iPhone', 'Apple Watch']);
      case HealthMetricType.activeEnergy:
        return _hourly(type, from, to, () => 8 + _rng.nextInt(75),
            sources: const ['Apple Watch']);
      case HealthMetricType.heartRate:
        return _everyMinutes(type, from, to, 45,
            () => 58 + _rng.nextInt(52), sources: const ['Apple Watch']);
      case HealthMetricType.bloodOxygen:
        return _everyMinutes(type, from, to, 180,
            () => 95 + _rng.nextInt(5), sources: const ['Apple Watch']);
      case HealthMetricType.sleep:
        return _nightly(type, from, to);
      case HealthMetricType.weight:
        return _daily(type, from, to,
            () => 70.0 + _rng.nextDouble() * 15.0, source: 'Health Connect');
      case HealthMetricType.bloodGlucose:
        return _everyMinutes(type, from, to, 120,
            () => 80 + _rng.nextInt(60), sources: const ['Health Connect']);
    }
  }

  List<HealthRecordModel> _hourly(
    HealthMetricType type,
    DateTime from,
    DateTime to,
    num Function() value, {
    required List<String> sources,
  }) {
    final out = <HealthRecordModel>[];
    var t = DateTime(from.year, from.month, from.day, from.hour);
    while (t.isBefore(to)) {
      // Only waking hours produce meaningful activity.
      if (t.hour >= 7 && t.hour <= 22) {
        // Occasionally both phone and watch record the same hour — an
        // overlapping-source duplicate the normalization layer must resolve.
        final source = sources[_rng.nextInt(sources.length)];
        out.add(_record(type, t, value().toDouble(), source));
        if (sources.length > 1 && _rng.nextDouble() < 0.25) {
          out.add(_record(type, t, value().toDouble(), sources.last));
        }
      }
      t = t.add(const Duration(hours: 1));
    }
    return out;
  }

  List<HealthRecordModel> _everyMinutes(
    HealthMetricType type,
    DateTime from,
    DateTime to,
    int minutes,
    num Function() value, {
    required List<String> sources,
  }) {
    final out = <HealthRecordModel>[];
    var t = from;
    while (t.isBefore(to)) {
      out.add(_record(
          type, t, value().toDouble(), sources[_rng.nextInt(sources.length)]));
      t = t.add(Duration(minutes: minutes));
    }
    return out;
  }

  List<HealthRecordModel> _daily(
    HealthMetricType type,
    DateTime from,
    DateTime to,
    num Function() value, {
    required String source,
  }) {
    final out = <HealthRecordModel>[];
    var t = DateTime(from.year, from.month, from.day, 8);
    while (t.isBefore(to)) {
      if (t.isAfter(from)) {
        out.add(_record(type, t, double.parse(value().toStringAsFixed(1)), source));
      }
      t = t.add(const Duration(days: 1));
    }
    return out;
  }

  List<HealthRecordModel> _nightly(
      HealthMetricType type, DateTime from, DateTime to) {
    final out = <HealthRecordModel>[];
    var day = DateTime(from.year, from.month, from.day);
    while (day.isBefore(to)) {
      // One sleep session per night, logged at ~7am wake time.
      final wake = day.add(const Duration(hours: 7));
      if (wake.isAfter(from) && wake.isBefore(to)) {
        final hours = 5.5 + _rng.nextDouble() * 3.0;
        out.add(_record(type, wake, double.parse(hours.toStringAsFixed(1)),
            'Apple Watch'));
      }
      day = day.add(const Duration(days: 1));
    }
    return out;
  }

  HealthRecordModel _record(
      HealthMetricType type, DateTime ts, double value, String source) {
    return HealthRecordModel(
      id: HealthRecord.buildId(type: type, timestamp: ts, source: source),
      type: type,
      value: value,
      unit: type.unit,
      source: source,
      timestamp: ts,
      syncStatus: SyncStatus.pending,
    );
  }

  /// De-duplicate overlapping samples: when the same metric is reported for the
  /// same timestamp window by more than one source, keep a single reading
  /// (here, the first — a real impl would prefer a trusted source such as a
  /// dedicated wearable). Matching is by type + timestamp window + source.
  List<HealthRecordModel> _deduplicate(List<HealthRecordModel> records) {
    final seen = <String>{};
    final out = <HealthRecordModel>[];
    for (final r in records) {
      // 10-minute window key, source-agnostic, per type.
      final windowKey =
          '${r.type.id}_${r.timestamp.millisecondsSinceEpoch ~/ (10 * 60 * 1000)}';
      if (seen.add(windowKey)) out.add(r);
    }
    return out;
  }
}
