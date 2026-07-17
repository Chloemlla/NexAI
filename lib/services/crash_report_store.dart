import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/crash_report.dart';

class CrashReportStore {
  static const String _dirName = 'lumen-crash';
  static const String _fileName = 'crash_report.json';

  Future<void> save(CrashReport report) async {
    final payload = jsonEncode(report.toJson());
    final files = await _preferredFiles();
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

    // Avoid leaving stale root-level copies after a successful write.
    await _clearLegacyRootCopies();
  }

  Future<CrashReport?> load() async {
    // Prefer dedicated crash-dir locations first, then migrate legacy root files.
    for (final file in await _preferredFiles()) {
      final report = await _readReport(file);
      if (report != null) return report;
    }

    for (final file in await _legacyRootFiles()) {
      final report = await _readReport(file);
      if (report == null) continue;
      try {
        await save(report);
      } catch (_) {
        // Best effort migration; still return the loaded report.
      }
      return report;
    }
    return null;
  }

  Future<CrashReport?> _readReport(File file) async {
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is Map<String, dynamic>) {
        return CrashReport.fromJson(data);
      }
      if (data is Map) {
        return CrashReport.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> clear() async {
    final files = <File>[
      ...await _preferredFiles(),
      ...await _legacyRootFiles(),
    ];
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
      final parent = file.parent;
      if (parent.path.endsWith(_dirName) && await parent.exists()) {
        try {
          final remaining = await parent.list().isEmpty;
          if (remaining) {
            await parent.delete();
          }
        } catch (_) {
          // Ignore directory cleanup failures.
        }
      }
    }
  }

  Future<void> _clearLegacyRootCopies() async {
    for (final file in await _legacyRootFiles()) {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Ignore cleanup failures.
        }
      }
    }
  }

  Future<List<File>> _preferredFiles() async {
    final dirs = await _candidateDirs();
    return dirs
        .map((dir) => File('${dir.path}/$_dirName/$_fileName'))
        .toList(growable: false);
  }

  Future<List<File>> _legacyRootFiles() async {
    final dirs = await _candidateDirs();
    return dirs
        .map((dir) => File('${dir.path}/$_fileName'))
        .toList(growable: false);
  }

  Future<List<Directory>> _candidateDirs() async {
    final dirs = <Directory>[];
    Future<void> add(Future<Directory> Function() getter) async {
      try {
        dirs.add(await getter());
      } catch (_) {
        // Skip unavailable storage roots.
      }
    }

    await add(getApplicationSupportDirectory);
    await add(getApplicationDocumentsDirectory);
    await add(getTemporaryDirectory);
    return dirs;
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
