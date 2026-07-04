import 'dart:io';

Future<void> writeTextAtomically(File file, String payload) async {
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
      // Cleanup is best effort; direct write below preserves user data intent.
    }
    await file.writeAsString(payload, flush: true);
  }
}
