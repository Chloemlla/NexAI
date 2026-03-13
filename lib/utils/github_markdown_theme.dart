/// GitHub Markdown CSS theme colors
/// Extracted from https://github.com/sindresorhus/github-markdown-css
library;

import 'package:flutter/material.dart';

class GitHubMarkdownTheme {
  final bool isDark;

  const GitHubMarkdownTheme({required this.isDark});

  // ── Background Colors ──────────────────────────────────────────────────────

  Color get bgDefault => isDark
      ? const Color(0xFF0d1117) // --bgColor-default (dark)
      : const Color(0xFFffffff); // white (light)

  Color get bgMuted => isDark
      ? const Color(0xFF151b23) // --bgColor-muted (dark)
      : const Color(0xFFf6f8fa); // --bgColor-muted (light)

  Color get bgAttentionMuted => isDark
      ? const Color(0x26bb8009) // --bgColor-attention-muted (dark)
      : const Color(0xFFfff8c5); // --bgColor-attention-muted (light)

  // ── Foreground Colors ──────────────────────────────────────────────────────

  Color get fgDefault => isDark
      ? const Color(0xFFf0f6fc) // --fgColor-default (dark)
      : const Color(0xFF1f2328); // default text (light)

  Color get fgMuted => isDark
      ? const Color(0xFF9198a1) // --fgColor-muted (dark)
      : const Color(0xFF636c76); // muted text (light)

  Color get fgAccent => isDark
      ? const Color(0xFF4493f8) // --fgColor-accent (dark)
      : const Color(0xFF0969da); // accent blue (light)

  Color get fgDanger => isDark
      ? const Color(0xFFf85149) // --fgColor-danger (dark)
      : const Color(0xFFd1242f); // --fgColor-danger (light)

  Color get fgSuccess => isDark
      ? const Color(0xFF3fb950) // --fgColor-success (dark)
      : const Color(0xFF1a7f37); // success green (light)

  Color get fgAttention => isDark
      ? const Color(0xFFd29922) // --fgColor-attention (dark)
      : const Color(0xFF9a6700); // attention yellow (light)

  // ── Border Colors ──────────────────────────────────────────────────────────

  Color get borderDefault => isDark
      ? const Color(0xFF3d444d) // --borderColor-default (dark)
      : const Color(0xFFd1d9e0); // --borderColor-default (light)

  Color get borderMuted => isDark
      ? const Color(0xB33d444d) // --borderColor-muted (dark)
      : const Color(0xFFd8dee4); // border muted (light)

  // ── Syntax Highlighting (Prettylights) ─────────────────────────────────────

  Color get syntaxComment => isDark
      ? const Color(0xFF9198a1) // --color-prettylights-syntax-comment (dark)
      : const Color(0xFF59636e); // --color-prettylights-syntax-comment (light)

  Color get syntaxConstant => isDark
      ? const Color(0xFF79c0ff) // --color-prettylights-syntax-constant (dark)
      : const Color(0xFF0550ae); // --color-prettylights-syntax-constant (light)

  Color get syntaxEntity => isDark
      ? const Color(0xFFd2a8ff) // --color-prettylights-syntax-entity (dark)
      : const Color(0xFF6639ba); // --color-prettylights-syntax-entity (light)

  Color get syntaxKeyword => isDark
      ? const Color(0xFFff7b72) // --color-prettylights-syntax-keyword (dark)
      : const Color(0xFFcf222e); // --color-prettylights-syntax-keyword (light)

  Color get syntaxString => isDark
      ? const Color(0xFFa5d6ff) // --color-prettylights-syntax-string (dark)
      : const Color(0xFF0a3069); // string blue (light)

  Color get syntaxVariable => isDark
      ? const Color(0xFFffa657) // --color-prettylights-syntax-variable (dark)
      : const Color(0xFF953800); // variable orange (light)

  Color get syntaxMarkupHeading => isDark
      ? const Color(0xFF1f6feb) // --color-prettylights-syntax-markup-heading (dark)
      : const Color(0xFF0550ae); // --color-prettylights-syntax-markup-heading (light)

  // ── Code Block Background ──────────────────────────────────────────────────

  Color get codeBlockBg => isDark
      ? const Color(0xFF161b22) // slightly lighter than bgDefault
      : const Color(0xFFf6f8fa); // bgMuted

  // ── Inline Code ────────────────────────────────────────────────────────────

  Color get inlineCodeBg => isDark
      ? const Color(0x33656c76) // semi-transparent gray
      : const Color(0x1F818b98); // --bgColor-neutral-muted (light)

  Color get inlineCodeFg => fgDefault;

  // ── Link Colors ────────────────────────────────────────────────────────────

  Color get linkColor => fgAccent;

  // ── Blockquote ─────────────────────────────────────────────────────────────

  Color get blockquoteBorder => isDark
      ? const Color(0xFF3d444d)
      : const Color(0xFFd1d9e0);

  Color get blockquoteFg => fgMuted;

  // ── Table ──────────────────────────────────────────────────────────────────

  Color get tableBorder => borderDefault;
  Color get tableHeaderBg => bgMuted;

  // ── Heading Colors ─────────────────────────────────────────────────────────

  Color get headingFg => fgDefault;
  Color get headingBorder => borderMuted;
}
