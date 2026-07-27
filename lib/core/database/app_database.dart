import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../features/health/data/datasources/local/health_local_datasource.dart';

/// Opens the on-device database. Uses the native SQLite on iOS/Android and the
/// FFI backend on desktop so the same code runs everywhere.
///
/// In production this would be an encrypted database (e.g. SQLCipher); the
/// open call is the only line that changes.
Future<Database> openAppDatabase() async {
  final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  late final DatabaseFactory factory;
  late final String path;

  if (isDesktop) {
    sqfliteFfiInit();
    factory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    path = p.join(dir.path, 'health_monitor.db');
  } else {
    factory = databaseFactory;
    path = p.join(await getDatabasesPath(), 'health_monitor.db');
  }

  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) => HealthLocalDataSource.createSchema(db),
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}
