import 'dart:async';

import 'package:dio/dio.dart';

/// In-app **mock backend** for the splash → onboarding surface.
///
/// While there is no real server, this interceptor short-circuits every request
/// to a known path and resolves it with a canned REST response. It keeps a
/// mutable in-memory store so that `PATCH`/`POST` writes are reflected by later
/// `GET`s — which is what lets the onboarding flow reload previously-saved
/// answers when the user navigates back.
///
/// To go live: set `kUseMockApi = false` in `dio_client.dart` and point
/// `baseUrl` at the real API. Nothing else in the app changes — the request
/// shapes here match `docs/onboarding-api-contract.md`.
class MockApiInterceptor extends Interceptor {
  MockApiInterceptor({this.latency = const Duration(milliseconds: 600)});

  /// Simulated round-trip latency so loading states behave realistically.
  final Duration latency;

  // ── In-memory store ────────────────────────────────────────────────────────

  /// Profile records "shared by the care team" — pre-populated, editable on the
  /// Verify-your-information step.
  final Map<String, dynamic> _profile = {
    'fullName': 'William Harry',
    'dateOfBirth': '1974-03-14',
    'gender': 'female',
    'primaryDiagnosis': 'MASLD',
    'diagnosedDate': '2025-01',
    'otherConditions': 'Metformin 500mg',
    'currentMedications': '',
  };

  /// The user's onboarding answers. Starts blank (except sensible slider/stepper
  /// defaults) and is filled in step by step.
  final Map<String, dynamic> _draft = {
    'currentStep': 0,
    'motivations': <String>[],
    'supportTypes': <String>[],
    'activityLevel': 'low',
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

  // ── Interception ─────────────────────────────────────────────────────────────

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final path = options.path;
    final method = options.method.toUpperCase();
    final body = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};

    await Future<void>.delayed(latency);

    Map<String, dynamic>? payload;

    switch ((method, path)) {
      case ('POST', '/auth/referral/verify'):
        final code = (body['code'] as String? ?? '').trim();
        payload = code.isEmpty
            ? {'valid': false, 'memberName': null}
            : {'valid': true, 'memberName': 'Harry'};

      case ('POST', '/auth/signup'):
        payload = {
          'userId': 'usr_mock_001',
          'token': 'mock_token_signup',
          'email': body['email'],
          'gender': _profile['gender'],
        };

      case ('POST', '/auth/login'):
        payload = {
          'userId': 'usr_mock_001',
          'token': 'mock_token_login',
          'email': body['email'],
          'gender': _profile['gender'],
        };

      case ('GET', '/onboarding'):
        payload = {'profile': _profile, 'draft': _draft};

      case ('GET', '/profile'):
        payload = Map<String, dynamic>.from(_profile);

      case ('PATCH', '/profile'):
        _profile.addAll(body);
        payload = Map<String, dynamic>.from(_profile);

      case ('PATCH', '/onboarding'):
        // Body: { "answers": { ...partial draft... } }.
        final answers = body['answers'];
        if (answers is Map) _draft.addAll(Map<String, dynamic>.from(answers));
        payload = Map<String, dynamic>.from(_draft);

      case ('POST', '/onboarding/complete'):
        final full = (_profile['fullName'] as String? ?? '').trim();
        final first = full.isEmpty ? 'there' : full.split(' ').first;
        payload = {
          'coachName': 'Maya',
          'userName': first,
          'whatHappensNext': [
            '3–4 days of quiet observation as your data comes in.',
            'A nurse calls you on day 5 to review what we\'ve seen.',
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

    // Unknown path — surface a 404 so bugs are obvious rather than hanging.
    handler.reject(
      DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 404),
        type: DioExceptionType.badResponse,
        error: 'MockApiInterceptor: no handler for $method $path',
      ),
    );
  }
}
