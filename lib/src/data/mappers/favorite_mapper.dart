import 'dart:convert';

import '../../domain/models/favorite.dart';
import '../../domain/models/score.dart';
import 'score_mapper.dart';

/// 在领域资源与本地收藏快照之间转换。
final class FavoriteMapper {
  const FavoriteMapper._();

  static FavoriteItem fromJson(Map<String, dynamic> json) {
    final kind = switch (textValue(json['kind'])) {
      'image' => ScoreKind.image,
      'accompaniment' => ScoreKind.accompaniment,
      _ => ScoreKind.dynamic,
    };
    return FavoriteItem(
      kind: kind,
      id: textValue(json['id']),
      title: textValue(json['title']),
      subtitle: textValue(json['subtitle']),
      scorePath: textValue(json['scorePath']),
      imageUrl: textValue(json['imageUrl']),
    );
  }

  static Map<String, dynamic> toJson(FavoriteItem item) => {
    'kind': item.kind.name,
    'id': item.id,
    'title': item.title,
    'subtitle': item.subtitle,
    'scorePath': item.scorePath,
    'imageUrl': item.imageUrl,
  };

  static MusicSummary toMusicSummary(FavoriteItem item) {
    final json = _metadata(item.scorePath);
    return MusicSummary(
      id: int.tryParse(item.id) ?? 0,
      title: item.title,
      singer: textValue(json['singer']),
      arranger: textValue(json['arranger']),
      times: intValue(json['times']),
      level: intValue(json['level']),
      source: item.id.startsWith('yuepu-dyn:')
          ? ResourceSource.yuepu
          : ResourceSource.guji,
      externalId: item.id.startsWith('yuepu-dyn:')
          ? item.id.substring('yuepu-dyn:'.length)
          : '',
      category: textValue(json['category']),
      previewVideoUrl: textValue(json['previewVideoUrl']),
      encryptedVideoUrl: textValue(json['encryptedVideoUrl']),
      tracks: (json['tracks'] as List? ?? const [])
          .whereType<Map>()
          .map((track) => track.cast<String, dynamic>())
          .map(
            (track) => AudioTrackItem(
              id: textValue(track['id']),
              name: textValue(track['name']),
              mp3Url: textValue(track['mp3Url']),
            ),
          )
          .where((track) => track.mp3Url.isNotEmpty)
          .toList(growable: false),
    );
  }

  static ImageScoreItem toImageScore(FavoriteItem item) {
    final json = _metadata(item.scorePath);
    return ImageScoreItem(
      id: item.id,
      title: item.title,
      summary: item.subtitle,
      pic: item.imageUrl,
      views: 0,
      hasVideo: false,
      date: textValue(json['date']),
      source: item.id.startsWith('yuepu-mus:')
          ? ResourceSource.yuepu
          : ResourceSource.forum,
      fileUrl: textValue(json['fileUrl']),
      encryptedUrl: textValue(json['encryptedUrl']),
      fileType: textValue(json['fileType']),
      category: textValue(json['category']),
    );
  }

  static AccompanimentItem toAccompaniment(FavoriteItem item) {
    final json = _metadata(item.scorePath);
    return AccompanimentItem(
      id: item.id.startsWith('yuepu-acc:')
          ? item.id.substring('yuepu-acc:'.length)
          : item.id,
      title: item.title,
      subtitle: item.subtitle,
      fileUrl: textValue(json['fileUrl'] ?? item.imageUrl),
      encryptedUrl: textValue(json['encryptedUrl']),
      category: textValue(json['category']),
      playCount: intValue(json['playCount']),
      isEncrypted: intValue(json['isEncrypted']) == 1,
    );
  }

  static Map<String, dynamic> _metadata(String value) {
    if (value.isEmpty) return const {};
    try {
      return (jsonDecode(value) as Map).cast<String, dynamic>();
    } on Object {
      return const {};
    }
  }
}

extension MusicSummaryFavoriteMapping on MusicSummary {
  FavoriteItem toFavoriteItem() => FavoriteItem(
    kind: ScoreKind.dynamic,
    id: isYuepu ? 'yuepu-dyn:$externalId' : '$id',
    title: title,
    subtitle: subtitle,
    scorePath: isYuepu
        ? jsonEncode({
            'singer': singer,
            'arranger': arranger,
            'times': times,
            'level': level,
            'category': category,
            'previewVideoUrl': previewVideoUrl,
            'encryptedVideoUrl': encryptedVideoUrl,
            'tracks': [
              for (final track in tracks)
                {'id': track.id, 'name': track.name, 'mp3Url': track.mp3Url},
            ],
          })
        : '',
  );
}

extension ImageScoreFavoriteMapping on ImageScoreItem {
  FavoriteItem toFavoriteItem() => FavoriteItem(
    kind: ScoreKind.image,
    id: id,
    title: title,
    subtitle: displaySubtitle,
    imageUrl: imageUrl,
    scorePath: isYuepu
        ? jsonEncode({
            'date': date,
            'fileUrl': fileUrl,
            'encryptedUrl': encryptedUrl,
            'fileType': fileType,
            'category': category,
          })
        : '',
  );
}

extension AccompanimentFavoriteMapping on AccompanimentItem {
  FavoriteItem toFavoriteItem() => FavoriteItem(
    kind: ScoreKind.accompaniment,
    id: 'yuepu-acc:$id',
    title: title,
    subtitle: subtitle.isEmpty ? category : subtitle,
    imageUrl: fileUrl,
    scorePath: jsonEncode({
      'fileUrl': fileUrl,
      'encryptedUrl': encryptedUrl,
      'category': category,
      'playCount': playCount,
      'isEncrypted': isEncrypted ? 1 : 0,
    }),
  );
}
