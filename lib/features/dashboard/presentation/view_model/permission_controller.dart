import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/permission_state.dart';
import 'health_view_model.dart';
import 'sync_controller.dart';

/// Owns the per-data-type permission state and drives the initial acquisition
/// once consent is granted. Re-checks current state rather than assuming it is
/// static (permissions can be revoked from system settings).
class PermissionController extends AsyncNotifier<HealthPermissionState> {
  @override
  Future<HealthPermissionState> build() {
    return ref.read(healthRepositoryProvider).currentPermissions();
  }

  /// Request only the collectible tiers (headline + collect-quiet). Types
  /// marked `collect: false` are never requested, keeping the consent sheet short.
  Future<void> requestAll() => request(HealthMetricType.collectible);

  Future<void> request(List<HealthMetricType> types) async {
    state = const AsyncLoading();
    final repo = ref.read(healthRepositoryProvider);
    final result = await repo.requestPermissions(types);
    state = AsyncData(result);

    if (result.anyGranted) {
      // First acquisition + initial sync.
      await ref.read(syncControllerProvider.notifier).refreshData();
    }
  }
}

final permissionControllerProvider =
    AsyncNotifierProvider<PermissionController, HealthPermissionState>(
        PermissionController.new);
