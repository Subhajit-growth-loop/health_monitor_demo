import 'package:dio/dio.dart';

/// Thin Dio wrapper over the auth + onboarding REST endpoints. Returns decoded
/// JSON maps; the repository maps them to domain entities. Endpoint shapes are
/// documented in `docs/onboarding-api-contract.md`.
///
/// In development every call is served by `MockApiInterceptor`; in production
/// the same calls hit the real backend (see `kUseMockApi` in `dio_client.dart`).
class OnboardingApi {
  OnboardingApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _asMap(Future<Response<dynamic>> req) async {
    final res = await req;
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> verifyReferral(String code) =>
      _asMap(_dio.post('/auth/referral/verify', data: {'code': code}));

  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? referralCode,
  }) => _asMap(
    _dio.post(
      '/auth/signup',
      data: {
        'email': email,
        'password': password,
        'referralCode': referralCode,
      },
    ),
  );

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _asMap(
    _dio.post('/auth/login', data: {'email': email, 'password': password}),
  );

  Future<Map<String, dynamic>> getOnboarding() =>
      _asMap(_dio.get('/onboarding'));

  Future<Map<String, dynamic>> patchProfile(Map<String, dynamic> changes) =>
      _asMap(_dio.patch('/profile', data: changes));

  Future<Map<String, dynamic>> patchOnboarding(Map<String, dynamic> answers) =>
      _asMap(_dio.patch('/onboarding', data: {'answers': answers}));

  Future<Map<String, dynamic>> complete() =>
      _asMap(_dio.post('/onboarding/complete'));
}
