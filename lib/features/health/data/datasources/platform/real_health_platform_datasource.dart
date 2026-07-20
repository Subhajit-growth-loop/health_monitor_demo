import 'dart:io';

import 'package:health/health.dart';

import '../../../domain/entities/health_metric_type.dart';
import '../../../domain/entities/health_record.dart';
import '../../../domain/entities/permission_state.dart';
import '../../../domain/entities/sync_status.dart';
import '../../models/health_record_model.dart';
import 'health_platform_datasource.dart';

/// Real implementation of the Unified Access Layer, backed by the `health`
/// package which wraps **Apple HealthKit** (iOS) and **Google Health Connect**
/// (Android) behind one API. Raw samples are normalized here into the app's
/// common [HealthRecordModel] schema, so nothing above the data layer changes.
///
/// Only works on physical devices — HealthKit is unavailable on the iOS
/// simulator, and Health Connect requires a real Android device.
class RealHealthPlatformDataSource implements HealthPlatformDataSource {
  RealHealthPlatformDataSource();

  final Health _health = Health();
  bool _configured = false;

  /// Last-known grants. Needed because Apple deliberately hides read-permission
  /// status, so [currentPermissions] cannot always re-derive it from the OS.
  HealthPermissionState _state = HealthPermissionState.allNotRequested();

  @override
  String get providerName =>
      Platform.isIOS ? 'Apple HealthKit' : 'Health Connect';

  /// Maps our internal metric to the platform data type(s) to read.
  List<HealthDataType> _dataTypes(HealthMetricType type) => switch (type) {
        // Vitals
        HealthMetricType.heartRate => [HealthDataType.HEART_RATE],
        HealthMetricType.restingHeartRate => [HealthDataType.RESTING_HEART_RATE],
        HealthMetricType.bloodOxygen => [HealthDataType.BLOOD_OXYGEN],
        HealthMetricType.respiratoryRate => [HealthDataType.RESPIRATORY_RATE],
        HealthMetricType.bloodPressureSystolic =>
          [HealthDataType.BLOOD_PRESSURE_SYSTOLIC],
        HealthMetricType.bloodPressureDiastolic =>
          [HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
        HealthMetricType.bodyTemperature => [HealthDataType.BODY_TEMPERATURE],
        HealthMetricType.bloodGlucose => [HealthDataType.BLOOD_GLUCOSE],
        // Activity
        HealthMetricType.steps => [HealthDataType.STEPS],
        HealthMetricType.activeEnergy => [HealthDataType.ACTIVE_ENERGY_BURNED],
        HealthMetricType.basalEnergy => [HealthDataType.BASAL_ENERGY_BURNED],
        HealthMetricType.totalCalories => [HealthDataType.TOTAL_CALORIES_BURNED],
        HealthMetricType.flightsClimbed => [HealthDataType.FLIGHTS_CLIMBED],
        // Body
        HealthMetricType.weight => [HealthDataType.WEIGHT],
        HealthMetricType.height => [HealthDataType.HEIGHT],
        HealthMetricType.bmi => [HealthDataType.BODY_MASS_INDEX],
        HealthMetricType.bodyFat => [HealthDataType.BODY_FAT_PERCENTAGE],
        HealthMetricType.leanBodyMass => [HealthDataType.LEAN_BODY_MASS],
        // Sleep — Health Connect devices write SLEEP_SESSION (total duration);
        // HealthKit has no SLEEP_SESSION, so SLEEP_ASLEEP is the total there.
        // The stages (deep/light/rem/awake) exist on both platforms.
        HealthMetricType.sleep => Platform.isAndroid
            ? [HealthDataType.SLEEP_SESSION]
            : [HealthDataType.SLEEP_ASLEEP],
        HealthMetricType.sleepDeep => [HealthDataType.SLEEP_DEEP],
        HealthMetricType.sleepLight => [HealthDataType.SLEEP_LIGHT],
        HealthMetricType.sleepRem => [HealthDataType.SLEEP_REM],
        HealthMetricType.sleepAwake => [HealthDataType.SLEEP_AWAKE],
        // Wellness
        HealthMetricType.water => [HealthDataType.WATER],
        HealthMetricType.menstruationFlow => [HealthDataType.MENSTRUATION_FLOW],
      };

  /// Sleep-stage metrics are all stored by the platform as durations (minutes).
  static const _sleepMetrics = {
    HealthMetricType.sleep,
    HealthMetricType.sleepDeep,
    HealthMetricType.sleepLight,
    HealthMetricType.sleepRem,
    HealthMetricType.sleepAwake,
  };

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<HealthPermissionState> requestPermissions(
      List<HealthMetricType> types) async {
    await _ensureConfigured();

    // On Android, Health Connect must be present. Guide the user to install it
    // rather than failing silently (design doc §10.5).
    if (Platform.isAndroid) {
      final status = await _health.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        await _health.installHealthConnect();
        return _state; // still not granted; user must finish install
      }
    }

    final dataTypes = types.expand(_dataTypes).toList();
    final access =
        List.filled(dataTypes.length, HealthDataAccess.READ);

    bool granted = false;
    try {
      granted = await _health.requestAuthorization(dataTypes,
          permissions: access);
    } catch (_) {
      granted = false;
    }

    _state = HealthPermissionState(grants: {
      for (final t in HealthMetricType.values)
        t: types.contains(t)
            ? (granted ? PermissionGrant.granted : PermissionGrant.denied)
            : (_state.grants[t] ?? PermissionGrant.notRequested),
    });
    return _state;
  }

