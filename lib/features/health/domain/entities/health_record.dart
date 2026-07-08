import 'health_metric_type.dart';
import 'sync_status.dart';

/// A single normalized health sample — the common internal record that the
/// entire app (storage, sync, UI) operates on, regardless of whether it
/// originated from HealthKit or Health Connect.
class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.source,
    required this.timestamp,
    required this.syncStatus,
  });

  /// Stable identifier derived from type + timestamp + source. This makes
  /// uploads idempotent: re-sending the same sample never creates a duplicate
  /// on the backend, and the same reading arriving from two sources collapses
  /// to one record.
  final String id;
  final HealthMetricType type;
  final double value;
  final String unit;

  /// The device or app that produced the sample (e.g. "Apple Watch",
  /// "iPhone", "Pixel Watch"). Retained so provenance is never lost.
  final String source;
  final DateTime timestamp;
  final SyncStatus syncStatus;

  /// Deterministic id used for de-duplication and idempotent writes.
  static String buildId({
    required HealthMetricType type,
    required DateTime timestamp,
    required String source,
  }) =>
      '${type.id}_${timestamp.millisecondsSinceEpoch}_$source';

  HealthRecord copyWith({SyncStatus? syncStatus}) => HealthRecord(
        id: id,
        type: type,
        value: value,
        unit: unit,
        source: source,
        timestamp: timestamp,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}
