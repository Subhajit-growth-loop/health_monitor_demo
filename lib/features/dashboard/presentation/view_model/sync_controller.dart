import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/settings/app_settings.dart';
import '../../domain/repositories/health_repository.dart';
import 'health_view_model.dart';

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

/// Coordinates *when* foreground synchronization happens (the resilience layer):
/// connectivity changes, a settings-driven periodic interval, app resume, and
/// manual/foreground triggers — combined so no single mechanism is a point of
/// failure. Uploads retry with exponential backoff.
///
/// The auto-sync toggle + interval here control the FOREGROUND timer only; the
/// background WorkManager tasks are the separate resilience layer and run
/// regardless (see health_background_service.dart).
class SyncController extends Notifier<SyncState> {
  Timer? _periodic;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<void>? _dbSub;
  _LifecycleObserver? _lifecycle;
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

    // Fetch from the platform + sync whenever the app returns to the foreground.
    _lifecycle = _LifecycleObserver(onResume: refreshData);
    WidgetsBinding.instance.addObserver(_lifecycle!);

    // (Re)configure the periodic timer from settings, and react to changes.
    ref.listen(syncSettingsProvider, (_, next) => _configureTimer(next));
    _configureTimer(ref.read(syncSettingsProvider));

    ref.onDispose(() {
      _periodic?.cancel();
      _connSub?.cancel();
      _dbSub?.cancel();
      if (_lifecycle != null) {
        WidgetsBinding.instance.removeObserver(_lifecycle!);
      }
    });

    // Kick off initial pending count.
    _refreshPending();
    return SyncState(online: _conn.isOnline);
  }

  void _configureTimer(SyncSettings settings) {
    _periodic?.cancel();
    if (!settings.autoSync) return;
    _periodic = Timer.periodic(
      Duration(minutes: settings.intervalMinutes),
      (_) => syncNow(),
    );
  }

  Future<void> _refreshPending() async {
    final count = await _repo.pendingCount();
    state = state.copyWith(pending: count, online: _conn.isOnline);
  }

  /// Pull fresh samples from the platform into the local DB (acquisition),
  /// then attempt a sync. Used on app open/resume and manual refresh.
  Future<void> refreshData() async {
    await _repo.refreshFromPlatform();
    await _refreshPending();
    await syncNow();
  }

  /// Catch-up: force a re-read of the trailing [window] (default 48h) from the
  /// platform, then sync. Used by the manual sync page and the 48h flow.
  Future<void> lookBackSync(
      {Duration window = const Duration(hours: 48)}) async {
    await _repo.refreshFromPlatform(lookback: window);
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
          await markSyncSuccess();
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

/// Bridges Flutter app-lifecycle callbacks to the controller so a resume
/// triggers a fresh fetch + sync.
class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver({required this.onResume});
  final Future<void> Function() onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);
