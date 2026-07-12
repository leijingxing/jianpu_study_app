import '../../../core/media/gallery_service.dart';
import '../../../core/error/failure.dart';
import '../../../media/gallery_image_saver.dart' as legacy;

/// 使用 Gal 插件保存网络图片。
final class GalleryServiceImpl implements GalleryService {
  const GalleryServiceImpl();

  @override
  Future<GallerySaveResult> saveNetworkImages({
    required List<String> urls,
    required String namePrefix,
  }) async {
    try {
      final result = await legacy.GalleryImageSaver.saveNetworkImages(
        urls: urls,
        namePrefix: namePrefix,
      );
      return GallerySaveResult(saved: result.saved, failed: result.failed);
    } catch (error) {
      throw PlatformFailure('图片保存失败，请检查相册权限和存储空间。', cause: error);
    }
  }
}
