import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

class GallerySaveResult {
  const GallerySaveResult({required this.saved, required this.failed});

  final int saved;
  final int failed;
}

class GalleryImageSaver {
  const GalleryImageSaver._();

  static Future<GallerySaveResult> saveNetworkImages({
    required List<String> urls,
    required String namePrefix,
  }) async {
    var saved = 0;
    var failed = 0;
    final prefix = _safeFileName(namePrefix);
    final stamp = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < urls.length; i++) {
      try {
        final response = await http.get(Uri.parse(urls[i]));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          failed++;
          continue;
        }
        await Gal.putImageBytes(
          response.bodyBytes,
          name: '${prefix}_${stamp}_${i + 1}',
        );
        saved++;
      } on GalException {
        rethrow;
      } catch (_) {
        failed++;
      }
    }

    return GallerySaveResult(saved: saved, failed: failed);
  }

  static String galleryErrorMessage(GalExceptionType type) {
    return switch (type) {
      GalExceptionType.accessDenied => '没有相册写入权限',
      GalExceptionType.notEnoughSpace => '设备空间不足，无法保存图片',
      GalExceptionType.notSupportedFormat => '图片格式不支持',
      GalExceptionType.unexpected => '保存到相册失败',
    };
  }

  static String _safeFileName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.isEmpty ? 'jianpu' : cleaned;
  }
}
