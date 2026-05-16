import 'cached_video_controller_result.dart';
import 'cached_video_controller_stub.dart'
    if (dart.library.io) 'cached_video_controller_io.dart'
    if (dart.library.html) 'cached_video_controller_web.dart'
    as impl;

Future<CachedVideoControllerResult> createCachedVideoController(Uri uri) {
  return impl.createCachedVideoController(uri);
}
