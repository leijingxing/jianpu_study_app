import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import 'cached_video_controller_result.dart';

Future<CachedVideoControllerResult> createCachedVideoController(Uri uri) async {
  final url = uri.toString();
  final cacheManager = DefaultCacheManager();
  final cached = await cacheManager.getFileFromCache(url);
  if (cached != null && await cached.file.exists()) {
    return CachedVideoControllerResult(
      controller: VideoPlayerController.file(cached.file),
      cacheAvailable: true,
      loadedFromCache: true,
    );
  }

  try {
    final file = await cacheManager.getSingleFile(url);
    if (await file.exists()) {
      return CachedVideoControllerResult(
        controller: VideoPlayerController.file(file),
        cacheAvailable: true,
        loadedFromCache: false,
      );
    }
  } catch (_) {
    // Fall back to streaming if the cache download fails.
  }

  return CachedVideoControllerResult(
    controller: VideoPlayerController.networkUrl(uri),
    cacheAvailable: false,
    loadedFromCache: false,
  );
}
