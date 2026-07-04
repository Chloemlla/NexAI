import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/crash_report.dart';

class CrashReportStore {
  static const String _fileName = 'crash_report.json';

  Future<void> save(CrashReport report) async {
    final payload = jsonEncode(report.toJson());
    final files = await _files();
    final failures = <Object>[];
    var saved = false;

    for (final file in files) {
      try {
        await _writeAtomically(file, payload);
        saved = true;
      } catch (error) {
        failures.add(error);
      }
    }

    if (!saved) {
      final firstFailure = failures.isEmpty ? null : failures.first;
      throw FileSystemException(
        'Unable to persist crash report.',
        firstFailure?.toString(),
      );
    }
  }

  Future<CrashReport?> load() async {
    final files = await _files();
    for (final file in files) {
      if (!await file.exists()) continue;
      try {
        final data = jsonDecode(await file.readAsString());
        if (data is Map<String, dynamic>) {
          return CrashReport.fromJson(data);
        }
      } catch (_) {
        // Try the next fallback file.
      }
    }
    return null;
  }

  Future<void> clear() async {
    final files = await _files();
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<List<File>> _files() async {
    final dirs = <Directory>[
      await getApplicationSupportDirectory(),
      await getApplicationDocumentsDirectory(),
      await getTemporaryDirectory(),
    ];
    return dirs.map((dir) => File('${dir.path}/$_fileName')).toList();
  }

  Future<void> _writeAtomically(File file, String payload) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(payload, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    try {
      await tempFile.rename(file.path);
    } catch (_) {
      try {
        await tempFile.delete();
      } catch (_) {
        // Ignore cleanup failure; direct write below is the fallback.
      }
      await file.writeAsString(payload, flush: true);
    }
  }
}
