import 'package:shared_preferences/shared_preferences.dart';

import '../network/mock_api_interceptor.dart';

/// Tracks, per email, whether onboarding was finished on this device.
///
/// Keyed by email rather than globally so signing in as a second user does not
/// inherit the first user's "already onboarded" state. The answer draft and the
/// step reached are stored alongside it by [MockApiInterceptor], under its own
/// per-email key.
abstract final class OnboardingProgress {
  static const _completePrefix = 'neu_onboarding_complete_';

  /// Legacy global flag from before progress was per-email. Read as a fallback
  /// so existing installs are not sent back through onboarding.
  static const _legacyKey = 'neu_onboarding_complete';

  static String _key(String email) =>
      '$_completePrefix${email.trim().toLowerCase()}';

  static bool isComplete(SharedPreferences prefs, String email) {
    final scoped = prefs.getBool(_key(email));
    if (scoped != null) return scoped;
    return prefs.getBool(_legacyKey) ?? false;
  }

  static Future<void> markComplete(
    SharedPreferences prefs,
    String email,
  ) async {
    await prefs.setBool(_key(email), true);
    await prefs.remove(_legacyKey);
  }

  /// Marks onboarding as not-yet-done — used right after signup so a fresh
  /// account always starts the flow.
  static Future<void> markIncomplete(
    SharedPreferences prefs,
    String email,
  ) async {
    await prefs.setBool(_key(email), false);
    await prefs.remove(_legacyKey);
  }

  /// Clears the saved answer draft and step for [email]. The completion flag is
  /// deliberately left alone: a user who finished onboarding and logged out has
  /// still finished it.
  static Future<void> clearDraft(SharedPreferences prefs, String email) =>
      MockApiInterceptor.clearFor(prefs, email);
}