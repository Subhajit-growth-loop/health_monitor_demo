import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../data/datasources/local/health_local_datasource.dart';
import '../../data/datasources/platform/health_platform_datasource.dart';
import '../../data/datasources/platform/real_health_platform_datasource.dart';
import '../../data/datasources/platform/simulated_health_platform_datasource.dart';
import '../../data/datasources/remote/health_remote_datasource.dart';
import '../../data/datasources/remote/http_health_remote_datasource.dart';
import '../../data/repositories/health_repository_impl.dart';
import '../../domain/repositories/health_repository.dart';

/// Force the simulated data source even on a phone. Set to `true` to run the
/// demo on an iOS simulator / Android emulator (where HealthKit / Health
/// Connect have no data). Leave `false` to read real data on a physical device.
const bool kForceSimulatedHealth = false;

/// Provides the opened SQLite [Database]. Overridden in `main()` once the
/// database is opened asynchronously at startup.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

final localDataSourceProvider = Provider<HealthLocalDataSource>((ref) {
  final db = ref.watch(databaseProvider);
  final source = HealthLocalDataSource(db);
  ref.onDispose(source.dispose);
  return source;
});

final platformDataSourceProvider = Provider<HealthPlatformDataSource>((ref) {
  // Real HealthKit / Health Connect on physical iOS & Android; simulated
  // elsewhere (desktop, web) or when explicitly forced.
  final canUseReal = !kIsWeb &&
      !kForceSimulatedHealth &&
      (Platform.isIOS || Platform.isAndroid);
  return canUseReal
      ? RealHealthPlatformDataSource()
      : SimulatedHealthPlatformDataSource();
});

final remoteDataSourceProvider = Provider<HealthRemoteDataSource>(
  // Dummy HTTP backend for now — real network round-trips against a placeholder
  // endpoint. Swap the baseUrl/paths in HttpHealthRemoteDataSource for the real
  // API later; nothing else changes.
  (ref) => HttpHealthRemoteDataSource(),
);

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepositoryImpl(
    platform: ref.watch(platformDataSourceProvider),
    local: ref.watch(localDataSourceProvider),
    remote: ref.watch(remoteDataSourceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
});

/// Emits whenever the local database (the source of truth) changes, so the
/// read providers below can re-query.
final healthChangesProvider = StreamProvider<void>((ref) {
  return ref.watch(healthRepositoryProvider).watchChanges();
});
