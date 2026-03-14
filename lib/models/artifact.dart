/// Artifact data models for NexAI sharing feature
class Artifact {
  final String id;
  final String shortId;
  final String title;
  final String contentType; // html, code, markdown, mermaid
  final String? language;
  final String content;
  final String? description;
  final List<String> tags;
  final String visibility; // public, private, password
  final int viewCount;
  final DateTime createdAt;
  final DateTime? expiresAt;

  Artifact({
    required this.id,
    required this.shortId,
    required this.title,
    required this.contentType,
    this.language,
    required this.content,
    this.description,
    required this.tags,
    required this.visibility,
    required this.viewCount,
    required this.createdAt,
    this.expiresAt,
  });

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['_id'] ?? json['id'],
      shortId: json['shortId'],
      title: json['title'],
      contentType: json['contentType'],
      language: json['language'],
      content: json['content'],
      description: json['description'],
      tags: List<String>.from(json['tags'] ?? []),
      visibility: json['visibility'],
      viewCount: json['viewCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
    );
  }
}

class ArtifactCreateResponse {
  final String id;
  final String shortId;
  final String shareUrl;
  final String embedUrl;
  final DateTime createdAt;
  final DateTime? expiresAt;

  ArtifactCreateResponse({
    required this.id,
    required this.shortId,
    required this.shareUrl,
    required this.embedUrl,
    required this.createdAt,
    this.expiresAt,
  });

  factory ArtifactCreateResponse.fromJson(Map<String, dynamic> json) {
    return ArtifactCreateResponse(
      id: json['id'],
      shortId: json['shortId'],
      shareUrl: json['shareUrl'],
      embedUrl: json['embedUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
    );
  }
}

class ArtifactSummary {
  final String id;
  final String shortId;
  final String title;
  final String contentType;
  final String visibility;
  final int viewCount;
  final DateTime createdAt;

  ArtifactSummary({
    required this.id,
    required this.shortId,
    required this.title,
    required this.contentType,
    required this.visibility,
    required this.viewCount,
    required this.createdAt,
  });

  factory ArtifactSummary.fromJson(Map<String, dynamic> json) {
    return ArtifactSummary(
      id: json['_id'] ?? json['id'],
      shortId: json['shortId'],
      title: json['title'],
      contentType: json['contentType'],
      visibility: json['visibility'],
      viewCount: json['viewCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class Pagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'],
      limit: json['limit'],
      total: json['total'],
      totalPages: json['totalPages'],
    );
  }
}

class ArtifactListResponse {
  final List<ArtifactSummary> artifacts;
  final Pagination pagination;

  ArtifactListResponse({
    required this.artifacts,
    required this.pagination,
  });

  factory ArtifactListResponse.fromJson(Map<String, dynamic> json) {
    return ArtifactListResponse(
      artifacts: (json['artifacts'] as List)
          .map((e) => ArtifactSummary.fromJson(e))
          .toList(),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}

// Custom exceptions
class PasswordRequiredException implements Exception {}
class InvalidPasswordException implements Exception {}
class ArtifactNotFoundException implements Exception {}
