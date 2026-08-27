class ModelRequestBudget {
  static const maxTranslationInputChars = 5000;
  static const maxImagePromptChars = 4000;
  static const maxImagesPerRequest = 4;
  static const maxImageBytes = 6 * 1024 * 1024;

  static String? validateTranslationInput(String text) {
    if (_exceedsRuneLimit(text, maxTranslationInputChars)) {
      return '文本过长，请控制在 $maxTranslationInputChars 个字符以内';
    }
    return null;
  }

  static String? validateImagePrompt(String prompt) {
    if (_exceedsRuneLimit(prompt, maxImagePromptChars)) {
      return '提示词过长，请控制在 $maxImagePromptChars 个字符以内';
    }
    return null;
  }

  /// Rune count can never exceed the code-unit count, so a short string is
  /// accepted without walking it; longer input stops counting at [limit]
  /// instead of scanning the whole (possibly huge) paste.
  static bool _exceedsRuneLimit(String text, int limit) {
    if (text.length <= limit) return false;
    final iterator = text.runes.iterator;
    var count = 0;
    while (iterator.moveNext()) {
      if (++count > limit) return true;
    }
    return false;
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
