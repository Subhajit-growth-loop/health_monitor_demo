import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys — deliberately plain strings so the WorkManager
/// background isolate (which has no access to Riverpod) can read/write the same
/// values via the static helpers below.
abstract final class SyncPrefsKeys {
  static const autoSync = 'auto_sync_enabled';
  static const intervalMinutes = 'auto_sync_interval_minutes';
  static const lastSuccessfulSyncMs = 'last_successful_sync_ms';
}

/// Foreground auto-sync interval choices (minutes). The background continuous
/// task always runs at the WorkManager 15-minute floor regardless.
const List<int> kSyncIntervalOptions = [5, 15, 30, 60];
const int kDefaultSyncIntervalMinutes = 15;

/// After this much silence the app prompts the user to catch up (spec §3).
const Duration kCatchUpThreshold = Duration(hours: 48);

/// User-controlled foreground sync preferences.
class SyncSettings {
  const SyncSettings({required this.autoSync, required this.intervalMinutes});

  final bool autoSync;
  final int intervalMinutes;

  SyncSettings copyWith({bool? autoSync, int? intervalMinutes}) => SyncSettings(
    autoSync: autoSync ?? this.autoSync,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
  );
}

/// Record a successful sync. Safe to call from the background isolate — opens
/// its own SharedPreferences instance rather than depending on the UI.
Future<void> markSyncSuccess() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(
    SyncPrefsKeys.lastSuccessfulSyncMs,
    DateTime.now().millisecondsSinceEpoch,
  );
}

/// Removes all user-specific sync prefs so a new user starts clean after logout.
Future<void> clearSyncPrefsOnLogout(SharedPreferences prefs) => Future.wait([
      prefs.remove(SyncPrefsKeys.autoSync),
      prefs.remove(SyncPrefsKeys.intervalMinutes),
      prefs.remove(SyncPrefsKeys.lastSuccessfulSyncMs),
    ]);

/// The timestamp of the last successful sync, or null if it has never synced.
Future<DateTime?> readLastSuccessfulSync() async {
  final prefs = await SharedPreferences.getInstance();
  final ms = prefs.getInt(SyncPrefsKeys.lastSuccessfulSyncMs);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

/// Provides the opened [SharedPreferences]. Overridden in `main()` once loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Owns the persisted [SyncSettings] and writes changes straight through to
/// SharedPreferences so the foreground scheduler and background isolate agree.
class SyncSettingsController extends Notifier<SyncSettings> {
  @override
  SyncSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SyncSettings(
      autoSync: prefs.getBool(SyncPrefsKeys.autoSync) ?? true,
      intervalMinutes:
          prefs.getInt(SyncPrefsKeys.intervalMinutes) ??
          kDefaultSyncIntervalMinutes,
    );
  }

  Future<void> setAutoSync(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(SyncPrefsKeys.autoSync, value);
    state = state.copyWith(autoSync: value);
  }

  Future<void> setIntervalMinutes(int minutes) async {
    await ref
        .read(sharedPreferencesProvider)
        .setInt(SyncPrefsKeys.intervalMinutes, minutes);
    state = state.copyWith(intervalMinutes: minutes);
  }
}

final syncSettingsProvider =
    NotifierProvider<SyncSettingsController, SyncSettings>(
      SyncSettingsController.new,
    );
