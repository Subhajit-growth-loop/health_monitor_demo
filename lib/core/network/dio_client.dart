import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import 'mock_api_interceptor.dart';

/// Flip to `false` and set [kApiBaseUrl] to the real backend to go live. When
/// `true`, [MockApiInterceptor] serves every request in-app (no network).
const bool kUseMockApi = true;

/// TODO: replace with the real backend base URL when [kUseMockApi] is false.
const String kApiBaseUrl = 'https://api.neuhealth.example/v1';

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
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref
            .read(sharedPreferencesProvider)
            .getString('neu_token');
        if (token != null && token.isNotEmpty) {
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
