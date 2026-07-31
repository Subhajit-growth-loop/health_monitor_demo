import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_monitor_demo/app/app_url.dart';
import 'package:health_monitor_demo/features/onboarding/data/datasources/remote/onboarding_api.dart';
import 'package:health_monitor_demo/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:health_monitor_demo/features/onboarding/domain/entities/user_profile.dart';

/// Records every request and replies with [reply], so a test can assert on the
/// exact method, path and body the app puts on the wire.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.reply);

  final Map<String, dynamic> reply;
  final List<RequestOptions> requests = [];

  RequestOptions get last => requests.last;

  /// [RequestOptions.data] keeps whatever the caller passed — a Map here, though
  /// an already-encoded String is just as valid.
  Map<String, dynamic> get lastBody {
    final data = last.data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    return Map<String, dynamic>.from(data as Map);
  }

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
  group('UserProfile.fromJson reads the name off the GET response', () {
    test('snake_case `name` (the /patient/me/details shape)', () {
      final p = UserProfile.fromJson({
        'name': 'William Harry',
        'date_of_birth': '1974-03-14',
        'gender': 'female',
      });
      expect(p.fullName, 'William Harry');
      expect(p.firstName, 'William');
    });

    test('`full_name` variant', () {
      expect(
        UserProfile.fromJson({'full_name': 'Ada Lovelace'}).fullName,
        'Ada Lovelace',
      );
    });

    test('camelCase `fullName` still wins when both are present', () {
      expect(
        UserProfile.fromJson({'fullName': 'Preferred', 'name': 'Other'}).fullName,
        'Preferred',
      );
    });

    test('absent name is empty, not null', () {
      expect(UserProfile.fromJson({'gender': 'female'}).fullName, '');
    });
  });

  group('the verify-info step hits PATCH /patient/me/details', () {
    late _RecordingAdapter adapter;
    late OnboardingRepositoryImpl repo;

    setUp(() {
      adapter = _RecordingAdapter({
        'id': 'pd_1',
        'patient_id': 'usr_1',
        'name': 'Grace Hopper',
        'date_of_birth': '1906-12-09',
        'gender': 'female',
        'primary_diagnosis': 'MASLD',
        'diagnosed_at': '2025-01',
        'other_conditions': <String>[],
        'current_medications': <String>[],
        'current_supplements': <String>[],
      });
      final dio = Dio(BaseOptions(baseUrl: AppUrls.baseUrl))
        ..httpClientAdapter = adapter;
      repo = OnboardingRepositoryImpl(OnboardingApi(dio));
    });

    test('uses the PATCH verb on the details path', () async {
      await repo.savePatientDetails({'name': 'Grace Hopper'});
      expect(adapter.last.method, 'PATCH');
      expect(adapter.last.path, '/patient/me/details');
    });

    test('sends name plus the seven medical fields', () async {
      await repo.savePatientDetails({
        'name': 'Grace Hopper',
        'date_of_birth': '1906-12-09',
        'gender': 'female',
        'primary_diagnosis': 'MASLD',
        'diagnosed_at': '2025-01',
        'other_conditions': <String>[],
        'current_medications': <String>[],
        'current_supplements': <String>[],
      });
      expect(adapter.lastBody['name'], 'Grace Hopper');
      expect(adapter.lastBody.keys, hasLength(8));
    });

    test('returns the profile as the server stored it', () async {
      final saved = await repo.savePatientDetails({'name': 'ignored locally'});
      expect(saved.fullName, 'Grace Hopper');
      expect(saved.primaryDiagnosis, 'MASLD');
    });

    test('GET reads the name back off the same endpoint', () async {
      final loaded = await repo.loadPatientDetails();
      expect(adapter.last.method, 'GET');
      expect(adapter.last.path, '/patient/me/details');
      expect(loaded!.fullName, 'Grace Hopper');
    });
  });
}