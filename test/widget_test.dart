// End-to-end test of the data pipeline: acquisition (simulated platform) →
// normalization/persistence (local SQLite) → synchronization (mock backend).
// Runs on the FFI SQLite backend so no device is required.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:health_monitor_demo/features/health/data/datasources/local/health_local_datasource.dart';
import 'package:health_monitor_demo/features/health/data/datasources/platform/simulated_health_platform_datasource.dart';
import 'package:health_monitor_demo/features/health/data/datasources/remote/health_remote_datasource.dart';
import 'package:health_monitor_demo/features/health/domain/entities/health_metric_type.dart';

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

    // Upload pending in one batch and mark synced.
    final pending = await local.pending(limit: 1000);
    final acceptedIds = await remote.uploadBatch(pending);
    await local.markSynced(acceptedIds);
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
}
