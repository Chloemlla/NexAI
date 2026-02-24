import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

class NotesProvider extends ChangeNotifier {
  List<Note> _notes = [];

  List<Note> get notes => _notes;

  Future<void> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('notes');
    if (data != null && data.isNotEmpty) {
      _notes = Note.decodeList(data);
      // Sort by updatedAt descending
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes', Note.encodeList(_notes));
  }

  Note createNote({String title = '', String content = ''}) {
    final now = DateTime.now();
    final note = Note(
      id: now.millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Untitled Note' : title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    _notes.insert(0, note);
    notifyListeners();
    _save();
    return note;
  }

  void updateNote(String id, {String? title, String? content}) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    if (title != null) _notes[idx].title = title;
    if (content != null) _notes[idx].content = content;
    _notes[idx].updatedAt = DateTime.now();
    notifyListeners();
    _save();
  }

  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
    _save();
  }

  /// Append AI reply content to an existing note
  void appendToNote(String id, String text) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final note = _notes[idx];
    note.content = note.content.isEmpty ? text : '${note.content}\n\n---\n\n$text';
    note.updatedAt = DateTime.now();
    notifyListeners();
    _save();
  }
}
