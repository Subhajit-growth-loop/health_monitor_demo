import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/background/health_background_service.dart';
import 'core/database/app_database.dart';
import 'core/notifications/notification_service.dart';
import 'features/health/presentation/providers/health_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the local database up front so it can be provided synchronously to
  // the rest of the app as the single source of truth.
  final db = await openAppDatabase();

  // Initialize local notification channel and permissions.
  await NotificationService.init();

  // Register the periodic background health-alert task (WorkManager on Android,
  // background fetch on iOS). ExistingWorkPolicy.keep means this is a no-op on
  // subsequent launches when the task is already scheduled.
  await registerHealthAlertTask(debugMode: kDebugMode);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const HealthMonitorApp(),
    ),
  );
}
