import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local document files that prove a prior install on IO platforms.
const _localDocumentTraceFiles = <String>[
  'nexai_chats.json',
  'nexai_notes.json',
  'nexai_generated_images.json',
];

/// Probe local document files that prove a prior install on IO platforms.
Future<bool> hasLocalDocumentDataTraces() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    // Probe in parallel: one IO round-trip instead of up to three serial ones.
    final results = await Future.wait(
      _localDocumentTraceFiles.map(
        (name) => File('${dir.path}/$name').exists(),
      ),
    );
    return results.contains(true);
  } catch (_) {
    return false;
  }
}
