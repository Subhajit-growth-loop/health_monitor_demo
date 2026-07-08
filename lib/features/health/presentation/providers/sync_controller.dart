import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../domain/repositories/health_repository.dart';
import 'health_providers.dart';

enum SyncPhase { idle, syncing, error }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.online = true,
    this.pending = 0,
    this.lastSyncedAt,
    this.lastSyncedCount = 0,
    this.message,
  });

  final SyncPhase phase;
  final bool online;
  final int pending;
  final DateTime? lastSyncedAt;
  final int lastSyncedCount;
  final String? message;

  bool get hasPending => pending > 0;

  SyncState copyWith({
    SyncPhase? phase,
    bool? online,
    int? pending,
    DateTime? lastSyncedAt,
    int? lastSyncedCount,
    String? message,
  }) =>
      SyncState(
        phase: phase ?? this.phase,
        online: online ?? this.online,
        pending: pending ?? this.pending,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
        message: message,
      );
}

/// Coordinates *when* synchronization happens (the resilience layer):
/// connectivity changes, periodic interval, and manual/foreground triggers —
/// combined so no single mechanism is a point of failure. Uploads retry with
/// exponential backoff.
class SyncController extends Notifier<SyncState> {
  Timer? _periodic;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<void>? _dbSub;
  bool _running = false;

  HealthRepository get _repo => ref.read(healthRepositoryProvider);
  ConnectivityService get _conn => ref.read(connectivityServiceProvider);

  @override
  SyncState build() {
    // Refresh the pending badge whenever the local DB changes.
    _dbSub = _repo.watchChanges().listen((_) => _refreshPending());

    // Trigger a sync when connectivity is (re)gained.
    _connSub = _conn.onStatusChanged.listen((online) {
      state = state.copyWith(online: online);
      if (online) syncNow();
    });

    // Periodic background sync interval.
    _periodic = Timer.periodic(
      const Duration(seconds: 30),
      (_) => syncNow(),
    );

    ref.onDispose(() {
      _periodic?.cancel();
      _connSub?.cancel();
      _dbSub?.cancel();
    });

    // Kick off initial pending count.
    _refreshPending();
    return SyncState(online: _conn.isOnline);
  }

  Future<void> _refreshPending() async {
    final count = await _repo.pendingCount();
    state = state.copyWith(pending: count, online: _conn.isOnline);
  }

  /// Pull fresh samples from the platform into the local DB (acquisition),
  /// then attempt a sync.
  Future<void> refreshData() async {
    await _repo.refreshFromPlatform();
    await _refreshPending();
    await syncNow();
  }

  /// Upload pending + pull remote, with exponential-backoff retries.
  Future<void> syncNow() async {
    if (_running) return;
    if (!_conn.isOnline) {
      state = state.copyWith(online: false, phase: SyncPhase.idle);
      return;
    }
    _running = true;
    state = state.copyWith(phase: SyncPhase.syncing, online: true);

    const maxAttempts = 4;
    var delay = const Duration(milliseconds: 500);
    try {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final synced = await _repo.synchronize();
          state = state.copyWith(
            phase: SyncPhase.idle,
            lastSyncedCount: synced,
            lastSyncedAt: DateTime.now(),
            message: synced > 0 ? 'Synced $synced records' : 'Up to date',
          );
          await _refreshPending();
          return;
        } catch (e) {
          if (attempt == maxAttempts) {
            state = state.copyWith(
              phase: SyncPhase.error,
              message: 'Sync failed, will retry — ${_short(e)}',
            );
            await _refreshPending();
            return;
          }
          // Exponential backoff before the next attempt.
          await Future<void>.delayed(delay);
          delay *= 2;
        }
      }
    } finally {
      _running = false;
    }
  }

  String _short(Object e) {
    final s = e.toString();
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);
