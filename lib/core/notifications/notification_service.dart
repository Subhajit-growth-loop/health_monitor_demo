import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/dashboard/domain/entities/health_metric_type.dart';

/// Static notification service — safe to call from both the main isolate
/// (foreground) and WorkManager's background isolate.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  // Alerts (threshold breaches).
  static const _channelId = 'health_alerts';
  static const _channelName = 'Health Alerts';

  // Sync progress — low importance, WhatsApp-style ongoing bar.
  static const _syncChannelId = 'health_sync';
  static const _syncChannelName = 'Sync Progress';
  static const _syncNotifId = 1001;

  // Catch-up prompt — high importance, actionable.
  static const _catchupChannelId = 'health_catchup';
  static const _catchupChannelName = 'Sync Reminders';
  static const _catchupNotifId = 1002;

  /// Payload set on the catch-up notification; routes to the manual sync page.
  static const catchUpPayload = 'catchup';
  static const catchUpActionId = 'sync_now';

  /// Invoked when a notification is tapped while the app is running (foreground
  /// or already-launched). The launch-from-terminated case is handled via
  /// [takeLaunchPayload].
  static void Function(String payload)? onSelectNotification;

  /// Payload captured when a notification cold-starts the app. Consumed once by
  /// the first screen so it can route to the catch-up flow.
  static String? _pendingLaunchPayload;

  /// Initialize the plugin and notification channels.
  ///
  /// [requestPermissions] must only be true when running in the foreground
  /// (an Activity is attached). Requesting the Android POST_NOTIFICATIONS
  /// permission needs an Activity, so calling it from WorkManager's background
  /// isolate throws a NullPointerException. Background callers rely on the
  /// permission already having been granted from the foreground.
  static Future<void> init({bool requestPermissions = false}) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: requestPermissions,
      requestBadgePermission: requestPermissions,
      requestSoundPermission: requestPermissions,
    );
    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
          enableVibration: true,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _syncChannelId,
          _syncChannelName,
          description: 'Progress while syncing your health data',
          importance: Importance.low,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _catchupChannelId,
          _catchupChannelName,
          description: 'Prompts to resume syncing after a long gap',
          importance: Importance.high,
          enableVibration: true,
        ),
      );

      // Request POST_NOTIFICATIONS permission (Android 13+). Only possible
      // with an attached Activity, i.e. from the foreground.
      if (requestPermissions) {
        await android?.requestNotificationsPermission();
      }
    }
  }

  static void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) onSelectNotification?.call(payload);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) {
    // Cannot navigate from the background isolate. Tapping brings the app to the
    // foreground; routing then happens via [takeLaunchPayload] / onSelect.
  }

  /// Read (once) the payload of the notification that launched the app from a
  /// terminated state. Call from the first screen; returns null afterwards.
  static Future<String?> takeLaunchPayload() async {
    if (_pendingLaunchPayload != null) {
      final p = _pendingLaunchPayload;
      _pendingLaunchPayload = null;
      return p;
    }
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details!.notificationResponse?.payload;
    }
    return null;
  }

  // ── Sync progress (WhatsApp-style) ────────────────────────────────────────

  /// Show an ongoing, indeterminate sync-progress notification.
  static Future<void> showSyncProgress() async {
    const android = AndroidNotificationDetails(
      _syncChannelId,
      _syncChannelName,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showProgress: true,
      indeterminate: true,
    );
    await _plugin.show(
      _syncNotifId,
      'Syncing health data',
      'Fetching your latest readings…',
      const NotificationDetails(
        android: android,
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
  }

  /// Update the ongoing notification with determinate progress.
  static Future<void> updateSyncProgress({
    required int current,
    required int max,
    String? label,
  }) async {
    final android = AndroidNotificationDetails(
      _syncChannelId,
      _syncChannelName,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: max,
      progress: current,
    );
    await _plugin.show(
      _syncNotifId,
      'Syncing health data',
      label ?? 'Uploading $current of $max…',
      NotificationDetails(
        android: android,
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
  }

  /// Replace the ongoing notification with a completed (dismissible) one.
  static Future<void> completeSyncProgress({
    required int count,
    required bool success,
  }) async {
    final title = success ? 'Health data synced' : 'Sync incomplete';
    final body = success
        ? (count > 0 ? 'Uploaded $count new readings.' : 'You’re up to date.')
        : 'Couldn’t finish — will retry automatically.';
    const android = AndroidNotificationDetails(
      _syncChannelId,
      _syncChannelName,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: false,
      autoCancel: true,
      onlyAlertOnce: true,
      showProgress: false,
    );
    await _plugin.show(
      _syncNotifId,
      title,
      body,
      const NotificationDetails(
        android: android,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> cancelSyncProgress() => _plugin.cancel(_syncNotifId);

  // ── 48h catch-up prompt ───────────────────────────────────────────────────

  /// High-priority, actionable prompt shown when sync has been silent > 48h.
  static Future<void> showCatchUpNeeded() async {
    const android = AndroidNotificationDetails(
      _catchupChannelId,
      _catchupChannelName,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          catchUpActionId,
          'Sync now',
          showsUserInterface: true,
        ),
      ],
    );
    await _plugin.show(
      _catchupNotifId,
      'Health data is behind',
      'It’s been over 48 hours since your last sync. Tap to catch up.',
      const NotificationDetails(
        android: android,
        iOS: DarwinNotificationDetails(),
      ),
      payload: catchUpPayload,
    );
  }

  static Future<void> cancelCatchUp() => _plugin.cancel(_catchupNotifId);

  // ── Threshold alerts ──────────────────────────────────────────────────────

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
