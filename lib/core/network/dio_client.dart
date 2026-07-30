import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/app_error_handler.dart';
import '../settings/app_settings.dart';
import 'app_urls.dart';
import 'auth_interceptor.dart';
import 'mock_api_interceptor.dart';

/// A configured [Dio] shared across the auth + onboarding data sources.
///
/// - Sets the base URL and sane timeouts.
/// - [AuthInterceptor] attaches the bearer token, renews it before expiry, and
///   retries a 401 once after refreshing. Only a failed refresh ends the
///   session.
/// - [MockApiInterceptor] answers the three onboarding-draft routes locally and
///   forwards everything else — including the Verify-info step's
///   `PATCH /patient/me/details` — to the real API.
///
/// Order matters: the auth interceptor is added first so it sees requests before
/// the mock short-circuits them, and errors after the mock has declined them.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppUrls.baseUrl,
      // connectTimeout stays short: it covers *reaching* the host, so a genuinely
      // offline device should fail fast rather than hang for minutes.
      connectTimeout: const Duration(seconds: 15),
      // Generous send/receive budgets — the AI endpoints run an LLM call per
      // request and a cold start can take far longer than a normal REST reply.
      sendTimeout: const Duration(seconds: 300),
      receiveTimeout: const Duration(seconds: 300),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      // Same destination as before — clear the session and go to login — but
      // now reached only after a refresh attempt has genuinely failed.
      onSessionExpired: () => AppErrorHandler.instance.onSessionExpired?.call(),
    ),
  );

  dio.interceptors.add(
    MockApiInterceptor(ref.watch(sharedPreferencesProvider)),
  );

  return dio;
});