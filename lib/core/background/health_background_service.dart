import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/health/data/datasources/local/health_local_datasource.dart';
import '../../features/health/data/datasources/platform/health_platform_datasource.dart';
import '../../features/health/data/datasources/platform/real_health_platform_datasource.dart';
import '../../features/health/data/datasources/platform/simulated_health_platform_datasource.dart';
import '../../features/health/data/datasources/remote/http_health_remote_datasource.dart';
import '../../features/health/data/repositories/health_repository_impl.dart';
import '../../features/health/presentation/providers/health_providers.dart'
    show kForceSimulatedHealth;
import '../connectivity/connectivity_service.dart';
import '../database/app_database.dart';
import '../notifications/notification_service.dart';
import '../settings/app_settings.dart';
import 'alert_thresholds.dart';

/// Continuous silent sync (WorkManager 15-minute floor).
const _taskSync = 'health_sync';

/// Once-daily visible sync with a progress notification.
const _taskDaily = 'health_daily_digest';

/// One hour in milliseconds — minimum gap between repeated alerts per metric.
const _cooldownMs = 3600000;

/// WorkManager callback — must be a top-level function.
@pragma('vm:entry-point')
void healthBackgroundDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      switch (taskName) {
        case _taskSync:
          await _runBackgroundSync(showProgress: false);
        case _taskDaily:
          await _runBackgroundSync(showProgress: true);
      }
    } catch (e, st) {
      debugPrint('[HealthBackground] error: $e\n$st');
    }
    return Future.value(true);
  });
}

/// Build the repository stack manually — the background isolate has no Riverpod.
Future<HealthRepositoryImpl> _buildRepository() async {
  final db = await openAppDatabase();
  final local = HealthLocalDataSource(db);

  final canUseReal =
      !kIsWeb && !kForceSimulatedHealth && (Platform.isIOS || Platform.isAndroid);
  final HealthPlatformDataSource platform = canUseReal
      ? RealHealthPlatformDataSource()
      : SimulatedHealthPlatformDataSource();

  return HealthRepositoryImpl(
    platform: platform,
    local: local,
    remote: HttpHealthRemoteDataSource(),
    connectivity: ConnectivityService(),
  );
}

/// The core background job: acquire from the platform, persist locally, upload
/// to the backend, run alert checks, and prompt catch-up after long silence.
Future<void> _runBackgroundSync({required bool showProgress}) async {
  await NotificationService.init(); // no permission request in the background

  // Detect long silence BEFORE attempting this run's sync.
  final last = await readLastSuccessfulSync();
  final wasSilent =
      last == null || DateTime.now().difference(last) >= kCatchUpThreshold;

  if (showProgress) await NotificationService.showSyncProgress();

  final repo = await _buildRepository();
  var syncedCount = 0;
  var ok = false;
  try {
    await repo.refreshFromPlatform();
    syncedCount = await repo.synchronize();
    await markSyncSuccess();
    ok = true;
  } catch (e, st) {
    debugPrint('[HealthBackground] sync error: $e\n$st');
  }

  // Threshold alerts run regardless of upload success (based on local data).
  try {
    await _runAlertCheck(repo);
  } catch (e, st) {
    debugPrint('[HealthBackground] alert error: $e\n$st');
  }

  if (showProgress) {
    await NotificationService.completeSyncProgress(count: syncedCount, success: ok);
  }

  // If we were already past the 48h threshold and still couldn't sync, prompt
  // the user to catch up. If this run succeeded, clear any stale prompt.
  if (ok) {
    await NotificationService.cancelCatchUp();
  } else if (wasSilent) {
    await NotificationService.showCatchUpNeeded();
  }
}

Future<void> _runAlertCheck(HealthRepositoryImpl repo) async {
  final summary = await repo.todaySummary();
  final violations = AlertThresholds.check(summary);
  if (violations.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now().millisecondsSinceEpoch;

  for (final v in violations) {
    final key = 'last_alert_${v.type.id}';
    final lastAt = prefs.getInt(key) ?? 0;
    if (now - lastAt < _cooldownMs) continue; // respect cooldown

    await NotificationService.showHealthAlert(
      type: v.type,
      title: v.title,
      body: v.body,
    );
    await prefs.setInt(key, now);
  }
}

/// Register the periodic background tasks. Safe to call multiple times —
/// [ExistingWorkPolicy.keep] prevents duplicate scheduling.
///
/// Android only. The workmanager iOS path relies on HealthKit background
/// delivery configured in AppDelegate.swift instead (spec §3: iOS handles
/// background wake-ups natively; Android is the unreliable platform this
/// resilience layer exists for).
Future<void> registerBackgroundTasks({bool debugMode = false}) async {
  if (!Platform.isAndroid) return;

  await Workmanager().initialize(
    healthBackgroundDispatcher,
    isInDebugMode: debugMode,
  );

  // Continuous sync — needs network to upload.
  await Workmanager().registerPeriodicTask(
    _taskSync,
    _taskSync,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  // Once-daily visible digest — fetches even when offline; upload just waits.
  await Workmanager().registerPeriodicTask(
    _taskDaily,
    _taskDaily,
    frequency: const Duration(hours: 24),
    initialDelay: const Duration(hours: 2),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}