import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/app_settings.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'neu_theme_mode';

  /// Set once after the light-default switchover, so anyone carrying a saved
  /// `dark` from when dark was the default lands on light instead. Cleared
  /// choices are re-honoured immediately after — the switch keeps working.
  static const _resetKey = 'neu_theme_reset_to_light_v1';

  /// Drops a stale saved choice exactly once. Call from main() before the app
  /// builds; a no-op on every launch after the first.
  static Future<void> resetToLightOnce(SharedPreferences prefs) async {
    if (prefs.getBool(_resetKey) ?? false) return;
    await prefs.remove(_key);
    await prefs.setBool(_resetKey, true);
  }

  // Defaults to light unless the user has explicitly chosen dark.
  static ThemeMode _load(SharedPreferences prefs) =>
      prefs.getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;

  void setMode(ThemeMode mode) {
    state = mode;
    _prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(sharedPreferencesProvider));
});
