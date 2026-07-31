import 'health_metric_type.dart';

/// Per-data-type permission outcome. Users may grant some types and deny
/// others, so the app degrades gracefully per metric rather than failing
/// wholesale.
enum PermissionGrant { granted, denied, notRequested }

class HealthPermissionState {
  const HealthPermissionState({required this.grants});

  final Map<HealthMetricType, PermissionGrant> grants;

  bool isGranted(HealthMetricType type) =>
      grants[type] == PermissionGrant.granted;

  bool get anyGranted =>
      grants.values.any((g) => g == PermissionGrant.granted);

  static HealthPermissionState allNotRequested() => HealthPermissionState(
        grants: {
          for (final t in HealthMetricType.values) t: PermissionGrant.notRequested,
        },
      );
}
