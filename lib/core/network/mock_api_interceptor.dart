import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../session/current_user.dart';
import 'app_urls.dart';

/// Mock backend for the onboarding **answer draft** only.
///
/// Exactly three routes are served locally — the ones that persist a step's
/// answers and finalize the flow:
///
///   GET   /onboarding
///   PATCH /onboarding
///   POST  /onboarding/complete
///
/// Every other request (auth, and crucially `PATCH /patient/me/details` behind
/// the Verify-your-information step) is passed straight through to the real API
/// via `handler.next`.
///
/// The store is [SharedPreferences], keyed by the signed-in email, so answers
/// **and the step the user reached** survive an app restart. Logging back in
/// with the same email resumes the flow where it left off; a different email
/// starts clean.
class MockApiInterceptor extends Interceptor {
  MockApiInterceptor(
    this._prefs, {
    this.latency = const Duration(milliseconds: 250),
  });

  final SharedPreferences _prefs;

  /// Simulated round-trip latency so loading states behave realistically.
  final Duration latency;

  // ── Per-email store ────────────────────────────────────────────────────────

  static const _keyPrefix = 'neu_onboarding_progress_';

  /// Scopes saved progress to the signed-in user. Falls back to a shared bucket
  /// for the (unusual) case of reaching onboarding with no email set.
  String get _storeKey => keyFor(CurrentUser.instance.email);

  static String keyFor(String email) {
    final normalised = email.trim().toLowerCase();
    return '$_keyPrefix${normalised.isEmpty ? '_anonymous' : normalised}';
  }

  Map<String, dynamic> _read() {
    final raw = _prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) {
      return {'draft': blankDraft(), 'stepIndex': 0};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        map['draft'] = map['draft'] is Map
            ? {...blankDraft(), ...Map<String, dynamic>.from(map['draft'] as Map)}
            : blankDraft();
        map['stepIndex'] = (map['stepIndex'] as num?)?.toInt() ?? 0;
        return map;
      }
    } catch (_) {
      // Corrupt entry — fall through to a clean slate rather than crashing.
    }
    return {'draft': blankDraft(), 'stepIndex': 0};
  }

  Future<void> _write(Map<String, dynamic> store) =>
      _prefs.setString(_storeKey, jsonEncode(store));

  /// A blank answer draft — sensible slider/stepper defaults, everything else
  /// empty so each step starts unanswered.
  static Map<String, dynamic> blankDraft() => {
    'motivations': <String>[],
    'supportTypes': <String>[],
    'activityLevel': null,
    'eatingRhythm': null,
    'sleepHours': 7,
    'dietaryPrefs': <String>[],
    'menstrualCycle': null,
    'symptoms': <String>[],
    'feeling': {'sleep': 0.5, 'energy': 0.5, 'stress': 0.5, 'mood': 0.5},
    'note': '',
    'connectChoice': null,
    'connectedSources': <String>[],
    'firstAction': null,
  };

  /// Wipes the saved draft + step for [email]. Called on logout so the next
  /// sign-in on this device cannot inherit someone else's answers.
  static Future<void> clearFor(SharedPreferences prefs, String email) =>
      prefs.remove(keyFor(email));

  // ── Interception ───────────────────────────────────────────────────────────

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final path = options.path;
    final method = options.method.toUpperCase();

    // Anything that is not a draft route belongs to the real backend.
    if (path != AppUrls.onboarding && path != AppUrls.onboardingComplete) {
      handler.next(options);
      return;
    }

    final body = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};

    await Future<void>.delayed(latency);

    final store = _read();
    final draft = Map<String, dynamic>.from(store['draft'] as Map);
    Map<String, dynamic>? payload;

    switch ((method, path)) {
      case ('GET', AppUrls.onboarding):
        // `profile` stays empty on purpose — the Verify-info step's fields come
        // from the real GET /patient/me/details, never from here.
        payload = {
          'profile': <String, dynamic>{},
          'draft': draft,
          'stepIndex': store['stepIndex'],
        };

      case ('PATCH', AppUrls.onboarding):
        // Body: { answers: { ...partial draft... }, step_index: <int> }.
        final answers = body['answers'];
        if (answers is Map) {
          draft.addAll(Map<String, dynamic>.from(answers));
        }
        final step = (body['step_index'] as num?)?.toInt();
        await _write({
          'draft': draft,
          'stepIndex': step ?? store['stepIndex'],
        });
        payload = draft;

      case ('POST', AppUrls.onboardingComplete):
        final first = CurrentUser.instance.firstName;
        payload = {
          'coachName': 'Maya',
          'userName': first.isEmpty ? 'there' : first,
          'whatHappensNext': [
            '3–4 days of quiet observation as your data comes in.',
            "A nurse calls you on day 5 to review what we've seen.",
            'Then we build your first treatment plan together.',
          ],
        };
    }

    if (payload != null) {
      handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: payload,
        ),
      );
      return;
    }

    // A draft path with an unexpected verb — surface it rather than hanging.
    handler.reject(
      DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 405),
        type: DioExceptionType.badResponse,
        error: 'MockApiInterceptor: no handler for $method $path',
      ),
    );
  }
}