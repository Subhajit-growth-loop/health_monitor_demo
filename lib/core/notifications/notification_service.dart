import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/health/domain/entities/health_metric_type.dart';

/// Static notification service — safe to call from both the main isolate
/// (foreground) and WorkManager's background isolate.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'health_alerts';
  static const _channelName = 'Health Alerts';

  /// Initialize the plugin and notification channel.
  ///
  /// [requestPermissions] must only be true when running in the foreground
  /// (an Activity is attached). Requesting the Android POST_NOTIFICATIONS
  /// permission needs an Activity, so calling it from WorkManager's background
  /// isolate throws a NullPointerException (Context is null). Background callers
  /// rely on the permission already having been granted from the foreground.
  static Future<void> init({bool requestPermissions = false}) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: requestPermissions,
      requestBadgePermission: requestPermissions,
      requestSoundPermission: requestPermissions,
    );
    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              importance: Importance.high,
              enableVibration: true,
            ),
          );

      // Request POST_NOTIFICATIONS permission (Android 13+). Only possible
      // with an attached Activity, i.e. from the foreground.
      if (requestPermissions) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    }
  }

  static Future<void> showHealthAlert({
    required HealthMetricType type,
    required String title,
    required String body,
  }) async {
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      color: type.color,
      colorized: true,
      // Use metric color as notification accent.
      ledColor: type.color,
      ledOnMs: 500,
      ledOffMs: 1000,
      styleInformation: BigTextStyleInformation(body),
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      type.index, // deterministic ID per metric — prevents duplicate banners
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}