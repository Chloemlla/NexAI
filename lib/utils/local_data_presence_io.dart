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
    for (final name in _localDocumentTraceFiles) {
      if (await File('${dir.path}/$name').exists()) {
        return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}
