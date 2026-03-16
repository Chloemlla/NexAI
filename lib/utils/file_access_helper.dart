import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

/// 统一的文件访问助手，使用 SAF (Storage Access Framework) 实现细粒度权限控制
class FileAccessHelper {
  /// 选择单个视频文件
  ///
  /// 在 Android 上使用 SAF，只请求用户选择的特定文件访问权限
  /// 在桌面平台使用原生文件选择器
  static Future<String?> pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;
      return result.files.single.path;
    } catch (e) {
      debugPrint('FileAccessHelper: pickVideo error: $e');
      return null;
    }
  }

  /// 选择多个视频文件
  ///
  /// 在 Android 上使用 SAF，只请求用户选择的特定文件访问权限
  static Future<List<String>> pickVideos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return [];
      return result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
    } catch (e) {
      debugPrint('FileAccessHelper: pickVideos error: $e');
      return [];
    }
  }

  /// 选择单个文件（自定义扩展名）
  ///
  /// [allowedExtensions] 允许的文件扩展名列表，如 ['json', 'txt']
  static Future<String?> pickFile({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;
      return result.files.single.path;
    } catch (e) {
      debugPrint('FileAccessHelper: pickFile error: $e');
      return null;
    }
  }

  /// 保存文件（创建新文件或覆盖现有文件）
  ///
  /// 在 Android 上使用 SAF 的 ACTION_CREATE_DOCUMENT
  /// 在桌面平台使用原生保存对话框
  ///
  /// [fileName] 建议的文件名
  /// [dialogTitle] 对话框标题
  /// [allowedExtensions] 允许的文件扩展名列表
  ///
  /// 返回用户选择的保存路径，如果取消则返回 null
  static Future<String?> saveFile({
    required String fileName,
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle ?? '保存文件',
        fileName: fileName,
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      return path;
    } catch (e) {
      debugPrint('FileAccessHelper: saveFile error: $e');
      return null;
    }
  }

  /// 选择图片文件
  static Future<String?> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;
      return result.files.single.path;
    } catch (e) {
      debugPrint('FileAccessHelper: pickImage error: $e');
      return null;
    }
  }

  /// 选择多个图片文件
  static Future<List<String>> pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return [];
      return result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
    } catch (e) {
      debugPrint('FileAccessHelper: pickImages error: $e');
      return [];
    }
  }

  /// 选择音频文件
  static Future<String?> pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;
      return result.files.single.path;
    } catch (e) {
      debugPrint('FileAccessHelper: pickAudio error: $e');
      return null;
    }
  }

  /// 选择多个音频文件
  static Future<List<String>> pickAudios() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return [];
      return result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
    } catch (e) {
      debugPrint('FileAccessHelper: pickAudios error: $e');
      return [];
    }
  }

  /// 选择任意类型的文件
  static Future<String?> pickAnyFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;
      return result.files.single.path;
    } catch (e) {
      debugPrint('FileAccessHelper: pickAnyFile error: $e');
      return null;
    }
  }

  /// 选择多个任意类型的文件
  static Future<List<String>> pickAnyFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return [];
      return result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
    } catch (e) {
      debugPrint('FileAccessHelper: pickAnyFiles error: $e');
      return [];
    }
  }
}
