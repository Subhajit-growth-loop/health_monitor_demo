import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/health_record.dart';
import '../../domain/entities/sync_status.dart';

/// Data-layer mapping of [HealthRecord] to/from the local SQLite row and the
/// backend JSON payload.
class HealthRecordModel extends HealthRecord {
  const HealthRecordModel({
    required super.id,
    required super.type,
    required super.value,
    required super.unit,
    required super.source,
    required super.timestamp,
    required super.syncStatus,
  });

  factory HealthRecordModel.fromEntity(HealthRecord r) => HealthRecordModel(
        id: r.id,
        type: r.type,
        value: r.value,
        unit: r.unit,
        source: r.source,
        timestamp: r.timestamp,
        syncStatus: r.syncStatus,
      );

  factory HealthRecordModel.fromDb(Map<String, Object?> row) =>
      HealthRecordModel(
        id: row['id'] as String,
        type: HealthMetricType.fromId(row['type'] as String),
        value: (row['value'] as num).toDouble(),
        unit: row['unit'] as String,
        source: row['source'] as String,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        syncStatus: SyncStatus.fromValue(row['sync_status'] as String),
      );

  Map<String, Object?> toDb() => {
        'id': id,
        'type': type.id,
        'value': value,
        'unit': unit,
        'source': source,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'sync_status': syncStatus.value,
      };

  /// Payload sent to / received from the backend. The backend stores by [id],
  /// which makes ingestion idempotent.
  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.id,
        'value': value,
        'unit': unit,
        'source': source,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory HealthRecordModel.fromJson(Map<String, Object?> json) =>
      HealthRecordModel(
        id: json['id'] as String,
        type: HealthMetricType.fromId(json['type'] as String),
        value: (json['value'] as num).toDouble(),
        unit: json['unit'] as String,
        source: json['source'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
        // Anything coming from the backend is, by definition, already synced.
        syncStatus: SyncStatus.synced,
      );
}
