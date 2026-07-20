import '../entities/daily_point.dart';
import '../entities/health_metric_type.dart';
import '../entities/health_record.dart';
import '../entities/permission_state.dart';

/// Contract the presentation layer depends on. The implementation orchestrates
/// the acquisition (HealthKit / Health Connect), normalization, local
/// persistence and synchronization layers, but callers never see any of that.
abstract interface class HealthRepository {
  /// Request platform read permission for the given metric types.
  Future<HealthPermissionState> requestPermissions(
      List<HealthMetricType> types);

  /// Current permission state without prompting.
  Future<HealthPermissionState> currentPermissions();

  /// Pull new samples from the native platform, normalize + de-duplicate them,
  /// and persist them locally tagged as pending-sync. Returns how many new
  /// records were written.
  ///
  /// [lookback] forces a re-read of the trailing window (e.g. 48h) instead of
  /// resuming from the incremental cursor — used by the catch-up flow.
  Future<int> refreshFromPlatform({Duration? lookback});

  /// The most recent records of a type, newest first (reads local DB only).
  Future<List<HealthRecord>> recordsForType(
    HealthMetricType type, {
    int limit = 200,
  });

  /// Per-day aggregates for a type over the last [days] days.
  Future<List<DailyPoint>> dailySeries(
    HealthMetricType type, {
    int days = 7,
  });

  /// Today's aggregated value for each metric type (sum/avg/latest as defined
  /// by the metric).
  Future<Map<HealthMetricType, double>> todaySummary();

  /// Aggregated value for each metric type on a specific date.
  Future<Map<HealthMetricType, double>> summaryForDate(DateTime date);

  /// Per-month aggregates for a type over the last [months] months.
  Future<List<DailyPoint>> monthlySeries(
    HealthMetricType type, {
    int months = 12,
  });

  /// How many local records are still awaiting backend confirmation.
  Future<int> pendingCount();

  /// Push all pending records to the backend and pull remote updates down.
  /// Returns the number of records successfully synced (uploaded).
  Future<int> synchronize();

  /// A stream that fires whenever the local database changes, so the UI can
  /// re-read its single source of truth.
  Stream<void> watchChanges();
}
