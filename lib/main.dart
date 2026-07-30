import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/background/health_background_service.dart';
import 'core/database/app_database.dart';
import 'core/notifications/notification_service.dart';
import 'core/session/app_error_handler.dart';
import 'core/session/current_user.dart';
import 'core/session/token_manager.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/theme_provider.dart';
import 'features/health/presentation/providers/health_providers.dart';
import 'features/health/presentation/screens/sync_settings_screen.dart';
import 'features/neu/presentation/screens/neu_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the local database and settings store up front so they can be provided
  // synchronously to the rest of the app as the single source of truth.
  final db = await openAppDatabase();
  final prefs = await SharedPreferences.getInstance();

  // Initialise singletons that need SharedPreferences
  TokenManager.instance.init(prefs);
  CurrentUser.instance.init(prefs);

  // One-time: clear a `dark` saved from when dark was the default, so this build
  // opens light. The Dark mode switch is respected normally from here on.
  await ThemeModeNotifier.resetToLightOnce(prefs);

  // When any API call returns 401, clear the session and push to login.
  AppErrorHandler.instance.onSessionExpired = () async {
    await TokenManager.instance.clearToken();
    await CurrentUser.instance.clear();
    HealthMonitorApp.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NeuLoginScreen()),
      (_) => false,
    );
  };

  // Initialize local notification channels and permissions. Route taps (e.g.
  // the 48h catch-up prompt) to the manual sync page.
  await NotificationService.init(requestPermissions: true);
  NotificationService.onSelectNotification = _routeNotification;

  // Register the periodic background sync + daily-digest tasks (Android).
  await registerBackgroundTasks(debugMode: kDebugMode);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const HealthMonitorApp(),
    ),
  );
}

/// Navigate to the manual sync page (and auto-run the look-back) when the user
/// taps a catch-up notification while the app is already running.
void _routeNotification(String payload) {
  if (payload == NotificationService.catchUpPayload) {
    HealthMonitorApp.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => const SyncSettingsScreen(autoLookBack: true),
      ),
    );
  }
}
