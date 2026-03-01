import 'dart:convert';

/// Regex to extract #tags (including nested like #category/subcategory)
/// Avoids matching inside code blocks or frontmatter
final tagPattern = RegExp(
  r'(?<!\w)#([\w\u4e00-\u9fff][\w\u4e00-\u9fff/]*)(?!\w)',
);

/// Regex to extract wiki-links: [[note]], [[note|alias]], [[note#heading]], [[note#^blockId]]
final wikiLinkPattern = RegExp(r'\[\[([^\]]+)\]\]');

/// Regex to extract YAML frontmatter
final frontmatterPattern = RegExp(r'^---\s*\n([\s\S]*?)\n---', multiLine: true);

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

  /// Extract all tags from content (both body #tags and frontmatter tags)
  List<String> get tags {
    final result = <String>{};
    // Extract from frontmatter
    final fm = frontmatter;
    if (fm.containsKey('tags')) {
      final fmTags = fm['tags'];
      if (fmTags is String) {
        for (final m in tagPattern.allMatches(fmTags)) {
          result.add(m.group(1)!);
        }
      }
    }
    // Extract from body (skip frontmatter and code blocks)
    final body = bodyContent;
    // Remove code blocks before scanning
    final noCode = body.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    for (final m in tagPattern.allMatches(noCode)) {
      result.add(m.group(1)!);
    }
    return result.toList()..sort();
  }

  /// Parse frontmatter as simple key-value map
  Map<String, String> get frontmatter {
    final match = frontmatterPattern.firstMatch(content);
    if (match == null) return {};
    final yaml = match.group(1)!;
    final map = <String, String>{};
    for (final line in yaml.split('\n')) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        final key = line.substring(0, idx).trim();
        final value = line.substring(idx + 1).trim();
        map[key] = value;
      }
    }
    return map;
  }

  /// Content without frontmatter
  String get bodyContent {
    final match = frontmatterPattern.firstMatch(content);
    if (match == null) return content;
    return content.substring(match.end).trimLeft();
  }

  /// Extract all wiki-links from content
  List<WikiLink> get wikiLinks {
    final result = <WikiLink>[];
    final body = bodyContent;
    final noCode = body.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    for (final m in wikiLinkPattern.allMatches(noCode)) {
      final raw = m.group(1)!;
      result.add(WikiLink.parse(raw));
    }
    return result;
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
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    lastViewedAt: json['lastViewedAt'] != null
        ? DateTime.parse(json['lastViewedAt'] as String)
        : null,
    isStarred: json['isStarred'] as bool? ?? false,
  );

  static String encodeList(List<Note> notes) =>
      jsonEncode(notes.map((n) => n.toJson()).toList());

  static List<Note> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
  }
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
