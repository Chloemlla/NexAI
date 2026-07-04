import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/utils/atomic_file_writer.dart';

void main() {
  test('writeTextAtomically writes the complete payload', () async {
    final dir = await Directory.systemTemp.createTemp('nexai_atomic_test_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final file = File('${dir.path}/store.json');
    await writeTextAtomically(file, '{"version":1}');
    await writeTextAtomically(file, '{"version":2}');

    expect(await file.readAsString(), '{"version":2}');
    expect(await File('${file.path}.tmp').exists(), isFalse);
  });
}
