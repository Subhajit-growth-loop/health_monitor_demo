// End-to-end test of the data pipeline: acquisition (simulated platform) →
// normalization/persistence (local SQLite) → synchronization (mock backend).
// Runs on the FFI SQLite backend so no device is required.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:health_monitor_demo/features/dashboard/data/datasources/local/health_local_datasource.dart';
import 'package:health_monitor_demo/features/dashboard/data/datasources/platform/simulated_health_platform_datasource.dart';
import 'package:health_monitor_demo/features/dashboard/data/datasources/remote/health_remote_datasource.dart';
import 'package:health_monitor_demo/features/dashboard/domain/entities/health_metric_type.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<HealthLocalDataSource> newLocal() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => HealthLocalDataSource.createSchema(db),
      ),
    );
    return HealthLocalDataSource(db);
  }

  test('acquires, persists as pending, then syncs to backend', () async {
    final local = await newLocal();
    final platform = SimulatedHealthPlatformDataSource();
    final remote = InMemoryHealthRemoteDataSource();

    // Grant permission and acquire samples for the last week.
    await platform.requestPermissions(HealthMetricType.values);
    final samples = await platform.fetchSamplesSince(
      DateTime.now().subtract(const Duration(days: 7)),
      HealthMetricType.values,
    );
    expect(samples, isNotEmpty);

    // Persist — everything starts pending.
    final inserted = await local.upsertPending(samples);
    expect(inserted, greaterThan(0));
    expect(await local.pendingCount(), inserted);

    // Re-inserting the same samples is idempotent (stable ids).
    final reinserted = await local.upsertPending(samples);
    expect(reinserted, 0);

    // Upload all pending in bounded batches and mark synced — mirrors the
    // production synchronize() loop so a large backlog is fully drained. The
    // mock backend injects a transient failure, so retry each batch like the
    // SyncController does.
    while (true) {
      final pending = await local.pending(limit: 50);
      if (pending.isEmpty) break;
      List<String>? acceptedIds;
      for (var attempt = 0; attempt < 5 && acceptedIds == null; attempt++) {
        try {
          acceptedIds = await remote.uploadBatch(pending);
        } catch (_) {
          // transient — retry
        }
      }
      await local.markSynced(acceptedIds!);
    }
    expect(await local.pendingCount(), 0);
  });

  test('daily series and today summary aggregate correctly', () async {
    final local = await newLocal();
    final platform = SimulatedHealthPlatformDataSource();
    await platform.requestPermissions([HealthMetricType.steps]);
    final samples = await platform.fetchSamplesSince(
      DateTime.now().subtract(const Duration(days: 7)),
      [HealthMetricType.steps],
    );
    await local.upsertPending(samples);

    final series = await local.dailySeries(HealthMetricType.steps, days: 7);
    expect(series.length, 7);

    final summary = await local.todaySummary();
    expect(summary.containsKey(HealthMetricType.steps), isTrue);
  });

  test('collectible metric types flow through the pipeline and aggregate',
      () async {
    final local = await newLocal();
    final platform = SimulatedHealthPlatformDataSource();

    // The app only ever requests / sweeps the collectible tiers.
    final requested = HealthMetricType.collectible;
    await platform.requestPermissions(requested);
    final samples = await platform.fetchSamplesSince(
      DateTime.now().subtract(const Duration(days: 7)),
      requested,
    );
    await local.upsertPending(samples);

    // Every requested type should have produced at least one sample.
    final typesWithData = samples.map((s) => s.type).toSet();
    for (final type in requested) {
      expect(typesWithData.contains(type), isTrue,
          reason: 'no samples generated for ${type.id}');
    }

    // Sanity-check normalized value ranges for a few converted metrics.
    double latest(HealthMetricType t) =>
        samples.where((s) => s.type == t).last.value;
    expect(latest(HealthMetricType.height), inInclusiveRange(120, 250)); // cm
    expect(latest(HealthMetricType.sleep), inInclusiveRange(0, 24)); // hours
    expect(latest(HealthMetricType.bloodOxygen), inInclusiveRange(80, 100)); // %

    // The summary must include every type after aggregation.
    final summary = await local.todaySummary();
    for (final type in HealthMetricType.values) {
      expect(summary.containsKey(type), isTrue);
    }

    // Triage sanity: HRV is collected; water/bmi are gone; the not-requested
    // energy/activity extras are excluded from the request.
    expect(requested.contains(HealthMetricType.heartRateVariability), isTrue);
    expect(requested.contains(HealthMetricType.basalEnergy), isFalse);
    expect(requested.contains(HealthMetricType.totalCalories), isFalse);
    expect(requested.contains(HealthMetricType.flightsClimbed), isFalse);
    expect(HealthMetricType.maybeFromId('water'), isNull);
    expect(HealthMetricType.maybeFromId('bmi'), isNull);
  });
}
