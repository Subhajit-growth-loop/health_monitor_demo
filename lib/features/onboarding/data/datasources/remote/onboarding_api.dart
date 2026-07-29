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

  Future<Map<String, dynamic>> getOnboarding() =>
      _asMap(_dio.get(AppUrls.onboarding));

  Future<Map<String, dynamic>> patchProfile(Map<String, dynamic> changes) =>
      _asMap(_dio.patch(AppUrls.profile, data: changes));

  Future<Map<String, dynamic>> patchOnboarding(Map<String, dynamic> answers) =>
      _asMap(_dio.patch(AppUrls.onboarding, data: {'answers': answers}));

  Future<Map<String, dynamic>> getPatientDetails() =>
      _asMap(_dio.get(AppUrls.patientDetails));

  Future<Map<String, dynamic>> savePatientProfile(Map<String, dynamic> data) =>
      _asMap(_dio.patch(AppUrls.patientDetails, data: data));

  Future<Map<String, dynamic>> complete() =>
      _asMap(_dio.post(AppUrls.onboardingComplete));
}
