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

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
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

      // Request POST_NOTIFICATIONS permission (Android 13+).
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
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