import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Probe local document files that prove a prior install on IO platforms.
Future<bool> hasLocalDocumentDataTraces() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final chatFile = File('${dir.path}/nexai_chats.json');
    final notesFile = File('${dir.path}/nexai_notes.json');
    return await chatFile.exists() || await notesFile.exists();
  } catch (_) {
    return false;
  }
}
