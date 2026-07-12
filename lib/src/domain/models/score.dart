import 'score_document.dart';

/// 乐谱资源的业务类型。
enum ScoreKind { dynamic, image, accompaniment }

/// 乐谱资源的来源。
enum ResourceSource { guji, forum, yuepu }

/// 可播放的音轨。
final class AudioTrackItem {
  const AudioTrackItem({
    required this.id,
    required this.name,
    required this.mp3Url,
  });

  final String id;
  final String name;
  final String mp3Url;
}

/// 动态简谱列表项。
final class MusicSummary {
  const MusicSummary({
    required this.id,
    required this.title,
    required this.singer,
    required this.arranger,
    required this.times,
    required this.level,
    this.source = ResourceSource.guji,
    this.externalId = '',
    this.category = '',
    this.previewVideoUrl = '',
    this.encryptedVideoUrl = '',
    this.tracks = const [],
  });

  final int id;
  final String title;
  final String singer;
  final String arranger;
  final int times;
  final int level;
  final ResourceSource source;
  final String externalId;
  final String category;
  final String previewVideoUrl;
  final String encryptedVideoUrl;
  final List<AudioTrackItem> tracks;

  bool get isYuepu => source == ResourceSource.yuepu;
  String get resourceId => isYuepu ? externalId : id.toString();
  String get favoriteId => isYuepu ? 'yuepu-dyn:$externalId' : '$id';

  String get subtitle {
    final parts = <String>[
      if (singer.isNotEmpty) singer,
      if (category.isNotEmpty) category,
      if (arranger.isNotEmpty) '编：$arranger',
    ];
    return parts.isEmpty ? '动态简谱' : parts.join(' · ');
  }
}

/// 动态简谱详情。
final class MusicDetail {
  const MusicDetail({
    required this.id,
    required this.title,
    required this.originalKey,
    required this.selectedKey,
    required this.timeSignature,
    required this.bpm,
    required this.singer,
    required this.arranger,
    required this.composer,
    required this.lyricist,
    required this.scorePath,
    required this.coverPath,
    required this.times,
  });

  final int id;
  final String title;
  final String originalKey;
  final String selectedKey;
  final String timeSignature;
  final int bpm;
  final String singer;
  final String arranger;
  final String composer;
  final String lyricist;
  final String scorePath;
  final String coverPath;
  final int times;
}

/// 动态谱详情和已解析谱面组成的完整阅读内容。
final class DynamicScoreContent {
  const DynamicScoreContent({required this.detail, required this.document});

  final MusicDetail detail;
  final ScoreDocument document;
}

/// 图片谱列表项。
final class ImageScoreItem {
  const ImageScoreItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.pic,
    required this.views,
    required this.hasVideo,
    required this.date,
    this.source = ResourceSource.forum,
    this.fileUrl = '',
    this.encryptedUrl = '',
    this.fileType = '',
    this.category = '',
  });

  final String id;
  final String title;
  final String summary;
  final String pic;
  final int views;
  final bool hasVideo;
  final String date;
  final ResourceSource source;
  final String fileUrl;
  final String encryptedUrl;
  final String fileType;
  final String category;

  bool get isYuepu => source == ResourceSource.yuepu;
  List<String> get fileUrls => fileUrl
      .split('@')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  String get imageUrl {
    if (isYuepu) return fileUrls.isEmpty ? '' : fileUrls.first;
    if (pic.isEmpty || pic.startsWith('http')) return pic;
    if (pic.startsWith('//')) return 'http:$pic';
    if (pic.startsWith('/')) return 'http://www.jita666.com$pic';
    if (pic.startsWith('portal/')) {
      return 'http://www.jita666.com/data/attachment/$pic';
    }
    return 'http://www.jita666.com/$pic';
  }

  String get displaySubtitle {
    final parts = <String>[
      if (category.isNotEmpty) category,
      if (summary.isNotEmpty) summary,
      if (date.isNotEmpty) date,
    ];
    return parts.isEmpty ? '图片谱' : parts.join(' · ');
  }
}

/// 图片谱详情。
final class ImageScoreDetail {
  const ImageScoreDetail({
    required this.item,
    required this.imageUrls,
    required this.videoUrls,
  });

  final ImageScoreItem item;
  final List<String> imageUrls;
  final List<String> videoUrls;
}

/// 伴奏资源。
final class AccompanimentItem {
  const AccompanimentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.fileUrl,
    required this.encryptedUrl,
    required this.category,
    required this.playCount,
    required this.isEncrypted,
  });

  final String id;
  final String title;
  final String subtitle;
  final String fileUrl;
  final String encryptedUrl;
  final String category;
  final int playCount;
  final bool isEncrypted;

  String get favoriteId => 'yuepu-acc:$id';
}
