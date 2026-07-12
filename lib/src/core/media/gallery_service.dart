/// 一次批量图片保存的结果。
final class GallerySaveResult {
  const GallerySaveResult({required this.saved, required this.failed});

  final int saved;
  final int failed;
}

/// 相册写入平台边界。
abstract interface class GalleryService {
  Future<GallerySaveResult> saveNetworkImages({
    required List<String> urls,
    required String namePrefix,
  });
}
