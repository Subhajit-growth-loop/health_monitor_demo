import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/network/app_urls.dart';

class OnboardingApi {
  OnboardingApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _asMap(Future<Response<dynamic>> req) async {
    final res = await req;
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  /// Logs a chat request and its response in debug builds. The chat endpoints are
  /// the hardest to reason about from the UI alone — the session id, the `done`
  /// flag and the summary all decide what the screen does next — so both
  /// directions are printed in full.
  ///
  /// Failures are not logged here: they reach `AppErrorHandler`, which already
  /// prints the status, path and body.
  Future<Map<String, dynamic>> _logged(
    String label,
    Map<String, dynamic> body,
    Future<Map<String, dynamic>> Function() call,
  ) async {
    if (!kDebugMode) return call();

    debugPrint('[OnboardingChat] → $label request: ${_pretty(body)}');
    final res = await call();
    debugPrint('[OnboardingChat] ← $label response: ${_pretty(res)}');
    return res;
  }

  /// Indented JSON, chunked so debugPrint doesn't truncate a long payload.
  static String _pretty(Object? value) {
    late final String text;
    try {
      text = const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
    return text;
  }

  Future<Map<String, dynamic>> verifyReferral(String code) => _asMap(
    _dio.get(AppUrls.referenceEmail, queryParameters: {'ref_number': code}),
  );

  Future<Map<String, dynamic>> signup({
    required String refNumber,
    required String email,
    required String password,
    required String confirmPassword,
  }) => _asMap(
    _dio.post(AppUrls.register, data: {
      'ref_number': refNumber,
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
    }),
  );

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _asMap(
    _dio.post(AppUrls.login, data: {'email': email, 'password': password}),
  );

  /// POST /auth/logout — real endpoint. Ends the session for [refreshToken].
  Future<Map<String, dynamic>> logout(String refreshToken) => _asMap(
    _dio.post(AppUrls.logout, data: {'refresh_token': refreshToken}),
  );

  /// Mock-served. Returns { profile, draft, stepIndex }.
  Future<Map<String, dynamic>> getOnboarding() =>
      _asMap(_dio.get(AppUrls.onboarding));

  /// Mock-served. Persists a step's [answers] and the step the user is now on.
  Future<Map<String, dynamic>> patchOnboarding(
    Map<String, dynamic> answers, {
    required int stepIndex,
  }) => _asMap(
    _dio.patch(
      AppUrls.onboarding,
      data: {'answers': answers, 'step_index': stepIndex},
    ),
  );

  /// GET /patient/me/details
  Future<Map<String, dynamic>> getPatientDetails() =>
      _asMap(_dio.get(AppUrls.patientDetails));

  /// PATCH /patient/me/details — the only write for the Verify-info step.
  /// Returns the server's updated record, which is what the UI then renders.
  Future<Map<String, dynamic>> patchPatientDetails(
    Map<String, dynamic> data,
  ) => _asMap(_dio.patch(AppUrls.patientDetails, data: data));

  Future<Map<String, dynamic>> complete() =>
      _asMap(_dio.post(AppUrls.onboardingComplete));

  // ── AI onboarding chat ─────────────────────────────────────────────────────

  /// POST /onboarding-chat/start — [onboarding] is the structured questionnaire
  /// payload, passed through to the AI planner verbatim.
  ///
  /// Relies on the client-wide 300s send/receive budget in dio_client.dart —
  /// every chat call costs one LLM round-trip.
  Future<Map<String, dynamic>> startChat({
    required String patientId,
    required Map<String, dynamic> onboarding,
  }) {
    final body = {'patient_id': patientId, 'onboarding': onboarding};
    return _logged(
      'START',
      body,
      () => _asMap(_dio.post(AppUrls.onboardingChatStart, data: body)),
    );
  }

  /// POST /onboarding-chat/turn — submits one answer and gets the next question
  /// or the final summary.
  Future<Map<String, dynamic>> chatTurn({
    required String sessionId,
    required String answer,
  }) {
    final body = {'session_id': sessionId, 'answer': answer};
    return _logged(
      'TURN',
      body,
      () => _asMap(_dio.post(AppUrls.onboardingChatTurn, data: body)),
    );
  }
}
