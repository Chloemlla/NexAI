import 'dart:io';

/// Process-local counter for temp-file names. Combined with the pid and a
/// microsecond timestamp this stays collision-free across concurrent writers
/// without paying for secure-random UUID generation on every save.
int _tempSequence = 0;

Future<void> writeTextAtomically(File file, String payload) async {
  await file.parent.create(recursive: true);
  final tempId =
      '$pid-${DateTime.now().microsecondsSinceEpoch}-${_tempSequence++}';
  final tempFile = File('${file.path}.$tempId.tmp');
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
      // Cleanup is best effort; direct write below preserves user data intent.
    }
    await file.writeAsString(payload, flush: true);
  }
}
