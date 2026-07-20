import '../../../../core/connectivity/connectivity_service.dart';
import '../../domain/entities/daily_point.dart';
import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/health_record.dart';
import '../../domain/entities/permission_state.dart';
import '../../domain/repositories/health_repository.dart';
import '../datasources/local/health_local_datasource.dart';
import '../datasources/platform/health_platform_datasource.dart';
import '../datasources/remote/health_remote_datasource.dart';

/// Orchestrates the five architecture layers behind the [HealthRepository]
/// contract: acquisition (platform) → normalization/persistence (local) →
/// synchronization (remote). The local DB is always the read path.
class HealthRepositoryImpl implements HealthRepository {
  HealthRepositoryImpl({
    required HealthPlatformDataSource platform,
    required HealthLocalDataSource local,
    required HealthRemoteDataSource remote,
    required ConnectivityService connectivity,
  })  : _platform = platform,
        _local = local,
        _remote = remote,
        _connectivity = connectivity;

  final HealthPlatformDataSource _platform;
  final HealthLocalDataSource _local;
  final HealthRemoteDataSource _remote;
  final ConnectivityService _connectivity;

  // Cursors for incremental acquisition/sync. In-memory here; a real build
  // would persist these so restarts don't re-scan.
  // 90-day initial window captures infrequent measurements (BP, weight, glucose)
  // that may not have a reading in the last 7 days.
  DateTime _lastPlatformRead =
      DateTime.now().subtract(const Duration(days: 90));
  DateTime _lastRemotePull =
      DateTime.now().subtract(const Duration(days: 30));

  @override
  Future<HealthPermissionState> requestPermissions(
          List<HealthMetricType> types) =>
      _platform.requestPermissions(types);

  @override
  Future<HealthPermissionState> currentPermissions() =>
      _platform.currentPermissions();

  @override
  Future<int> refreshFromPlatform({Duration? lookback}) async {
    final perms = await _platform.currentPermissions();
    final granted = HealthMetricType.collectible
        .where(perms.isGranted)
        .toList(growable: false);
    if (granted.isEmpty) return 0;

    // Catch-up re-reads the trailing window; a normal refresh resumes from the
    // incremental cursor. Stable ids make re-reading idempotent either way.
    final since = lookback != null
        ? DateTime.now().subtract(lookback)
        : _lastPlatformRead;

    final samples = await _platform.fetchSamplesSince(since, granted);
    final inserted = await _local.upsertPending(samples);
    _lastPlatformRead = DateTime.now();
    return inserted;
  }

  @override
  Future<List<HealthRecord>> recordsForType(HealthMetricType type,
          {int limit = 200}) =>
      _local.recordsForType(type, limit: limit);

  @override
  Future<List<DailyPoint>> dailySeries(HealthMetricType type,
          {int days = 7}) =>
      _local.dailySeries(type, days: days);

  @override
  Future<Map<HealthMetricType, double>> todaySummary() =>
      _local.todaySummary();

  @override
  Future<Map<HealthMetricType, double>> summaryForDate(DateTime date) =>
      _local.summaryForDate(date);

  @override
  Future<List<DailyPoint>> monthlySeries(HealthMetricType type,
          {int months = 12}) =>
      _local.monthlySeries(type, months: months);

  @override
  Future<int> pendingCount() => _local.pendingCount();

  @override
  Future<int> synchronize() async {
    if (!_connectivity.isOnline) return 0;

    // 1. Download remote updates first, then merge (server-computed values,
    //    other-device data). Never blocks the UI — this is background work.
    final remote = await _remote.fetchUpdatesSince(_lastRemotePull);
    await _local.mergeFromRemote(remote);
    _lastRemotePull = DateTime.now();

    // 2. Upload pending records in bounded batches with backoff between them,
    //    so a large backlog after a long offline period doesn't cause a sync
    //    storm. Nothing is marked synced until the backend confirms.
    const batchSize = 50;
    var syncedTotal = 0;
    while (true) {
      final pending = await _local.pending(limit: batchSize);
      if (pending.isEmpty) break;

      try {
        final acceptedIds = await _remote.uploadBatch(pending);
        await _local.markSynced(acceptedIds);
        syncedTotal += acceptedIds.length;
      } catch (_) {
        // Leave the batch pending; caller/scheduler retries with backoff.
        rethrow;
      }

      if (pending.length < batchSize) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return syncedTotal;
  }

  @override
  Stream<void> watchChanges() => _local.changes;
}
