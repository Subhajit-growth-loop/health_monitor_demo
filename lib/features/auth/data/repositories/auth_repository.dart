import 'package:dio/dio.dart';
import '../../../../app/app_url.dart';

class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> verifyReferral(String code) async {
    final res = await _dio.get(
      AppUrls.referenceEmail,
      queryParameters: {'ref_number': code},
    );
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> signup({
    required String refNumber,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final res = await _dio.post(AppUrls.register, data: {
      'ref_number': refNumber,
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
    });
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      AppUrls.login,
      data: {'email': email, 'password': password},
    );
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> logout(String refreshToken) async {
    final res = await _dio.post(
      AppUrls.logout,
      data: {'refresh_token': refreshToken},
    );
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }
}
