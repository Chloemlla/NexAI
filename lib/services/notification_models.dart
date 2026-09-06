/// Model types shared by every notification engine and the rendering stack.
library;

/// Notification severity; wire names must match the JS engine's accepted types.
enum NexNotifyType { success, error, warning, info }

/// Immutable payload for [NexNotify.show].
class NexNotifyData {
  const NexNotifyData({
    required this.message,
    this.type = NexNotifyType.info,
    this.title,
    this.details = const <String>[],
    this.duration = const Duration(milliseconds: 3000),
  });

  final String message;
  final NexNotifyType type;
  final String? title;
  final List<String> details;
  final Duration duration;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.name,
        'message': message,
        if (title != null) 'title': title,
        'details': details,
        'duration': duration.inMilliseconds,
      };
}

/// One queued notification as reported by an engine snapshot.
class NexNotification {
  const NexNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.details,
    required this.duration,
    required this.start,
    required this.faded,
    required this.paused,
    required this.remaining,
    this.title,
  });

  final int id;
  final NexNotifyType type;
  final String message;
  final String? title;
  final List<String> details;
  final Duration duration;

  /// Epoch milliseconds when the countdown (re)started.
  final int start;
  final bool faded;

  /// True while a hover / long-press pauses the countdown.
  final bool paused;

  /// Remaining time captured when paused; only meaningful while [paused].
  final Duration remaining;

  factory NexNotification.fromJson(Object? raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    var type = NexNotifyType.info;
    final typeValue = map['type'];
    for (final t in NexNotifyType.values) {
      if (t.name == typeValue) {
        type = t;
        break;
      }
    }
    return NexNotification(
      id: (map['id'] as num?)?.toInt() ?? 0,
      type: type,
      message: map['message'] as String? ?? '',
      title: map['title'] as String?,
      details: map['details'] is List
          ? (map['details'] as List).whereType<String>().toList()
          : const <String>[],
      duration: Duration(
        milliseconds: (map['duration'] as num?)?.toInt() ?? 3000,
      ),
      start: (map['start'] as num?)?.toInt() ?? 0,
      faded: map['faded'] == true,
      paused: map['paused'] == true,
      remaining: Duration(
        milliseconds: (map['remaining'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
