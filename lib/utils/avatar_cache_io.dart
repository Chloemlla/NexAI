/// On-disk cache for the account avatar so it survives restarts and renders
/// while offline.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'atomic_file_writer.dart';
import 'network_safety.dart';

const bool avatarCacheSupported = true;

/// Re-download once a cached copy is older than this, so a changed profile
/// photo still shows up even when the backend keeps the same URL.
const Duration _freshFor = Duration(days: 7);

/// Delete cached files that have not been refreshed for this long; avatar URLs
/// change over time and their old files would otherwise pile up.
const Duration _keepFor = Duration(days: 30);

const int _maxAvatarBytes = 2 * 1024 * 1024;
const int _memoryEntries = 4;
const Duration _networkTimeout = Duration(seconds: 10);

/// Insertion-ordered, so the oldest entry is the first key.
final Map<String, Uint8List> _memory = <String, Uint8List>{};
final Map<String, Future<Uint8List?>> _inflight =
    <String, Future<Uint8List?>>{};

/// Avatar bytes for [url], from memory, then disk, then network.
///
/// Returns null when the avatar cannot be cached (unsupported URL, or a first
/// load with no connectivity); callers then fall back to the remote URL. Never
/// throws.
Future<Uint8List?> loadCachedAvatar(String url) {
  final key = url.trim();
  if (key.isEmpty) {
    return Future<Uint8List?>.value();
  }

  final cached = _memory[key];
  if (cached != null) {
    return Future<Uint8List?>.value(cached);
  }

  return _inflight[key] ??= _resolve(
    key,
  ).whenComplete(() => _inflight.remove(key));
}

/// Drop a cached copy that failed to decode so the next load refetches it.
Future<void> evictCachedAvatar(String url) async {
  final key = url.trim();
  if (key.isEmpty) {
    return;
  }
  _memory.remove(key);
  try {
    final file = await _cacheFile(key);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e) {
    debugPrint('[NexAI Avatar] Evict failed: $e');
  }
}

/// Forget every cached avatar; called when the session is cleared.
Future<void> clearCachedAvatars() async {
  _memory.clear();
  try {
    final dir = await _cacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  } catch (e) {
    debugPrint('[NexAI Avatar] Clear failed: $e');
  }
}

Future<Uint8List?> _resolve(String url) async {
  File? file;
  try {
    file = await _cacheFile(url);
    if (await file.exists()) {
      final age = DateTime.now().difference(await file.lastModified());
      if (age < _freshFor) {
        return _remember(url, await file.readAsBytes());
      }
    }
  } catch (e) {
    debugPrint('[NexAI Avatar] Cache read failed: $e');
  }

  final downloaded = await _download(url);
  if (downloaded != null) {
    if (file != null) {
      try {
        await writeBytesAtomically(file, downloaded);
        _prune(file.parent).ignore();
      } catch (e) {
        debugPrint('[NexAI Avatar] Cache write failed: $e');
      }
    }
    return _remember(url, downloaded);
  }

  // Offline or a transient server failure: a stale photo beats the initials.
  try {
    if (file != null && await file.exists()) {
      return _remember(url, await file.readAsBytes());
    }
  } catch (e) {
    debugPrint('[NexAI Avatar] Stale cache read failed: $e');
  }
  return null;
}

Future<Uint8List?> _download(String url) async {
  if (NetworkSafety.validatePublicHttpUrl(url) != null) {
    return null;
  }

  try {
    final res = await http.get(Uri.parse(url)).timeout(_networkTimeout);
    if (res.statusCode != 200) {
      return null;
    }
    final bytes = res.bodyBytes;
    if (bytes.isEmpty || bytes.length > _maxAvatarBytes) {
      return null;
    }
    // A cached file that cannot be decoded would surface as an image error for
    // a whole week, and the crash reporter cannot tell it from a real crash.
    if (!_looksLikeImage(bytes)) {
      return null;
    }
    return bytes;
  } catch (e) {
    debugPrint('[NexAI Avatar] Download failed: $e');
    return null;
  }
}

bool _looksLikeImage(Uint8List bytes) {
  bool startsWith(List<int> magic, [int offset = 0]) {
    if (bytes.length < offset + magic.length) {
      return false;
    }
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) {
        return false;
      }
    }
    return true;
  }

  return startsWith(const [0x89, 0x50, 0x4e, 0x47]) || // PNG
      startsWith(const [0xff, 0xd8, 0xff]) || // JPEG
      startsWith(const [0x47, 0x49, 0x46, 0x38]) || // GIF
      startsWith(const [0x42, 0x4d]) || // BMP
      // WebP: "RIFF" <size> "WEBP"
      (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
          startsWith(const [0x57, 0x45, 0x42, 0x50], 8));
}

Uint8List _remember(String url, Uint8List bytes) {
  _memory.remove(url);
  _memory[url] = bytes;
  while (_memory.length > _memoryEntries) {
    _memory.remove(_memory.keys.first);
  }
  return bytes;
}

Future<Directory> _cacheDir() async {
  final base = await getApplicationCacheDirectory();
  return Directory('${base.path}/avatar_cache');
}

Future<File> _cacheFile(String url) async {
  final digest = sha256.convert(utf8.encode(url));
  return File('${(await _cacheDir()).path}/$digest');
}

Future<void> _prune(Directory dir) async {
  try {
    final cutoff = DateTime.now().subtract(_keepFor);
    await for (final entry in dir.list(followLinks: false)) {
      if (entry is! File) {
        continue;
      }
      if ((await entry.lastModified()).isBefore(cutoff)) {
        await entry.delete();
      }
    }
  } catch (e) {
    debugPrint('[NexAI Avatar] Prune failed: $e');
  }
}
