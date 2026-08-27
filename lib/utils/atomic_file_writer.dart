import 'dart:io';

/// Process-local counter for temp-file names. Combined with the pid and a
/// microsecond timestamp this stays collision-free across concurrent writers
/// without paying for secure-random UUID generation on every save.
int _tempSequence = 0;

Future<void> writeTextAtomically(File file, String payload) {
  return _writeAtomically(file, (target) async {
    await target.writeAsString(payload, flush: true);
  });
}

Future<void> writeBytesAtomically(File file, List<int> payload) {
  return _writeAtomically(file, (target) async {
    await target.writeAsBytes(payload, flush: true);
  });
}

Future<void> _writeAtomically(
  File file,
  Future<void> Function(File target) write,
) async {
  await file.parent.create(recursive: true);
  final tempId =
      '$pid-${DateTime.now().microsecondsSinceEpoch}-${_tempSequence++}';
  final tempFile = File('${file.path}.$tempId.tmp');
  await write(tempFile);

  if (await file.exists()) {
    await file.delete();
  }

  try {
    await tempFile.rename(file.path);
  } catch (_) {
    try {
      await tempFile.delete();
    } catch (_) {
      // Cleanup is best effort; direct write below preserves user data intent.
    }
    await write(file);
  }
}
