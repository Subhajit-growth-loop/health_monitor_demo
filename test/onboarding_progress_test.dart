import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_monitor_demo/app/app_url.dart';
import 'package:health_monitor_demo/core/network/mock_api_interceptor.dart';
import 'package:health_monitor_demo/core/session/current_user.dart';
import 'package:health_monitor_demo/core/session/onboarding_progress.dart';
import 'package:health_monitor_demo/features/onboarding/data/datasources/remote/onboarding_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the real backend. Any request that reaches it was *not*
/// intercepted by the mock — which is the point of the pass-through tests.
class _RealBackend implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Map<String, dynamic> reply = {'ok': true};

  RequestOptions get last => requests.last;
  Map<String, dynamic> get lastBody =>
      Map<String, dynamic>.from(last.data as Map);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(reply),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late SharedPreferences prefs;
  late _RealBackend backend;
  late OnboardingApi api;

  Future<void> signIn(String email) => CurrentUser.instance.set(
        id: 'u1',
        email: email,
        name: 'William Harry',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    CurrentUser.instance.init(prefs);

    backend = _RealBackend();
    final dio = Dio(BaseOptions(baseUrl: AppUrls.baseUrl))
      ..httpClientAdapter = backend
      ..interceptors.add(MockApiInterceptor(prefs, latency: Duration.zero));
    api = OnboardingApi(dio);
  });

  group('the mock serves draft steps and nothing else', () {
    test('GET /onboarding never reaches the network', () async {
      await signIn('a@b.com');
      final res = await api.getOnboarding();
      expect(backend.requests, isEmpty);
      expect(res.containsKey('draft'), isTrue);
      expect(res['stepIndex'], 0);
    });

    test('PATCH /onboarding never reaches the network', () async {
      await signIn('a@b.com');
      await api.patchOnboarding({'note': 'hello'}, stepIndex: 2);
      expect(backend.requests, isEmpty);
    });

    test('POST /onboarding/complete never reaches the network', () async {
      await signIn('a@b.com');
      final res = await api.complete();
      expect(backend.requests, isEmpty);
      expect(res['userName'], 'William');
    });

    test('verify-info PATCH /patient/me/details DOES hit the real API',
        () async {
      await signIn('a@b.com');
      backend.reply = {'name': 'William Harry', 'gender': 'female'};
      await api.patchPatientDetails({'name': 'William Harry'});
      expect(backend.requests, hasLength(1));
      expect(backend.last.method, 'PATCH');
      expect(backend.last.path, '/patient/me/details');
      expect(backend.lastBody['name'], 'William Harry');
    });

    test('GET /patient/me/details DOES hit the real API', () async {
      await signIn('a@b.com');
      await api.getPatientDetails();
      expect(backend.requests, hasLength(1));
      expect(backend.last.path, '/patient/me/details');
    });

    test('login DOES hit the real API', () async {
      await api.login(email: 'a@b.com', password: 'x');
      expect(backend.requests, hasLength(1));
      expect(backend.last.path, '/auth/login');
    });

    test('logout posts the refresh token to the real API', () async {
      await api.logout('refresh-abc');
      expect(backend.requests, hasLength(1));
      expect(backend.last.method, 'POST');
      expect(backend.last.path, '/auth/logout');
      expect(backend.lastBody, {'refresh_token': 'refresh-abc'});
    });
  });

  group('answers and step survive, scoped to the email', () {
    test('a saved step comes back on the next GET', () async {
      await signIn('a@b.com');
      await api.patchOnboarding({'note': 'my note'}, stepIndex: 4);

      final res = await api.getOnboarding();
      expect(res['stepIndex'], 4);
      expect((res['draft'] as Map)['note'], 'my note');
    });

    test('answers accumulate across steps', () async {
      await signIn('a@b.com');
      await api.patchOnboarding({'motivations': ['energy']}, stepIndex: 1);
      await api.patchOnboarding({'symptoms': ['fatigue']}, stepIndex: 2);

      final draft = (await api.getOnboarding())['draft'] as Map;
      expect(draft['motivations'], ['energy']);
      expect(draft['symptoms'], ['fatigue']);
    });

    test('a different email starts clean', () async {
      await signIn('a@b.com');
      await api.patchOnboarding({'note': 'first user'}, stepIndex: 5);

      await signIn('other@b.com');
      final res = await api.getOnboarding();
      expect(res['stepIndex'], 0);
      expect((res['draft'] as Map)['note'], '');
    });

    test('the first email still resumes after the second signs in', () async {
      await signIn('a@b.com');
      await api.patchOnboarding({'note': 'first user'}, stepIndex: 5);
      await signIn('other@b.com');
      await api.patchOnboarding({'note': 'second user'}, stepIndex: 1);

      await signIn('a@b.com');
      final res = await api.getOnboarding();
      expect(res['stepIndex'], 5);
      expect((res['draft'] as Map)['note'], 'first user');
    });

    test('email match ignores case and surrounding whitespace', () async {
      await signIn('a@b.com');
      await api.patchOnboarding({'note': 'saved'}, stepIndex: 3);

      await signIn('  A@B.COM ');
      expect((await api.getOnboarding())['stepIndex'], 3);
    });

    test('profile is never served by the mock — it comes from the real GET',
        () async {
      await signIn('a@b.com');
      final res = await api.getOnboarding();
      expect(res['profile'], isEmpty);
    });
  });

  group('per-email completion flag', () {
    test('defaults to not complete', () {
      expect(OnboardingProgress.isComplete(prefs, 'a@b.com'), isFalse);
    });

    test('marking one email complete does not affect another', () async {
      await OnboardingProgress.markComplete(prefs, 'a@b.com');
      expect(OnboardingProgress.isComplete(prefs, 'a@b.com'), isTrue);
      expect(OnboardingProgress.isComplete(prefs, 'other@b.com'), isFalse);
    });

    test('the legacy global flag is honoured for existing installs', () async {
      SharedPreferences.setMockInitialValues({
        'neu_onboarding_complete': true,
      });
      final legacy = await SharedPreferences.getInstance();
      expect(OnboardingProgress.isComplete(legacy, 'anyone@b.com'), isTrue);
    });

    test('an explicit per-email value wins over the legacy flag', () async {
      SharedPreferences.setMockInitialValues({
        'neu_onboarding_complete': true,
      });
      final p = await SharedPreferences.getInstance();
      await OnboardingProgress.markIncomplete(p, 'fresh@b.com');
      expect(OnboardingProgress.isComplete(p, 'fresh@b.com'), isFalse);
    });

    test('clearDraft wipes saved answers but keeps the completion flag',
        () async {
      await signIn('a@b.com');
      await api.patchOnboarding({'note': 'saved'}, stepIndex: 4);
      await OnboardingProgress.markComplete(prefs, 'a@b.com');

      await OnboardingProgress.clearDraft(prefs, 'a@b.com');

      expect((await api.getOnboarding())['stepIndex'], 0);
      expect(OnboardingProgress.isComplete(prefs, 'a@b.com'), isTrue);
    });
  });
}