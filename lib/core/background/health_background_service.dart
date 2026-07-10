import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/health/data/datasources/local/health_local_datasource.dart';
import '../database/app_database.dart';
import '../notifications/notification_service.dart';
import 'alert_thresholds.dart';

const _taskName = 'health_alert_check';

/// One hour in milliseconds — minimum gap between repeated alerts per metric.
const _cooldownMs = 3600000;

/// WorkManager callback — must be a top-level function.
@pragma('vm:entry-point')
void healthAlertDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _taskName) return Future.value(true);
    try {
      await _runHealthAlertCheck();
    } catch (e, st) {
      debugPrint('[HealthBackground] error: $e\n$st');
    }
    return Future.value(true);
  });
}

Future<void> _runHealthAlertCheck() async {
  await NotificationService.init();

  final db = await openAppDatabase();
  final local = HealthLocalDataSource(db);
  final summary = await local.todaySummary();

  final violations = AlertThresholds.check(summary);
  if (violations.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now().millisecondsSinceEpoch;

  for (final v in violations) {
    final key = 'last_alert_${v.type.id}';
    final last = prefs.getInt(key) ?? 0;
    if (now - last < _cooldownMs) continue; // respect cooldown

    await NotificationService.showHealthAlert(
      type: v.type,
      title: v.title,
      body: v.body,
    );
    await prefs.setInt(key, now);
  }
}

/// Register the periodic background task. Safe to call multiple times —
/// [ExistingWorkPolicy.keep] prevents duplicate scheduling.
///
/// Periodic tasks are only registered on Android. The workmanager 0.5.x iOS
/// plugin does not implement `registerPeriodicTask` (added in 0.6.0), so calling
/// it there throws `unhandledMethod`. On iOS the app instead relies on HealthKit
/// background delivery configured in AppDelegate.swift to wake the app.
Future<void> registerHealthAlertTask({bool debugMode = false}) async {
  if (!Platform.isAndroid) return;

  await Workmanager().initialize(
    healthAlertDispatcher,
    isInDebugMode: debugMode,
  );
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}