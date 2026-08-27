import 'dart:convert';

import 'message.dart' show asStringMap;

/// Regex to extract #tags (including nested like #category/subcategory)
/// Avoids matching inside code blocks or frontmatter
final tagPattern = RegExp(
  r'(?<!\w)#([\w\u4e00-\u9fff][\w\u4e00-\u9fff/]*)(?!\w)',
);

/// Regex to extract wiki-links: [[note]], [[note|alias]], [[note#heading]], [[note#^blockId]]
final wikiLinkPattern = RegExp(r'\[\[([^\]]+)\]\]');

/// Regex to extract YAML frontmatter
final frontmatterPattern = RegExp(r'^---\s*\n([\s\S]*?)\n---', multiLine: true);

final _codeBlockPattern = RegExp(r'```[\s\S]*?```');

class Note {
  final String id;
  String title;
  String content;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? lastViewedAt;
  bool isStarred;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.lastViewedAt,
    this.isStarred = false,
  });

  // Derived values (frontmatter / body / tags / wiki-links) are parsed together
  // and memoized against the content instance they came from; `content` is
  // reassigned on every edit, so an identity check is enough to invalidate.
  String? _derivedFrom;
  Map<String, String> _frontmatterCache = const {};
  String _bodyCache = '';
  List<String> _tagsCache = const [];
  List<WikiLink> _wikiLinksCache = const [];

  void _ensureDerived() {
    final source = content;
    if (identical(_derivedFrom, source)) return;

    final fmMatch = frontmatterPattern.firstMatch(source);
    final fm = <String, String>{};
    if (fmMatch != null) {
      for (final line in fmMatch.group(1)!.split('\n')) {
        final idx = line.indexOf(':');
        if (idx > 0) {
          fm[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
        }
      }
    }

    final body = fmMatch == null
        ? source
        : source.substring(fmMatch.end).trimLeft();
    // Skip code blocks so fenced samples don't produce tags or links.
    final noCode = body.replaceAll(_codeBlockPattern, '');

    final tags = <String>{};
    final fmTags = fm['tags'];
    if (fmTags != null) {
      for (final m in tagPattern.allMatches(fmTags)) {
        tags.add(m.group(1)!);
      }
    }
    for (final m in tagPattern.allMatches(noCode)) {
      tags.add(m.group(1)!);
    }

    final links = <WikiLink>[];
    for (final m in wikiLinkPattern.allMatches(noCode)) {
      links.add(WikiLink.parse(m.group(1)!));
    }

    _frontmatterCache = fm;
    _bodyCache = body;
    _tagsCache = tags.toList()..sort();
    _wikiLinksCache = links;
    _derivedFrom = source;
  }

  /// Extract all tags from content (both body #tags and frontmatter tags)
  List<String> get tags {
    _ensureDerived();
    return _tagsCache;
  }

  /// Parse frontmatter as simple key-value map
  Map<String, String> get frontmatter {
    _ensureDerived();
    return _frontmatterCache;
  }

  /// Content without frontmatter
  String get bodyContent {
    _ensureDerived();
    return _bodyCache;
  }

  /// Extract all wiki-links from content
  List<WikiLink> get wikiLinks {
    _ensureDerived();
    return _wikiLinksCache;
  }

  /// Just the target note names from wiki-links (deduplicated)
  Set<String> get linkedNoteNames {
    return wikiLinks.map((l) => l.target.toLowerCase()).toSet();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastViewedAt': lastViewedAt?.toIso8601String(),
    'isStarred': isStarred,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: _stringValue(json, 'id'),
    title: _stringValue(json, 'title'),
    content: _stringValue(json, 'content'),
    createdAt: _dateTimeValue(json, 'createdAt'),
    updatedAt: _dateTimeValue(json, 'updatedAt'),
    lastViewedAt: json['lastViewedAt'] != null
        ? _dateTimeValue(json, 'lastViewedAt')
        : null,
    isStarred: json['isStarred'] as bool? ?? false,
  );

  static String encodeList(List<Note> notes) =>
      jsonEncode(notes.map((n) => n.toJson()).toList());

  static List<Note> decodeList(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! List) {
      throw const FormatException('Expected notes JSON array');
    }
    return decoded.map((e) => Note.fromJson(asStringMap(e, 'note'))).toList();
  }
}

String _stringValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a string');
}

DateTime _dateTimeValue(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse(_stringValue(json, key));
  if (parsed != null) return parsed;
  throw FormatException('Expected "$key" to be an ISO-8601 timestamp');
}

/// Parsed wiki-link: [[target]], [[target|alias]], [[target#heading]], [[target#^blockId]]
class WikiLink {
  final String target; // note name
  final String? alias; // display text (after |)
  final String? heading; // heading anchor (after #, not starting with ^)
  final String? blockId; // block id (after #^)

  WikiLink({required this.target, this.alias, this.heading, this.blockId});

  /// Parse raw content inside [[ ]]
  factory WikiLink.parse(String raw) {
    String? alias;
    String remainder = raw;

    // Split alias: [[target|alias]]
    final pipeIdx = remainder.indexOf('|');
    if (pipeIdx != -1) {
      alias = remainder.substring(pipeIdx + 1).trim();
      remainder = remainder.substring(0, pipeIdx).trim();
    }

    // Split heading/block: [[target#heading]] or [[target#^blockId]]
    String? heading;
    String? blockId;
    final hashIdx = remainder.indexOf('#');
    if (hashIdx != -1) {
      final anchor = remainder.substring(hashIdx + 1).trim();
      remainder = remainder.substring(0, hashIdx).trim();
      if (anchor.startsWith('^')) {
        blockId = anchor.substring(1);
      } else {
        heading = anchor;
      }
    }

    return WikiLink(
      target: remainder,
      alias: alias,
      heading: heading,
      blockId: blockId,
    );
  }

  /// Display text for rendering
  String get displayText => alias ?? target;
}
