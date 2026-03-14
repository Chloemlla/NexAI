/// NexAI Artifacts State Provider
/// Manages artifacts sharing state and operations
import 'package:flutter/foundation.dart';
import '../services/nexai_artifacts_service.dart';
import '../models/artifact.dart';

class ArtifactsProvider extends ChangeNotifier {
  List<ArtifactSummary> _artifacts = [];
  Pagination? _pagination;
  bool _isLoading = false;
  String? _error;
  Artifact? _currentArtifact;

  // Getters
  List<ArtifactSummary> get artifacts => _artifacts;
  Pagination? get pagination => _pagination;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Artifact? get currentArtifact => _currentArtifact;

  /// Create a new artifact
  Future<ArtifactCreateResponse?> createArtifact({
    required String accessToken,
    required String title,
    required String contentType,
    required String content,
    String? language,
    String visibility = 'public',
    String? password,
    String? description,
    List<String>? tags,
    int? expiresInDays,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await NexaiArtifactsApi.createArtifact(
        accessToken: accessToken,
        title: title,
        contentType: contentType,
        content: content,
        language: language,
        visibility: visibility,
        password: password,
        description: description,
        tags: tags,
        expiresInDays: expiresInDays,
      );

      // Refresh list after creation
      await loadArtifacts(accessToken: accessToken);

      return response;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load artifacts list
  Future<void> loadArtifacts({
    required String accessToken,
    int page = 1,
    int limit = 20,
    String sort = 'createdAt',
    String order = 'desc',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await NexaiArtifactsApi.listArtifacts(
        accessToken: accessToken,
        page: page,
        limit: limit,
        sort: sort,
        order: order,
      );

      _artifacts = response.artifacts;
      _pagination = response.pagination;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get artifact by short ID
  Future<Artifact?> getArtifact(
    String shortId, {
    String? password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final artifact = await NexaiArtifactsApi.getArtifact(
        shortId,
        password: password,
      );

      _currentArtifact = artifact;

      // Record view
      await NexaiArtifactsApi.recordView(shortId);

      return artifact;
    } on PasswordRequiredException {
      _error = 'password_required';
      return null;
    } on InvalidPasswordException {
      _error = 'invalid_password';
      return null;
    } on ArtifactNotFoundException {
      _error = 'not_found';
      return null;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update artifact
  Future<bool> updateArtifact(
    String shortId, {
    required String accessToken,
    String? title,
    String? visibility,
    String? password,
    String? description,
    List<String>? tags,
    int? expiresInDays,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await NexaiArtifactsApi.updateArtifact(
        shortId,
        accessToken: accessToken,
        title: title,
        visibility: visibility,
        password: password,
        description: description,
        tags: tags,
        expiresInDays: expiresInDays,
      );

      // Refresh list after update
      await loadArtifacts(accessToken: accessToken);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete artifact
  Future<bool> deleteArtifact(
    String shortId, {
    required String accessToken,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await NexaiArtifactsApi.deleteArtifact(
        shortId,
        accessToken: accessToken,
      );

      // Remove from local list
      _artifacts.removeWhere((a) => a.shortId == shortId);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear current artifact
  void clearCurrentArtifact() {
    _currentArtifact = null;
    notifyListeners();
  }
}
