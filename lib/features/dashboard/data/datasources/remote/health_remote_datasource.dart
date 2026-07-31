import '../../models/health_record_model.dart';

/// The backend API abstraction. The real implementation talks to a REST/gRPC
/// service over TLS; this in-memory version keeps the app runnable end-to-end.
abstract interface class HealthRemoteDataSource {
  /// Idempotent batch ingest. Returns the ids the backend has durably stored
  /// (safe to mark synced locally). Throws on a transport/server failure so
  /// the caller keeps the batch pending and retries with backoff.
  Future<List<String>> uploadBatch(List<HealthRecordModel> records);

  /// Pull records the backend holds that the device does not yet have — data
  /// from the user's other devices, a care provider, or server-side analytics.
  Future<List<HealthRecordModel>> fetchUpdatesSince(DateTime since);
}

/// An in-memory, idempotent mock backend.
class InMemoryHealthRemoteDataSource implements HealthRemoteDataSource {
  final Map<String, HealthRecordModel> _store = {};
  int _uploadAttempts = 0;

  @override
  Future<List<String>> uploadBatch(List<HealthRecordModel> records) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _uploadAttempts++;

    // Simulate a transient failure on the 3rd upload to exercise the retry /
    // exponential-backoff path. The batch stays pending and succeeds later.
    if (_uploadAttempts == 3) {
      throw Exception('Simulated network error (503) — batch will be retried');
    }

    // Idempotent write keyed on the stable id: re-uploading is a no-op.
    for (final r in records) {
      _store[r.id] = r;
    }
    return records.map((r) => r.id).toList();
  }

  @override
  Future<List<HealthRecordModel>> fetchUpdatesSince(DateTime since) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // A real backend would return server-computed values or other-device data
    // here. Nothing extra to merge in this mock.
    return const [];
  }
}
