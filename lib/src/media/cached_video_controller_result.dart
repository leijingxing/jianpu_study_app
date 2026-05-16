import 'package:video_player/video_player.dart';

class CachedVideoControllerResult {
  const CachedVideoControllerResult({
    required this.controller,
    required this.cacheAvailable,
    required this.loadedFromCache,
  });

  final VideoPlayerController controller;
  final bool cacheAvailable;
  final bool loadedFromCache;
}
