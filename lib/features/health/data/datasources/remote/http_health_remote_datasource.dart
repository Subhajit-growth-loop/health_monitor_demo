import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/health_record_model.dart';
import 'health_remote_datasource.dart';

/// HTTP implementation of the backend contract, wired to a **dummy endpoint**
/// for now. It performs real network round-trips (so the offline/online sync
/// behaviour is genuine); swap [baseUrl] + the paths for your real API later.
///
/// The default points at a public placeholder API that accepts any JSON and
/// returns 2xx, letting uploads actually succeed over the wire during testing.
class HttpHealthRemoteDataSource implements HealthRemoteDataSource {
  HttpHealthRemoteDataSource({
    http.Client? client,
    this.baseUrl = 'https://jsonplaceholder.typicode.com',
    this.authToken = 'dummy-token',
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// TODO: replace with your real backend base URL.
  final String baseUrl;

  /// TODO: replace with a real bearer token / auth scheme.
  final String authToken;
  final Duration timeout;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };

  @override
  Future<List<String>> uploadBatch(List<HealthRecordModel> records) async {
    if (records.isEmpty) return const [];

    // Real endpoint would be e.g. POST $baseUrl/v1/health-records:batch with an
    // idempotency key. The dummy /posts endpoint accepts any body and 201s.
    final uri = Uri.parse('$baseUrl/posts');
    final body = jsonEncode({
      'records': records.map((r) => r.toJson()).toList(),
    });

    final res = await _client
        .post(uri, headers: _headers, body: body)
        .timeout(timeout);

    // Treat any 2xx as a durable, idempotent write acknowledgement.
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return records.map((r) => r.id).toList();
    }
    throw Exception('Upload failed: HTTP ${res.statusCode}');
  }

  @override
  Future<List<HealthRecordModel>> fetchUpdatesSince(DateTime since) async {
    // Real endpoint: GET $baseUrl/v1/health-records?updatedSince=<iso>.
    final uri = Uri.parse(
        '$baseUrl/posts?updatedSince=${since.toUtc().toIso8601String()}&_limit=0');

    final res = await _client.get(uri, headers: _headers).timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Fetch failed: HTTP ${res.statusCode}');
    }

    // The dummy endpoint's schema doesn't match ours, so there's nothing to
    // merge. A real backend would return records we map with fromJson:
    //   final list = jsonDecode(res.body) as List;
    //   return list.map((j) => HealthRecordModel.fromJson(j)).toList();
    return const [];
  }
}
