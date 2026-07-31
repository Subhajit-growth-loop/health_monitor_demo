import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_monitor_demo/app/app_url.dart';
import 'package:health_monitor_demo/features/onboarding/data/datasources/remote/onboarding_api.dart';
import 'package:health_monitor_demo/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:health_monitor_demo/features/onboarding/domain/entities/onboarding_chat.dart';
import 'package:health_monitor_demo/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:health_monitor_demo/features/onboarding/domain/entities/user_profile.dart';
import 'package:health_monitor_demo/features/onboarding/presentation/view_model/onboarding_chat_controller.dart';

class _Server implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, (int, Map<String, dynamic>)> script = {};

  RequestOptions get last => requests.last;
  Map<String, dynamic> bodyOf(String path) => Map<String, dynamic>.from(
        requests.lastWhere((r) => r.path == path).data as Map,
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) =
        script[options.path] ?? (200, <String, dynamic>{'ok': true});
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

void main() {
  late _Server server;
  late OnboardingRepositoryImpl repo;

  setUp(() {
    server = _Server();
    final dio = Dio(BaseOptions(baseUrl: AppUrls.baseUrl))
      ..httpClientAdapter = server;
    repo = OnboardingRepositoryImpl(OnboardingApi(dio));
  });

  group('parsing the unified ChatResponse', () {
    test('an in-progress turn carries acknowledgment and question', () {
      final res = OnboardingChatResponse.fromJson({
        'session_id': 'onb_1',
        'done': false,
        'acknowledgment': 'Thank you for being so open.',
        'question': 'What has worked before?',
        'summary': null,
      });

      expect(res.sessionId, 'onb_1');
      expect(res.done, isFalse);
      expect(res.acknowledgment, 'Thank you for being so open.');
      expect(res.question, 'What has worked before?');
      expect(res.summary, isNull);
    });

    test('/start has a null acknowledgment', () {
      final res = OnboardingChatResponse.fromJson({
        'session_id': 'onb_1',
        'done': false,
        'acknowledgment': null,
        'question': 'What has daily life looked like?',
      });
      expect(res.acknowledgment, isNull);
      expect(res.question, isNotNull);
    });

    test('a finished conversation carries the summary and no question', () {
      final res = OnboardingChatResponse.fromJson({
        'session_id': 'onb_1',
        'done': true,
        'acknowledgment': null,
        'question': null,
        'summary': {
          'facts': [
            {
              'category': 'barrier',
              'value': 'Too tired to cook on work evenings',
              'source_quote': "I'm too tired to cook most evenings",
            },
            {
              'category': 'psychosocial',
              'value': 'Frightened by the diagnosis',
              'source_quote': 'the diagnosis scared me',
            },
          ],
          'narrative': 'Sarah was diagnosed two months ago…',
        },
      });

      expect(res.done, isTrue);
      expect(res.question, isNull);
      expect(res.summary!.facts, hasLength(2));
      expect(res.summary!.facts.first.category, 'barrier');
      expect(
        res.summary!.facts.first.sourceQuote,
        "I'm too tired to cook most evenings",
      );
      expect(res.summary!.narrative, startsWith('Sarah was diagnosed'));
    });

    test('blank strings are treated as absent', () {
      final res = OnboardingChatResponse.fromJson({
        'session_id': 'onb_1',
        'done': false,
        'acknowledgment': '   ',
        'question': '',
      });
      expect(res.acknowledgment, isNull);
      expect(res.question, isNull);
    });

    test('an unknown fact category does not break parsing', () {
      final res = OnboardingChatResponse.fromJson({
        'session_id': 'onb_1',
        'done': true,
        'summary': {
          'facts': [
            {
              'category': 'brand_new_category',
              'value': 'v',
              'source_quote': 'q',
            },
          ],
          'narrative': 'n',
        },
      });
      expect(res.summary!.facts.single.category, 'brand_new_category');
    });

    test('a missing summary block is tolerated when done', () {
      final res = OnboardingChatResponse.fromJson({
        'session_id': 'onb_1',
        'done': true,
      });
      expect(res.done, isTrue);
      expect(res.summary, isNull);
    });
  });

  group('request shapes', () {
    test('start posts patient_id and the onboarding object', () async {
      server.script[AppUrls.onboardingChatStart] = (
        200,
        {'session_id': 'onb_1', 'done': false, 'question': 'Q1'},
      );

      await repo.startChat(
        patientId: 'pat_1',
        onboarding: {'symptoms': ['Fatigue']},
      );

      expect(server.last.method, 'POST');
      expect(server.last.path, AppUrls.onboardingChatStart);
      final body = server.bodyOf(AppUrls.onboardingChatStart);
      expect(body['patient_id'], 'pat_1');
      expect(body['onboarding'], {'symptoms': ['Fatigue']});
    });

    test('turn posts session_id and answer', () async {
      server.script[AppUrls.onboardingChatTurn] = (
        200,
        {'session_id': 'onb_1', 'done': false, 'question': 'Q2'},
      );

      await repo.chatTurn(sessionId: 'onb_1', answer: 'I cook rarely');

      expect(server.last.method, 'POST');
      expect(server.last.path, AppUrls.onboardingChatTurn);
      expect(server.bodyOf(AppUrls.onboardingChatTurn), {
        'session_id': 'onb_1',
        'answer': 'I cook rarely',
      });
    });

    test('a 404 on turn surfaces as a DioException for the caller', () async {
      server.script[AppUrls.onboardingChatTurn] = (
        404,
        {'error': {'code': 'not_found', 'message': 'Chat session not found.'}},
      );
      await expectLater(
        repo.chatTurn(sessionId: 'gone', answer: 'hello'),
        throwsA(isA<DioException>()),
      );
    });

    test('turn reuses the session id issued by start', () async {
      server.script[AppUrls.onboardingChatStart] = (
        200,
        {'session_id': 'onb_from_start', 'done': false, 'question': 'Q1'},
      );
      server.script[AppUrls.onboardingChatTurn] = (
        200,
        {'session_id': 'onb_from_start', 'done': true},
      );

      final started = await repo.startChat(patientId: 'p', onboarding: {});
      await repo.chatTurn(sessionId: started.sessionId, answer: 'my answer');

      expect(
        server.bodyOf(AppUrls.onboardingChatTurn)['session_id'],
        'onb_from_start',
      );
    });
  });

  group('buildChatPayload', () {
    final profile = const UserProfile(
      fullName: 'Sarah Johnson',
      dateOfBirth: '1985-06-18',
      gender: 'female',
      primaryDiagnosis: 'masld',
      diagnosedDate: '2026-05-14',
      otherConditions: ['prediabetes'],
      currentMedications: ['metformin'],
      currentSupplements: ['vitamin_d'],
    );

    final draft = const OnboardingDraft(
      motivations: ['recently_diagnosed'],
      supportTypes: ['accountability'],
      activityLevel: 'moderate',
      eatingRhythm: 'three_meals',
      sleepHours: 6,
      dietaryPrefs: ['mediterranean'],
      menstrualCycle: 'regular_cycles',
      symptoms: ['fatigue', 'brain_fog'],
      feeling: Feeling(sleep: 0.3, energy: 0.2, stress: 0.8, mood: 0.5),
    );

    test('splits the name into first and last', () {
      final p = buildChatPayload(profile: profile, draft: draft);
      expect(p['patient']['first_name'], 'Sarah');
      expect(p['patient']['last_name'], 'Johnson');
    });

    test('a single-word name leaves last_name empty', () {
      final p = buildChatPayload(
        profile: const UserProfile(fullName: 'Sarah'),
        draft: draft,
      );
      expect(p['patient']['first_name'], 'Sarah');
      expect(p['patient']['last_name'], '');
    });

    test('enum values are sent as human-readable labels for the AI', () {
      final p = buildChatPayload(profile: profile, draft: draft);
      final clinical = p['clinical_profile'] as Map<String, dynamic>;
      expect(clinical['primary_diagnosis'], 'MASLD');
      expect(clinical['other_conditions'], ['Prediabetes']);
      expect(clinical['supplements'], ['Vitamin D']);
    });

    test('medications are objects with a name, per the API schema', () {
      final p = buildChatPayload(profile: profile, draft: draft);
      expect(p['clinical_profile']['medications'], [
        {'name': 'Metformin'},
      ]);
    });

    test('snake_case draft answers are prettified', () {
      final p = buildChatPayload(profile: profile, draft: draft);
      expect(p['motivation']['reason_for_joining'], ['Recently Diagnosed']);
      expect(p['lifestyle']['activity_level'], 'Moderate');
      expect(p['lifestyle']['eating_pattern'], 'Three Meals');
      expect(p['symptoms'], ['Fatigue', 'Brain Fog']);
    });

    test('0..1 sliders are rescaled to the 0-10 range the API expects', () {
      final p = buildChatPayload(profile: profile, draft: draft);
      expect(p['wellbeing'], {
        'sleep': 3,
        'energy': 2,
        'stress': 8,
        'mood': 5,
      });
    });

    test('women_health is included only for female patients', () {
      final female = buildChatPayload(profile: profile, draft: draft);
      expect(female['women_health'], {'cycle_status': 'Regular Cycles'});

      final male = buildChatPayload(
        profile: const UserProfile(gender: 'male'),
        draft: draft,
      );
      expect(male.containsKey('women_health'), isFalse);
    });

    test('free text typed into an Other box passes through as written', () {
      final p = buildChatPayload(
        profile: const UserProfile(
          currentSupplements: ['other', 'Ashwagandha 500mg'],
        ),
        draft: draft,
      );
      expect(
        p['clinical_profile']['supplements'],
        ['Other', 'Ashwagandha 500mg'],
      );
    });

    test('an empty profile still produces every required section', () {
      final p = buildChatPayload(
        profile: const UserProfile(),
        draft: const OnboardingDraft(),
      );
      expect(p.keys, containsAll(<String>[
        'patient',
        'clinical_profile',
        'motivation',
        'lifestyle',
        'symptoms',
        'wellbeing',
      ]));
    });
  });
}