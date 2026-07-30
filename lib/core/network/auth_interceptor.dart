import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../session/token_manager.dart';
import 'app_urls.dart';

/// Keeps the session alive by exchanging the refresh token for a new pair
/// whenever the access token is expired or rejected.
///
/// Owns the whole token lifecycle on the request path:
///
///  1. Attaches `Authorization: Bearer <access>` to every request.
///  2. Refreshes *before* sending when the stored expiry is within
///     [TokenManager.refreshSkew], so a token never dies mid-flight.
///  3. On a 401, refreshes once and replays the original request.
///  4. Only when the refresh itself fails does the session end — that is when
///     [onSessionExpired] fires.
///
/// Point 4 is why this class, and not `AppErrorHandler`, decides that a session
/// is over: a 401 is routine and usually recoverable, and treating every one as
/// terminal logs users out who had a perfectly good refresh token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    Dio? refreshClient,
    this.onSessionExpired,
  })  : _dio = dio,
        // Deliberately interceptor-free: routing the refresh call back through
        // this interceptor would recurse on its own 401.
        _refreshDio = refreshClient ??
            Dio(BaseOptions(
              baseUrl: dio.options.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              contentType: 'application/json',
            ));

  /// The client whose requests are being authorized — used to replay a request
  /// after a refresh.
  final Dio _dio;

  /// Bare client used only for `POST /auth/refresh`.
  final Dio _refreshDio;

  /// Called when the refresh token is gone or rejected, i.e. the user really
  /// does have to sign in again. Wired in main.dart to clear the session and
  /// navigate to the login screen.
  final VoidCallback? onSessionExpired;

  /// Marks a request that has already been retried once, so a persistently
  /// 401-ing endpoint can't loop.
  static const _retriedFlag = 'auth_retried';

  /// Endpoints that must never trigger a refresh: the token endpoints
  /// themselves, and login (a 401 there means bad credentials).
  static bool _isAuthRoute(String path) =>
      path == AppUrls.login ||
      path == AppUrls.refresh ||
      path == AppUrls.logout ||
      path == AppUrls.register;

  // ── Single-flight refresh ──────────────────────────────────────────────────

  /// Shared across concurrent callers. `/auth/refresh` rotates the refresh
  /// token, so two parallel refreshes would invalidate each other and log the
  /// user out *because* the session was renewed twice.
  Future<bool>? _inFlight;

  Future<bool> refresh() =>
      _inFlight ??= _performRefresh().whenComplete(() => _inFlight = null);

  Future<bool> _performRefresh() async {
    final refreshToken = TokenManager.instance.refreshToken;
    if (refreshToken == null) return false;

    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        AppUrls.refresh,
        data: {'refresh_token': refreshToken},
      );

      final data = res.data ?? const {};
      final access = data['access_token'] as String?;
      final rotated = data['refresh_token'] as String?;
      if (access == null || access.isEmpty) return false;

      // Both tokens land in one write — a half-applied pair would leave the
      // session unrecoverable. The server rotates the refresh token, so fall
      // back to the current one only if it somehow omitted a new one.
      await TokenManager.instance.setTokens(
        accessToken: access,
        refreshToken: (rotated != null && rotated.isNotEmpty)
            ? rotated
            : refreshToken,
        expiresIn: (data['expires_in'] as num?)?.toInt(),
      );
      return true;
    } on DioException catch (e) {
      // A rejected refresh token is terminal — never retry it. A rotation whose
      // response was lost leaves us holding a dead token, and retrying would
      // only produce the same 401.
      final status = e.response?.statusCode;
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] refresh failed (${status ?? e.type})');
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Ends the session exactly once per expiry.
  Future<void> _expireSession() async {
    await TokenManager.instance.clearToken();
    onSessionExpired?.call();
  }

  // ── Interception ───────────────────────────────────────────────────────────

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isAuthRoute(options.path)) {
      handler.next(options);
      return;
    }

    // Proactive: renew a token that is expired or about to be, so the common
    // case costs no failed round-trip.
    final tokens = TokenManager.instance;
    if (tokens.refreshToken != null && tokens.hasToken && tokens.needsRefresh) {
      await refresh();
    }

    final token = tokens.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final recoverable = err.response?.statusCode == 401 &&
        !_isAuthRoute(options.path) &&
        options.extra[_retriedFlag] != true;

    if (!recoverable) {
      handler.next(err);
      return;
    }

    // An unauthenticated 401 is not a session problem — nothing to refresh.
    if (!options.headers.containsKey('Authorization')) {
      handler.next(err);
      return;
    }

    if (!await refresh()) {
      await _expireSession();
      handler.next(err);
      return;
    }

    try {
      final retried = options..extra[_retriedFlag] = true;
      handler.resolve(await _dio.fetch<dynamic>(retried));
    } on DioException catch (e) {
      // The replay failed on its own terms (still 401, or something else).
      if (e.response?.statusCode == 401) await _expireSession();
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }
}