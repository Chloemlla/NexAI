import 'package:intl/intl.dart';

class CrashBreadcrumbs {
  static const int _maxEvents = 40;
  static final List<String> _events = <String>[];
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss.SSS');

  CrashBreadcrumbs._();

  static void record(String event) {
    final sanitized = _sanitize(event).trim();
    if (sanitized.isEmpty) return;
    if (_events.length >= _maxEvents) {
      _events.removeAt(0);
    }
    final clipped = sanitized.length > 180
        ? sanitized.substring(0, 180)
        : sanitized;
    _events.add('${_timeFormat.format(DateTime.now())}  $clipped');
  }

  static List<String> snapshot() => List.unmodifiable(_events);

  static String _sanitize(String value) {
    return value
        .replaceAll(RegExp(r'[A-Za-z]:\\Users\\[^\\\s]+'), '[user-home]')
        .replaceAll(RegExp(r'/home/[^/\s]+'), '[user-home]')
        .replaceAll(RegExp(r'/Users/[^/\s]+'), '[user-home]')
        .replaceAll(RegExp(r'content://[^\s]+'), '[content-uri]')
        .replaceAll(RegExp(r'file://[^\s]+'), '[file-uri]');
  }
}
