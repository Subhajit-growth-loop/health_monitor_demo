import 'package:dio/dio.dart';

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
}
