import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'features/health/presentation/providers/health_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the local database up front so it can be provided synchronously to
  // the rest of the app as the single source of truth.
  final db = await openAppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const HealthMonitorApp(),
    ),
  );
}
