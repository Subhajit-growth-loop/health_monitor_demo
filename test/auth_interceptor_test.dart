import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_monitor_demo/core/network/app_urls.dart';
import 'package:health_monitor_demo/core/network/auth_interceptor.dart';
import 'package:health_monitor_demo/core/session/token_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scriptable backend: queue a status per path and count what arrives.
class _FakeServer implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  /// Per-path queue of responses. Each entry is popped in order; the last one
  /// repeats once exhausted.
  final Map<String, List<(int status, Map<String, dynamic> body)>> script = {};

  /// Gate used to hold responses open so concurrency can be observed.
  Completer<void>? gate;

  int countFor(String path) =>
      requests.where((r) => r.path == path).length;

  List<RequestOptions> forPath(String path) =>
      requests.where((r) => r.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (gate != null) await gate!.future;

    final queue = script[options.path];
    final (status, body) = queue == null || queue.isEmpty
        ? (200, <String, dynamic>{'ok': true})
        : (queue.length == 1 ? queue.first : queue.removeAt(0));

    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _pair(String access, String refresh, {int expiresIn = 900}) =>
    {
      'access_token': access,
      'refresh_token': refresh,
      'token_type': 'bearer',
      'expires_in': expiresIn,
    };

void main() {
  late SharedPreferences prefs;
  late _FakeServer server;
  late Dio dio;
  late AuthInterceptor auth;
  var expiredCount = 0;

  /// Builds the client under test. [refreshServer] backs the bare refresh
  /// client, mirroring how the real one is interceptor-free.
  void build({_FakeServer? refreshServer}) {
    server = _FakeServer();
    final refreshBacking = refreshServer ?? server;

    dio = Dio(BaseOptions(baseUrl: AppUrls.baseUrl))
      ..httpClientAdapter = server;

    final refreshDio = Dio(BaseOptions(baseUrl: AppUrls.baseUrl))
      ..httpClientAdapter = refreshBacking;

    auth = AuthInterceptor(
      dio: dio,
      refreshClient: refreshDio,
      onSessionExpired: () => expiredCount++,
    );
    dio.interceptors.add(auth);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    TokenManager.instance.init(prefs);
    expiredCount = 0;
    build();
  });

  Future<void> signedIn({int expiresIn = 900}) =>
      TokenManager.instance.setTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresIn: expiresIn,
      );

  group('attaching the token', () {
    test('adds the bearer header when signed in', () async {
      await signedIn();
      await dio.get('/patient/me/details');
      expect(
        server.forPath('/patient/me/details').single.headers['Authorization'],
        'Bearer access-1',
      );
    });

    test('sends no header when signed out', () async {
      await dio.get('/patient/me/details');
      expect(
        server.forPath('/patient/me/details').single
            .headers
            .containsKey('Authorization'),
        isFalse,
      );
    });

    test('auth routes are never given a header or a refresh', () async {
      await signedIn(expiresIn: 1); // would otherwise trigger a refresh
      await dio.post(AppUrls.login, data: {'email': 'a', 'password': 'b'});
      expect(server.countFor(AppUrls.refresh), 0);
      expect(
        server.forPath(AppUrls.login).single.headers
            .containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('proactive refresh before expiry', () {
    test('a token inside the skew window is renewed before the request',
        () async {
      // 30s left, skew is 2min → due for renewal.
      await signedIn(expiresIn: 30);
      server.script[AppUrls.refresh] = [(200, _pair('access-2', 'refresh-2'))];

      await dio.get('/patient/me/details');

      expect(server.countFor(AppUrls.refresh), 1);
      expect(
        server.forPath('/patient/me/details').single.headers['Authorization'],
        'Bearer access-2',
      );
      expect(TokenManager.instance.token, 'access-2');
      expect(TokenManager.instance.refreshToken, 'refresh-2');
    });

    test('a token with plenty of life left is left alone', () async {
      await signedIn(expiresIn: 3600);
      await dio.get('/patient/me/details');
      expect(server.countFor(AppUrls.refresh), 0);
    });

    test('no expiry from the server means no proactive refresh', () async {
      await TokenManager.instance.setTokens(
        accessToken: 'a',
        refreshToken: 'r',
      );
      expect(TokenManager.instance.needsRefresh, isFalse);
      await dio.get('/patient/me/details');
      expect(server.countFor(AppUrls.refresh), 0);
    });
  });

  group('reactive refresh on 401', () {
    test('refreshes and replays the original request', () async {
      await signedIn();
      server.script['/patient/me/details'] = [
        (401, {'message': 'Unauthorized'}),
        (200, {'name': 'William Harry'}),
      ];
      server.script[AppUrls.refresh] = [(200, _pair('access-2', 'refresh-2'))];

      final res = await dio.get<Map<String, dynamic>>('/patient/me/details');

      expect(res.data?['name'], 'William Harry');
      expect(server.countFor('/patient/me/details'), 2);
      // The replay carries the new token.
      expect(
        server.forPath('/patient/me/details').last.headers['Authorization'],
        'Bearer access-2',
      );
      expect(expiredCount, 0);
    });

    test('rotated tokens are both persisted', () async {
      await signedIn();
      server.script['/patient/me/details'] = [
        (401, {'message': 'Unauthorized'}),
        (200, {'ok': true}),
      ];
      server.script[AppUrls.refresh] = [
        (200, _pair('access-9', 'refresh-9', expiresIn: 600)),
      ];

      await dio.get('/patient/me/details');

      expect(TokenManager.instance.token, 'access-9');
      expect(TokenManager.instance.refreshToken, 'refresh-9');
      expect(TokenManager.instance.expiresAt, isNotNull);
      expect(TokenManager.instance.needsRefresh, isFalse);
    });

    test('an unauthenticated 401 is passed through untouched', () async {
      server.script['/public'] = [(401, {'message': 'nope'})];
      await expectLater(
        dio.get('/public'),
        throwsA(isA<DioException>()),
      );
      expect(server.countFor(AppUrls.refresh), 0);
      expect(expiredCount, 0);
    });

    test('a 401 on login does not trigger a refresh', () async {
      await signedIn();
      server.script[AppUrls.login] = [(401, {'message': 'Bad credentials'})];
      await expectLater(
        dio.post(AppUrls.login, data: {}),
        throwsA(isA<DioException>()),
      );
      expect(server.countFor(AppUrls.refresh), 0);
      expect(expiredCount, 0);
    });

    test('non-401 errors are not retried', () async {
      await signedIn();
      server.script['/patient/me/details'] = [(500, {'message': 'boom'})];
      await expectLater(
        dio.get('/patient/me/details'),
        throwsA(isA<DioException>()),
      );
      expect(server.countFor('/patient/me/details'), 1);
      expect(server.countFor(AppUrls.refresh), 0);
    });
  });

  group('session expiry', () {
    test('a rejected refresh token ends the session and clears tokens',
        () async {
      await signedIn();
      server.script['/patient/me/details'] = [(401, {'message': 'nope'})];
      server.script[AppUrls.refresh] = [
        (401, {'error': {'code': 'invalid_token'}}),
      ];

      await expectLater(
        dio.get('/patient/me/details'),
        throwsA(isA<DioException>()),
      );

      expect(expiredCount, 1);
      expect(TokenManager.instance.token, isNull);
      expect(TokenManager.instance.refreshToken, isNull);
    });

    test('a 401 with no refresh token stored ends the session', () async {
      await TokenManager.instance.setToken('access-only');
      server.script['/patient/me/details'] = [(401, {'message': 'nope'})];

      await expectLater(
        dio.get('/patient/me/details'),
        throwsA(isA<DioException>()),
      );

      expect(server.countFor(AppUrls.refresh), 0);
      expect(expiredCount, 1);
    });

    test('a request that 401s again after a successful refresh gives up',
        () async {
      await signedIn();
      // Always 401 — the retry flag must stop an infinite loop.
      server.script['/patient/me/details'] = [(401, {'message': 'nope'})];
      server.script[AppUrls.refresh] = [(200, _pair('access-2', 'refresh-2'))];

      await expectLater(
        dio.get('/patient/me/details'),
        throwsA(isA<DioException>()),
      );

      expect(server.countFor('/patient/me/details'), 2); // original + one retry
      expect(server.countFor(AppUrls.refresh), 1);
      expect(expiredCount, 1);
    });

    test('a refresh response with no access token counts as failure', () async {
      await signedIn();
      server.script['/patient/me/details'] = [(401, {'message': 'nope'})];
      server.script[AppUrls.refresh] = [(200, {'token_type': 'bearer'})];

      await expectLater(
        dio.get('/patient/me/details'),
        throwsA(isA<DioException>()),
      );
      expect(expiredCount, 1);
    });
  });

  group('single-flight', () {
    test('concurrent 401s share one refresh call', () async {
      await signedIn();
      server.script['/a'] = [(401, {}), (200, {})];
      server.script['/b'] = [(401, {}), (200, {})];
      server.script['/c'] = [(401, {}), (200, {})];
      server.script[AppUrls.refresh] = [(200, _pair('access-2', 'refresh-2'))];

      await Future.wait([dio.get('/a'), dio.get('/b'), dio.get('/c')]);

      // The critical assertion: rotation means a second refresh would have
      // invalidated the first, logging the user out mid-session.
      expect(server.countFor(AppUrls.refresh), 1);
      expect(expiredCount, 0);
    });

    test('concurrent proactive refreshes also collapse to one', () async {
      await signedIn(expiresIn: 5);
      server.script[AppUrls.refresh] = [(200, _pair('access-2', 'refresh-2'))];

      await Future.wait([dio.get('/a'), dio.get('/b'), dio.get('/c')]);

      expect(server.countFor(AppUrls.refresh), 1);
    });

    test('a later refresh starts fresh once the first has settled', () async {
      await signedIn(expiresIn: 5);
      server.script[AppUrls.refresh] = [
        (200, _pair('access-2', 'refresh-2', expiresIn: 5)),
        (200, _pair('access-3', 'refresh-3', expiresIn: 900)),
      ];

      await dio.get('/a');
      await dio.get('/b');

      expect(server.countFor(AppUrls.refresh), 2);
      expect(TokenManager.instance.token, 'access-3');
    });
  });

  group('no recursion through the refresh client', () {
    test('the refresh call itself is not intercepted', () async {
      // Refresh is backed by its own server; if the refresh call were routed
      // through `dio`, it would land on `server` instead.
      final refreshServer = _FakeServer();
      build(refreshServer: refreshServer);
      await signedIn();

      refreshServer.script[AppUrls.refresh] = [
        (200, _pair('access-2', 'refresh-2')),
      ];
      server.script['/patient/me/details'] = [(401, {}), (200, {})];

      await dio.get('/patient/me/details');

      expect(refreshServer.countFor(AppUrls.refresh), 1);
      expect(server.countFor(AppUrls.refresh), 0);
    });
  });

  group('TokenManager expiry bookkeeping', () {
    test('clearToken removes the expiry too', () async {
      await signedIn();
      expect(TokenManager.instance.expiresAt, isNotNull);
      await TokenManager.instance.clearToken();
      expect(TokenManager.instance.expiresAt, isNull);
      expect(TokenManager.instance.needsRefresh, isTrue);
    });

    test('an already-expired token needs refreshing', () async {
      await TokenManager.instance.setTokens(
        accessToken: 'a',
        refreshToken: 'r',
        expiresIn: -60,
      );
      expect(TokenManager.instance.needsRefresh, isTrue);
    });

    test('re-writing a pair replaces the previous expiry', () async {
      await signedIn(expiresIn: 30);
      expect(TokenManager.instance.needsRefresh, isTrue);
      await signedIn(expiresIn: 3600);
      expect(TokenManager.instance.needsRefresh, isFalse);
    });
  });
}