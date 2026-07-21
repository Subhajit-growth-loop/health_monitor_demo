import '../../../domain/entities/health_metric_type.dart';
import '../../../domain/entities/permission_state.dart';
import '../../models/health_record_model.dart';

/// The Unified Access Layer.
///
/// A single cross-platform interface the rest of the app talks to. In
/// production, one implementation wraps Apple HealthKit and another wraps
/// Android Health Connect (selected by [defaultTargetPlatform]); both return
/// the same normalized [HealthRecordModel]s. The app's business logic, storage
/// and UI never know which platform produced the data.
abstract interface class HealthPlatformDataSource {
  /// Human-readable name of the underlying provider ("Apple HealthKit" /
  /// "Health Connect" / the simulator).
  String get providerName;

  Future<HealthPermissionState> requestPermissions(
      List<HealthMetricType> types);

  Future<HealthPermissionState> currentPermissions();

  /// Read raw samples newer than [since] for the given granted types, already
  /// normalized to the common schema (unit conversion + timestamp
  /// normalization). De-duplication of overlapping sources happens here too.
  Future<List<HealthRecordModel>> fetchSamplesSince(
    DateTime since,
    List<HealthMetricType> grantedTypes,
  );

  /// Read raw samples newer than [since] for the given granted types and return
  /// them in the `health` package's own JSON shape (one
  /// `HealthDataPoint.toJson()` map per sample) — i.e. before any normalization
  /// or unit conversion. Backs the JSON export.
  Future<List<Map<String, dynamic>>> fetchRawJson(
    DateTime since,
    List<HealthMetricType> grantedTypes,
  );
}
