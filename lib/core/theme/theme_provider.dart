import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/app_settings.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'neu_theme_mode';

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
