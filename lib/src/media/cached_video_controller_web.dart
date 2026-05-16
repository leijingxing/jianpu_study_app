import 'package:video_player/video_player.dart';

import 'cached_video_controller_result.dart';

Future<CachedVideoControllerResult> createCachedVideoController(Uri uri) async {
  return CachedVideoControllerResult(
    controller: VideoPlayerController.networkUrl(uri),
    cacheAvailable: false,
    loadedFromCache: false,
  );
}