  @override
  Future<HealthPermissionState> currentPermissions() async {
    await _ensureConfigured();

    // Android (Health Connect) reports read-permission status; iOS does not, so
    // there we fall back to the last-known state.
    final grants = <HealthMetricType, PermissionGrant>{};
    for (final t in HealthMetricType.values) {
      bool? has;
      try {
        has = await _health.hasPermissions(_dataTypes(t),
            permissions: [HealthDataAccess.READ]);
      } catch (_) {
        has = null;
      }
      grants[t] = switch (has) {
        true => PermissionGrant.granted,
        false when Platform.isAndroid => PermissionGrant.denied,
        _ => _state.grants[t] ?? PermissionGrant.notRequested,
      };
    }
    _state = HealthPermissionState(grants: grants);
    return _state;
  }

  @override
  Future<List<HealthRecordModel>> fetchSamplesSince(
    DateTime since,
    List<HealthMetricType> grantedTypes,
  ) async {
    await _ensureConfigured();
    if (grantedTypes.isEmpty) return const [];

    final now = DateTime.now();
    final out = <HealthRecordModel>[];

    for (final metric in grantedTypes) {
      List<HealthDataPoint> points;
      try {
        points = await _health.getHealthDataFromTypes(
          types: _dataTypes(metric),
          startTime: since,
          endTime: now,
        );
      } catch (_) {
        continue; // degrade gracefully per metric
      }

      for (final p in points) {
        final value = _numericValue(p);
        if (value == null) continue;
        final converted = _convert(metric, value);
        // Sleep sessions start the previous night; use dateTo (wake time) so the
        // record is attributed to the day the user woke up, not when they fell asleep.
        final ts = _sleepMetrics.contains(metric) ? p.dateTo : p.dateFrom;
        final source = p.sourceName.isEmpty ? providerName : p.sourceName;
        out.add(HealthRecordModel(
          id: HealthRecord.buildId(
              type: metric, timestamp: ts, source: source),
          type: metric,
          value: converted,
          unit: metric.unit,
          source: source,
          timestamp: ts,
          syncStatus: SyncStatus.pending,
        ));
      }
    }
    return out;
  }

  double? _numericValue(HealthDataPoint p) {
    final v = p.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return null;
  }

  /// Unit normalization into the app's common schema.
  double _convert(HealthMetricType metric, double raw) {
    switch (metric) {
      // Sleep durations come back in minutes; the app displays hours.
      case HealthMetricType.sleep:
      case HealthMetricType.sleepDeep:
      case HealthMetricType.sleepLight:
      case HealthMetricType.sleepRem:
      case HealthMetricType.sleepAwake:
        return raw / 60.0;
      // Fractions (0–1 on HealthKit) → percentages; Health Connect already %.
      case HealthMetricType.bloodOxygen:
      case HealthMetricType.bodyFat:
        return raw <= 1.0 ? raw * 100.0 : raw;
      // HealthKit reports glucose in mmol/L; Health Connect in mg/dL.
      case HealthMetricType.bloodGlucose:
        return Platform.isIOS ? raw * 18.0182 : raw;
      // Height comes back in metres on both platforms; the app displays cm.
      // Guard against values already in cm so simulated data isn't double-scaled.
      case HealthMetricType.height:
        return raw < 3.0 ? raw * 100.0 : raw;
      // Everything else is already in the display unit.
      default:
        return raw;
    }
  }
}
