// Verifies the HTTP remote data source builds correct requests and handles
// responses, using a mocked http.Client (no live network).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:health_monitor_demo/features/dashboard/data/datasources/remote/http_health_remote_datasource.dart';
import 'package:health_monitor_demo/features/dashboard/data/models/health_record_model.dart';
import 'package:health_monitor_demo/features/dashboard/domain/entities/health_metric_type.dart';
import 'package:health_monitor_demo/features/dashboard/domain/entities/sync_status.dart';

HealthRecordModel _sample(String id) => HealthRecordModel(
      id: id,
      type: HealthMetricType.steps,
      value: 100,
      unit: 'steps',
      source: 'Test',
      timestamp: DateTime(2026, 7, 8, 10),
      syncStatus: SyncStatus.pending,
    );

void main() {
  test('uploadBatch posts JSON and returns ids on 2xx', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response('{"ok":true}', 201);
    });
    final remote = HttpHealthRemoteDataSource(client: client);

    final ids = await remote.uploadBatch([_sample('a'), _sample('b')]);

    expect(ids, ['a', 'b']);
    expect(captured.method, 'POST');
    expect(captured.headers['Authorization'], startsWith('Bearer '));
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect((body['records'] as List).length, 2);
  });

  test('uploadBatch throws on a server error (kept pending for retry)',
      () async {
    final client = MockClient((req) async => http.Response('err', 503));
    final remote = HttpHealthRemoteDataSource(client: client);

    expect(() => remote.uploadBatch([_sample('a')]), throwsException);
  });

  test('empty batch is a no-op', () async {
    final client = MockClient((req) async => http.Response('', 500));
    final remote = HttpHealthRemoteDataSource(client: client);
    expect(await remote.uploadBatch([]), isEmpty);
  });
}
