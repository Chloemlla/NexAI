import 'dart:typed_data';

/// The browser already caches profile photos for us, so the web build renders
/// the remote URL directly instead of keeping a second copy.
const bool avatarCacheSupported = false;

Future<Uint8List?> loadCachedAvatar(String url) async => null;

Future<void> evictCachedAvatar(String url) async {}

Future<void> clearCachedAvatars() async {}
