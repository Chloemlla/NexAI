import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

enum ImageGenerationMode {
  chat, // v1/chat/completions
  generation, // v1/images/generations
  edit, // v1/images/edits
}

class GeneratedImage {
  final String url;
  final String? b64Json;
  final String prompt;
  final DateTime timestamp;
  final ImageGenerationMode mode;

  GeneratedImage({
    required this.url,
    this.b64Json,
    required this.prompt,
    required this.timestamp,
    required this.mode,
  });
}

class ImageGenerationProvider extends ChangeNotifier {
  static const int _maxImages = 50;

  final List<GeneratedImage> _images = [];
  bool _isLoading = false;
  String? _error;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 120),
  ));

  List<GeneratedImage> get images => _images;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _addImage(GeneratedImage image) {
    _images.insert(0, image);
    if (_images.length > _maxImages) {
      _images.removeRange(_maxImages, _images.length);
    }
  }

  /// Chat-based image generation (v1/chat/completions)
  /// Supports text-to-image and image-to-image
  /// For Doubao models, supports special parameters: type, n, watermark, size
  Future<void> generateImageViaChat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String prompt,
    String? imageUrl,
    String? imageBase64,
    int imageCount = 1,
    String? imageType,
    bool watermark = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final messages = <Map<String, dynamic>>[];
      
      // Build prompt with Doubao parameters if it's a Doubao model
      String finalPrompt = prompt;
      if (model.contains('doubao') || model.contains('seedream')) {
        final params = <String>[];
        if (imageType != null && imageType.isNotEmpty) {
          params.add('-type=$imageType');
        }
        if (imageCount > 1) {
          params.add('-n=$imageCount');
        }
        params.add('-watermark=$watermark');
        
        if (params.isNotEmpty) {
          finalPrompt = '$prompt ${params.join(' ')}';
        }
      }
      
      if (imageUrl != null || imageBase64 != null) {
        // Image-to-image
        messages.add({
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {
                'url': imageUrl ?? 'data:image/jpeg;base64,$imageBase64',
              },
            },
            {'type': 'text', 'text': finalPrompt},
          ],
        });
      } else {
        // Text-to-image
        messages.add({
          'role': 'user',
          'content': finalPrompt,
        });
      }

      final response = await _dio.post(
        '$baseUrl/chat/completions',
        data: {
          'model': model,
          'messages': messages,
          'stream': false,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final content = data['choices']?[0]?['message']?['content'];
        
        if (content != null) {
          // Extract image URLs from response (support multiple images)
          final urls = <String>[];
          if (content is String) {
            // Try to find all URLs in markdown format or plain text
            final urlPattern = RegExp(r'https?://[^\s\)\]]+');
            final matches = urlPattern.allMatches(content);
            for (final match in matches) {
              final url = match.group(0);
              if (url != null && (url.contains('.jpg') || url.contains('.png') || url.contains('.jpeg') || url.contains('image'))) {
                urls.add(url);
              }
            }
          }

          if (urls.isNotEmpty) {
            for (final url in urls) {
              _addImage(GeneratedImage(
                url: url,
                prompt: prompt,
                timestamp: DateTime.now(),
                mode: ImageGenerationMode.chat,
              ));
            }
            _error = null;
          } else {
            _error = 'No image URL found in response';
          }
        }
      } else {
        _error = 'HTTP ${response.statusCode}';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        try {
          final errorBody = e.response!.data;
          _error = errorBody['error']?['message'] ?? 'HTTP ${e.response!.statusCode}';
        } catch (_) {
          _error = 'HTTP ${e.response!.statusCode}';
        }
      } else {
        _error = e.message ?? 'Connection error';
      }
    } catch (e) {
      _error = 'Error: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Professional image generation (v1/images/generations)
  /// For Doubao models, supports special parameters: type, n, watermark
  Future<void> generateImage({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String prompt,
    String size = '1024x1024',
    String responseFormat = 'url',
    int imageCount = 1,
    String? imageType,
    bool watermark = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final requestData = <String, dynamic>{
        'model': model,
        'prompt': prompt,
        'size': size,
        'response_format': responseFormat,
      };

      // Add Doubao-specific parameters
      if (model.contains('doubao') || model.contains('seedream')) {
        if (imageCount > 1) {
          requestData['n'] = imageCount;
        }
        if (imageType != null && imageType.isNotEmpty) {
          requestData['type'] = imageType;
        }
        requestData['watermark'] = watermark;
      }

      final response = await _dio.post(
        '$baseUrl/images/generations',
        data: requestData,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final imageDataList = data['data'] as List?;
        
        if (imageDataList != null && imageDataList.isNotEmpty) {
          for (final imageData in imageDataList) {
            _addImage(GeneratedImage(
              url: imageData['url'] ?? '',
              b64Json: imageData['b64_json'],
              prompt: prompt,
              timestamp: DateTime.now(),
              mode: ImageGenerationMode.generation,
            ));
          }
          _error = null;
        }
      } else {
        _error = 'HTTP ${response.statusCode}';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        try {
          final errorBody = e.response!.data;
          _error = errorBody['error']?['message'] ?? 'HTTP ${e.response!.statusCode}';
        } catch (_) {
          _error = 'HTTP ${e.response!.statusCode}';
        }
      } else {
        _error = e.message ?? 'Connection error';
      }
    } catch (e) {
      _error = 'Error: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Professional image editing (v1/images/edits)
  Future<void> editImage({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String image,
    required String prompt,
    String size = '1024x1024',
    String responseFormat = 'url',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.post(
        '$baseUrl/images/edits',
        data: {
          'model': model,
          'image': image,
          'prompt': prompt,
          'size': size,
          'response_format': responseFormat,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final imageData = data['data']?[0];
        
        if (imageData != null) {
          _addImage(GeneratedImage(
            url: imageData['url'] ?? '',
            b64Json: imageData['b64_json'],
            prompt: prompt,
            timestamp: DateTime.now(),
            mode: ImageGenerationMode.edit,
          ));
          _error = null;
        }
      } else {
        _error = 'HTTP ${response.statusCode}';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        try {
          final errorBody = e.response!.data;
          _error = errorBody['error']?['message'] ?? 'HTTP ${e.response!.statusCode}';
        } catch (_) {
          _error = 'HTTP ${e.response!.statusCode}';
        }
      } else {
        _error = e.message ?? 'Connection error';
      }
    } catch (e) {
      _error = 'Error: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void deleteImage(int index) {
    if (index >= 0 && index < _images.length) {
      _images.removeAt(index);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
