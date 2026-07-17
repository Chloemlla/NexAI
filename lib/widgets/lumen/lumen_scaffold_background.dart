import 'package:flutter/material.dart';

import '../../theme/lumen_tokens.dart';

/// Soft page backdrop matching Project-Lumen background ladder.
Color lumenScaffoldBackground(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? LumenTokens.backgroundDark
      : LumenTokens.background;
}
