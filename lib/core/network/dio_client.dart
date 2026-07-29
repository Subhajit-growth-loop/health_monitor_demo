import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/token_manager.dart';
import 'app_urls.dart';
import 'mock_api_interceptor.dart';

/// Flip to `true` to run entirely in-app with canned responses (no network).
const bool kUseMockApi = false;

/// A configured [Dio] shared across the auth + onboarding data sources.
///
/// - Sets the base URL and sane timeouts.
/// - Attaches `Authorization: Bearer <token>` from SharedPreferences on every
///   request once the user has signed in.
/// - In mock mode, attaches [MockApiInterceptor] which resolves requests with
///   canned REST responses.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppUrls.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = TokenManager.instance.token;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  if (kUseMockApi) {
    dio.interceptors.add(MockApiInterceptor());
  }

  return dio;
});
