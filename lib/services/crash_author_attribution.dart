import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Non-overridable crash author attribution, aligned with lumen-crash-core.
abstract final class CrashAuthorAttribution {
  static const String authorName = 'Chloemlla';
  static const String authorUrl = 'https://github.com/Chloemlla/';
  static const String footerLabel =
      'Crash SDK by Chloemlla · https://github.com/Chloemlla/';

  static String get fingerprintHex {
    return sha256
        .convert(utf8.encode('$authorName|$authorUrl'))
        .bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
