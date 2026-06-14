import 'dart:convert';

enum ScoreKind { dynamic, image, accompaniment }

enum ResourceSource { guji, forum, yuepu }

class AudioTrackItem {
  const AudioTrackItem({
    required this.id,
    required this.name,
    required this.mp3Url,
  });

  final String id;
  final String name;
  final String mp3Url;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'mp3Url': mp3Url};

  factory AudioTrackItem.fromJson(Map<String, dynamic> json) {
    return AudioTrackItem(
      id: cleanText(json['id'] ?? json['trackId']),
      name: cleanText(json['name'] ?? json['trackName'] ?? json['mp3Name']),
      mp3Url: cleanText(json['mp3Url']),
    );
  }
}

class MusicSummary {
  MusicSummary({
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

  String get favoriteId => isYuepu ? 'yuepu-dyn:$externalId' : '$id';

  String get subtitle {
    if (isYuepu) {
      final names = [
        if (singer.trim().isNotEmpty) singer,
        if (category.trim().isNotEmpty) category,
        if (arranger.trim().isNotEmpty) arranger,
      ];
      return names.isEmpty ? '悦谱动态资源' : names.join(' · ');
    }
    final names = [
      if (singer.trim().isNotEmpty) singer,
      if (arranger.trim().isNotEmpty) '编: $arranger',
    ];
    return names.isEmpty ? '动态简谱' : names.join(' · ');
  }

  factory MusicSummary.fromJson(Map<String, dynamic> json) {
    return MusicSummary(
      id: asInt(json['id']),
      title: cleanText(json['song_name']),
      singer: cleanText(json['singer']),
      arranger: cleanText(json['arranger']),
      times: asInt(json['times']),
      level: asInt(json['deerjs']),
    );
  }

  factory MusicSummary.fromYuepuJson(Map<String, dynamic> json) {
    final tracks = (json['trackList'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => AudioTrackItem.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.mp3Url.isNotEmpty)
        .toList();
    return MusicSummary(
      id: 0,
      title: cleanText(json['specName']),
      singer: cleanText(json['shakeLight']),
      arranger: cleanText(json['uploaderName']),
      times: asInt(json['playNum']),
      level: asInt(json['degreePoint']),
      source: ResourceSource.yuepu,
      externalId: cleanText(json['specId']),
      category: cleanText(json['categoryName']),
      previewVideoUrl: cleanText(json['noSpecUrl']),
      encryptedVideoUrl: cleanText(json['specUrl']),
      tracks: tracks,
    );
  }

  factory MusicSummary.fromFavorite(FavoriteItem item) {
    if (item.id.startsWith('yuepu-dyn:') && item.scorePath.isNotEmpty) {
      try {
        final json = (jsonDecode(item.scorePath) as Map)
            .cast<String, dynamic>();
        return MusicSummary(
          id: 0,
          title: item.title,
          singer: cleanText(json['singer']),
          arranger: cleanText(json['arranger']),
          times: asInt(json['times']),
          level: asInt(json['level']),
          source: ResourceSource.yuepu,
          externalId: item.id.substring('yuepu-dyn:'.length),
          category: cleanText(json['category']),
          previewVideoUrl: cleanText(json['previewVideoUrl']),
          encryptedVideoUrl: cleanText(json['encryptedVideoUrl']),
          tracks: (json['tracks'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (track) =>
                    AudioTrackItem.fromJson(track.cast<String, dynamic>()),
              )
              .where((track) => track.mp3Url.isNotEmpty)
              .toList(),
        );
      } catch (_) {
        // Fall through to a minimal item if the stored favorite is old.
      }
    }
    return MusicSummary(
      id: int.tryParse(item.id) ?? 0,
      title: item.title,
      singer: '',
      arranger: '',
      times: 0,
      level: 0,
    );
  }

  FavoriteItem toFavoriteItem() {
    return FavoriteItem(
      kind: ScoreKind.dynamic,
      id: favoriteId,
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
              'tracks': tracks.map((track) => track.toJson()).toList(),
            })
          : '',
    );
  }
}

class MusicDetail {
  MusicDetail({
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

  factory MusicDetail.fromJson(Map<String, dynamic> json) {
    return MusicDetail(
      id: asInt(json['id']),
      title: cleanText(json['song_name']),
      originalKey: cleanText(json['o_signature']),
      selectedKey: cleanText(json['key_signature']),
      timeSignature: cleanText(json['time_signature']),
      bpm: asInt(json['beats_per_minute']),
      singer: cleanText(json['singer']),
      arranger: cleanText(json['arranger']),
      composer: cleanText(json['composer']),
      lyricist: cleanText(json['lyricist']),
      scorePath: cleanText(json['xml_filename']),
      coverPath: cleanText(json['cover_img']),
      times: asInt(json['times']),
    );
  }
}

class ImageScoreItem {
  ImageScoreItem({
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

  List<String> get fileUrls => splitResourceUrls(fileUrl);

  String get imageUrl => isYuepu
      ? (fileUrls.isEmpty ? '' : fileUrls.first)
      : normalizeForumUrl(pic);

  String get displaySubtitle {
    if (isYuepu) {
      final parts = [
        if (category.isNotEmpty) category,
        if (summary.isNotEmpty) summary,
        if (date.isNotEmpty) date,
      ];
      return parts.isEmpty ? '悦谱曲谱' : parts.join(' · ');
    }
    return summary.isEmpty ? date : summary;
  }

  factory ImageScoreItem.fromJson(Map<String, dynamic> json) {
    return ImageScoreItem(
      id: cleanText(json['aid']),
      title: cleanText(json['title']),
      summary: cleanText(json['summary']),
      pic: cleanText(json['pic']),
      views: asInt(json['viewnum']),
      hasVideo: asInt(json['hasmp4']) == 1,
      date: cleanText(json['dateline']),
    );
  }

  factory ImageScoreItem.fromYuepuJson(Map<String, dynamic> json) {
    final musType = cleanText(json['musType']).toLowerCase();
    return ImageScoreItem(
      id: 'yuepu-mus:${cleanText(json['musId'])}',
      title: cleanText(json['musTitle']),
      summary: [
        if (cleanText(json['wordWriter']).isNotEmpty)
          '词: ${cleanText(json['wordWriter'])}',
        if (cleanText(json['songWriter']).isNotEmpty)
          '曲: ${cleanText(json['songWriter'])}',
      ].join(' · '),
      pic: '',
      views: asInt(json['playNum']),
      hasVideo: false,
      date: cleanText(json['uploadTime']),
      source: ResourceSource.yuepu,
      fileUrl: cleanText(json['musFileUrl']),
      encryptedUrl: cleanText(json['musEncryUrl']),
      fileType: musType,
      category: cleanText(json['classifyName'] ?? json['categoryName']),
    );
  }

  factory ImageScoreItem.favorite(FavoriteItem item) {
    if (item.id.startsWith('yuepu-mus:') && item.scorePath.isNotEmpty) {
      try {
        final json = (jsonDecode(item.scorePath) as Map)
            .cast<String, dynamic>();
        return ImageScoreItem(
          id: item.id,
          title: item.title,
          summary: item.subtitle,
          pic: '',
          views: 0,
          hasVideo: false,
          date: cleanText(json['date']),
          source: ResourceSource.yuepu,
          fileUrl: cleanText(json['fileUrl']),
          encryptedUrl: cleanText(json['encryptedUrl']),
          fileType: cleanText(json['fileType']),
          category: cleanText(json['category']),
        );
      } catch (_) {
        // Fall through to the legacy favorite shape.
      }
    }
    return ImageScoreItem(
      id: item.id,
      title: item.title,
      summary: item.subtitle,
      pic: item.imageUrl,
      views: 0,
      hasVideo: false,
      date: '',
    );
  }

  FavoriteItem toFavoriteItem() {
    return FavoriteItem(
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
}

class ImageScoreDetail {
  const ImageScoreDetail({
    required this.item,
    required this.imageUrls,
    required this.videoUrls,
  });

  final ImageScoreItem item;
  final List<String> imageUrls;
  final List<String> videoUrls;
}

class AccompanimentItem {
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

  factory AccompanimentItem.fromYuepuJson(Map<String, dynamic> json) {
    return AccompanimentItem(
      id: cleanText(json['accId']),
      title: cleanText(json['accName']),
      subtitle: [
        if (cleanText(json['accAuthor']).isNotEmpty)
          cleanText(json['accAuthor']),
        if (cleanText(json['accUserName']).isNotEmpty)
          '上传: ${cleanText(json['accUserName'])}',
      ].join(' · '),
      fileUrl: cleanText(json['fileUrl'] ?? json['accFileUrl']),
      encryptedUrl: cleanText(json['accEncryUrl']),
      category: cleanText(json['classifyName'] ?? json['categoryName']),
      playCount: asInt(json['playNum']),
      isEncrypted: asInt(json['isEncry']) == 1,
    );
  }

  factory AccompanimentItem.fromFavorite(FavoriteItem item) {
    if (item.scorePath.isNotEmpty) {
      try {
        final json = (jsonDecode(item.scorePath) as Map)
            .cast<String, dynamic>();
        return AccompanimentItem(
          id: item.id.startsWith('yuepu-acc:')
              ? item.id.substring('yuepu-acc:'.length)
              : item.id,
          title: item.title,
          subtitle: item.subtitle,
          fileUrl: cleanText(json['fileUrl']),
          encryptedUrl: cleanText(json['encryptedUrl']),
          category: cleanText(json['category']),
          playCount: asInt(json['playCount']),
          isEncrypted: asInt(json['isEncrypted']) == 1,
        );
      } catch (_) {
        // Fall through to a minimal item.
      }
    }
    return AccompanimentItem(
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      fileUrl: item.imageUrl,
      encryptedUrl: '',
      category: '',
      playCount: 0,
      isEncrypted: false,
    );
  }

  FavoriteItem toFavoriteItem() {
    return FavoriteItem(
      kind: ScoreKind.accompaniment,
      id: favoriteId,
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
}

class FavoriteItem {
  FavoriteItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    this.scorePath = '',
    this.imageUrl = '',
  });

  final ScoreKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String scorePath;
  final String imageUrl;

  String get key => '${kind.name}:$id';

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'scorePath': scorePath,
    'imageUrl': imageUrl,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    final kindText = cleanText(json['kind']);
    return FavoriteItem(
      kind: kindText == ScoreKind.image.name
          ? ScoreKind.image
          : kindText == ScoreKind.accompaniment.name
          ? ScoreKind.accompaniment
          : ScoreKind.dynamic,
      id: cleanText(json['id']),
      title: cleanText(json['title']),
      subtitle: cleanText(json['subtitle']),
      scorePath: cleanText(json['scorePath']),
      imageUrl: cleanText(json['imageUrl']),
    );
  }
}

class ScoreDocument {
  ScoreDocument({
    required this.title,
    required this.composer,
    required this.lyricist,
    required this.notation,
    required this.lyrics,
  });

  final String title;
  final String composer;
  final String lyricist;
  final List<String> notation;
  final List<String> lyrics;

  factory ScoreDocument.parse(String raw) {
    var title = '';
    var composer = '';
    var lyricist = '';
    final notationLines = <String>[];
    var lyricUnits = <String>[];
    var readingLyrics = false;

    for (final sourceLine in const LineSplitter().convert(raw)) {
      final line = sourceLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('title:')) {
        title = line.substring(6).trim();
      } else if (line.startsWith('composer:')) {
        composer = line.substring(9).trim();
      } else if (line.startsWith('lyricist:')) {
        lyricist = line.substring(9).trim();
        readingLyrics = false;
      } else if (line.startsWith('lyrics:')) {
        readingLyrics = true;
        final units = extractLyricUnits(line.substring(7).trim());
        if (lyricUnits.isEmpty || units.any((unit) => unit.isNotEmpty)) {
          lyricUnits = units;
        }
      } else if (readingLyrics) {
        final units = extractLyricUnits(line);
        if (units.any((unit) => unit.isNotEmpty)) {
          lyricUnits = units;
        }
      } else if (RegExp(r'[0-7]').hasMatch(line)) {
        notationLines.add(line);
      }
    }

    return ScoreDocument(
      title: title,
      composer: composer,
      lyricist: lyricist,
      notation: notationLines,
      lyrics: lyricUnits,
    );
  }
}

String cleanText(Object? value) {
  final text = (value ?? '').toString().trim();
  return text == 'null' ? '' : text;
}

int asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

List<String> extractLyricUnits(String text) {
  final result = <String>[];
  for (final part in text.split(RegExp(r'\s+'))) {
    if (part.isEmpty) continue;
    result.add(part.startsWith('+') ? '' : part);
  }
  return result;
}

List<String> tokenizeNotationLine(String line) {
  final tokens = <String>[];
  final matches = RegExp(r'\||[^\s|]+').allMatches(line);
  for (final match in matches) {
    var raw = match.group(0)!.trim();
    if (raw.isEmpty) continue;
    if (raw == '|') {
      tokens.add(raw);
      continue;
    }
    raw = raw.replaceAll(RegExp(r'^:+|:+$'), '');
    if (raw.isEmpty || RegExp(r'^\d+/\d+$').hasMatch(raw)) continue;
    tokens.add(raw);
  }
  return tokens;
}

String mainJianpuToken(String raw) {
  if (!raw.startsWith('@')) return raw;
  final parts = raw.split('@').where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? raw : parts.last;
}

String normalizeForumUrl(String path) {
  final text = cleanText(path);
  if (text.isEmpty) return '';
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  if (text.startsWith('//')) return 'http:$text';
  if (text.startsWith('data/')) return 'http://www.jita666.com/$text';
  if (text.startsWith('/')) return 'http://www.jita666.com$text';
  if (text.startsWith('portal/')) {
    return 'http://www.jita666.com/data/attachment/$text';
  }
  return 'http://www.jita666.com/$text';
}

List<String> splitResourceUrls(String value) {
  final text = cleanText(value);
  if (text.isEmpty) return const [];
  return text
      .split('@')
      .map((part) => cleanText(part))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}
