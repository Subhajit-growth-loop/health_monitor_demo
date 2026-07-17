import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/daily_point.dart';
import '../../../domain/entities/health_metric_type.dart';
import '../../../domain/entities/sync_status.dart';
import '../../models/health_record_model.dart';

/// The on-device database — the single source of truth for the UI.
///
/// In production this table would live in an encrypted SQLite database
/// (e.g. SQLCipher); the schema and access pattern are identical.
class HealthLocalDataSource {
  HealthLocalDataSource(this._db);

  final Database _db;
  static const table = 'health_records';

  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        source TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_type_ts ON $table(type, timestamp)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync ON $table(sync_status)');
  }

  /// Insert new normalized records. Uses INSERT OR IGNORE keyed on the stable
  /// id so duplicates (same type+timestamp+source) are dropped at the storage
  /// boundary. Returns the count actually inserted.
  Future<int> upsertPending(List<HealthRecordModel> records) async {
    if (records.isEmpty) return 0;
    var inserted = 0;
    final batch = _db.batch();
    for (final r in records) {
      batch.insert(table, r.toDb(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final results = await batch.commit();
    for (final res in results) {
      if (res is int && res > 0) inserted++;
    }
    if (inserted > 0) _notify();
    return inserted;
  }

  /// Merge records pulled from the backend. These already carry a synced
  /// status; REPLACE lets server-side computed values overwrite a local copy.
  Future<void> mergeFromRemote(List<HealthRecordModel> records) async {
    if (records.isEmpty) return;
    final batch = _db.batch();
    for (final r in records) {
      batch.insert(table, r.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    _notify();
  }

  Future<List<HealthRecordModel>> recordsForType(
    HealthMetricType type, {
    int limit = 200,
  }) async {
    final rows = await _db.query(
      table,
      where: 'type = ?',
      whereArgs: [type.id],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(HealthRecordModel.fromDb).toList();
  }

  Future<List<HealthRecordModel>> pending({int limit = 500}) async {
    final rows = await _db.query(
      table,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.value],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return rows.map(HealthRecordModel.fromDb).toList();
  }

  Future<int> pendingCount() async {
    final r = await _db.rawQuery(
      'SELECT COUNT(*) c FROM $table WHERE sync_status = ?',
      [SyncStatus.pending.value],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.rawUpdate(
      'UPDATE $table SET sync_status = ? WHERE id IN ($placeholders)',
      [SyncStatus.synced.value, ...ids],
    );
    _notify();
  }

  /// Per-day aggregation computed entirely in SQL so trend charts work with no
  /// network dependency.
  Future<List<DailyPoint>> dailySeries(
    HealthMetricType type, {
    int days = 7,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final rows = await _db.query(
      table,
      where: 'type = ? AND timestamp >= ?',
      whereArgs: [type.id, start.millisecondsSinceEpoch],
    );

    final buckets = <int, List<double>>{};
    for (final row in rows) {
      final ts =
          DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int);
      final key = DateTime(ts.year, ts.month, ts.day).millisecondsSinceEpoch;
      (buckets[key] ??= []).add((row['value'] as num).toDouble());
    }

    return List.generate(days, (i) {
      final day = start.add(Duration(days: i));
      final values = buckets[day.millisecondsSinceEpoch] ?? const [];
      return DailyPoint(day: day, value: _aggregate(type, values));
    });
  }

  Future<Map<HealthMetricType, double>> summaryForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day + 1);
    final rows = await _db.query(
      table,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );

    final grouped = <HealthMetricType, List<double>>{};
    for (final row in rows) {
      final type = HealthMetricType.maybeFromId(row['type'] as String);
      if (type == null) continue;
      (grouped[type] ??= []).add((row['value'] as num).toDouble());
    }

    return {
      for (final type in HealthMetricType.values)
        type: _aggregate(type, grouped[type] ?? const []),
    };
  }

  Future<Map<HealthMetricType, double>> todaySummary() =>
      summaryForDate(DateTime.now());

  Future<List<DailyPoint>> monthlySeries(
    HealthMetricType type, {
    int months = 12,
  }) async {
    final now = DateTime.now();
    var startYear = now.year;
    var startMonth = now.month - months + 1;
    while (startMonth < 1) {
      startYear--;
      startMonth += 12;
    }
    final start = DateTime(startYear, startMonth, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final rows = await _db.query(
      table,
      where: 'type = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [type.id, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );

    final buckets = <int, List<double>>{};
    for (final row in rows) {
      final ts = DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int);
      final key = DateTime(ts.year, ts.month, 1).millisecondsSinceEpoch;
      (buckets[key] ??= []).add((row['value'] as num).toDouble());
    }

    return List.generate(months, (i) {
      var y = startYear;
      var m = startMonth + i;
      while (m > 12) {
        y++;
        m -= 12;
      }
      final monthStart = DateTime(y, m, 1);
      final values = buckets[monthStart.millisecondsSinceEpoch] ?? const [];
      return DailyPoint(day: monthStart, value: _aggregate(type, values));
    });
  }

  double _aggregate(HealthMetricType type, List<double> values) {
    if (values.isEmpty) return 0;
    switch (type.aggregation) {
      case Aggregation.sum:
        return values.fold(0.0, (a, b) => a + b);
      case Aggregation.average:
        return values.reduce((a, b) => a + b) / values.length;
      case Aggregation.latest:
        return values.last;
    }
  }

  Future<void> dispose() => _changes.close();
}
