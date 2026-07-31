import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/background/alert_thresholds.dart';
import '../../domain/entities/health_metric_type.dart';
import '../../domain/repositories/health_repository.dart';
import 'health_view_model.dart';

/// Watches the local DB for changes and re-checks thresholds in real-time
/// while the app is in the foreground. Shows in-app banners (not OS
/// notifications) so the user isn't double-notified.
class ForegroundAlertNotifier extends Notifier<List<AlertViolation>> {
  StreamSubscription<void>? _sub;

  HealthRepository get _repo => ref.read(healthRepositoryProvider);

  @override
  List<AlertViolation> build() {
    _sub = _repo.watchChanges().listen((_) => _check());
    ref.onDispose(() => _sub?.cancel());
    _check();
    return const [];
  }

  Future<void> _check() async {
    final summary = await _repo.todaySummary();
    state = AlertThresholds.check(summary);
  }

  void dismiss(HealthMetricType type) {
    state = state.where((v) => v.type != type).toList();
  }
}

final foregroundAlertProvider =
    NotifierProvider<ForegroundAlertNotifier, List<AlertViolation>>(
  ForegroundAlertNotifier.new,
);
