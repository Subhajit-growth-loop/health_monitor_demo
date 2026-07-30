import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/token_manager.dart';
import '../settings/app_settings.dart';
import 'app_urls.dart';
import 'mock_api_interceptor.dart';

/// A configured [Dio] shared across the auth + onboarding data sources.
///
/// - Sets the base URL and sane timeouts.
/// - Attaches `Authorization: Bearer <token>` from SharedPreferences on every
///   request once the user has signed in.
/// - Attaches [MockApiInterceptor], which answers the three onboarding-draft
///   routes locally and forwards everything else — including the Verify-info
///   step's `PATCH /patient/me/details` — to the real API.
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

  dio.interceptors.add(
    MockApiInterceptor(ref.watch(sharedPreferencesProvider)),
  );

  return dio;
});