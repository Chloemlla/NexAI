class ModelRequestBudget {
  static const maxTranslationInputChars = 12000;
  static const maxImagePromptChars = 4000;
  static const maxImagesPerRequest = 4;
  static const maxImageBytes = 6 * 1024 * 1024;

  static String? validateTranslationInput(String text) {
    if (text.runes.length > maxTranslationInputChars) {
      return '文本过长，请控制在 $maxTranslationInputChars 个字符以内';
    }
    return null;
  }

  static String? validateImagePrompt(String prompt) {
    if (prompt.runes.length > maxImagePromptChars) {
      return '提示词过长，请控制在 $maxImagePromptChars 个字符以内';
    }
    return null;
  }

  static int clampImageCount(int value) =>
      value.clamp(1, maxImagesPerRequest).toInt();

  static String? validateImageBase64(String? imageBase64) {
    if (imageBase64 == null || imageBase64.isEmpty) return null;
    final estimatedBytes = (imageBase64.length * 3) ~/ 4;
    if (estimatedBytes > maxImageBytes) {
      return '图片过大，请控制在 ${maxImageBytes ~/ (1024 * 1024)} MB 以内';
    }
    return null;
  }
}
