import 'dart:convert';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/health/domain/repositories/health_repository.dart';

/// Result of building an export — the JSON text plus how many samples it holds.
class HealthExport {
  const HealthExport({required this.json, required this.recordCount});
  final String json;
  final int recordCount;

  /// Encoded size of the JSON payload in bytes (UTF-8).
  int get sizeBytes => utf8.encode(json).length;

  /// Human-readable size, e.g. "1.2 MB" or "834 KB".
  String get sizeLabel {
    final b = sizeBytes;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Builds a JSON snapshot of the device's health data — pulled fresh from
/// HealthKit / Health Connect in the `health` package's own record shape — and
/// either hands it to the native share sheet or writes it to disk.
class HealthExportService {
  const HealthExportService(this._repository);

  final HealthRepository _repository;

  /// Schema version of the export envelope. Bump when the shape changes.
  static const int schemaVersion = 1;

  /// Reads raw platform samples and serializes them into a pretty-printed JSON
  /// string. Each entry in `records` is exactly a `HealthDataPoint.toJson()`
  /// map from the `health` package, wrapped in an export envelope.
  Future<HealthExport> build({
    Duration lookback = const Duration(days: 365),
  }) async {
    final records = await _repository.exportRawPlatformJson(lookback: lookback);
    final now = DateTime.now();

    final payload = <String, Object?>{
      'app': 'health_monitor_demo',
      'schemaVersion': schemaVersion,
      'exportedAt': now.toUtc().toIso8601String(),
      'platform': _platformName(),
      'recordCount': records.length,
      'records': records,
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    return HealthExport(json: json, recordCount: records.length);
  }

  /// Writes the JSON to a temp file and opens the native share sheet so the
  /// user can save it to Files/Downloads, AirDrop it, email it, etc.
  Future<HealthExport> share({
    Duration lookback = const Duration(days: 365),
  }) async {
    final export = await build(lookback: lookback);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_fileName()}');
    await file.writeAsString(export.json);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Health data export',
      ),
    );
    return export;
  }

  /// Opens the native "Save As" picker so the user chooses where to store the
  /// file (Files app on iOS, Storage Access Framework on Android). Returns the
  /// export, or `null` if the user cancelled the picker.
  Future<HealthExport?> save({
    Duration lookback = const Duration(days: 365),
  }) async {
    final export = await build(lookback: lookback);
    final path = await FileSaver.instance.saveAs(
      name: _fileName(withExtension: false),
      bytes: utf8.encode(export.json),
      fileExtension: 'json',
      mimeType: MimeType.json,
    );
    return path == null ? null : export;
  }

  String _fileName({bool withExtension = true}) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final base = 'health_export_$stamp';
    return withExtension ? '$base.json' : base;
  }

  String _platformName() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem;
  }
}