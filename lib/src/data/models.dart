import 'dart:convert';

enum ScoreKind { dynamic, image }

class MusicSummary {
  MusicSummary({
    required this.id,
    required this.title,
    required this.singer,
    required this.arranger,
    required this.times,
    required this.level,
  });

  final int id;
  final String title;
  final String singer;
  final String arranger;
  final int times;
  final int level;

  String get subtitle {
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
  });

  final String id;
  final String title;
  final String summary;
  final String pic;
  final int views;
  final bool hasVideo;
  final String date;

  String get imageUrl => normalizeForumUrl(pic);

  String get displaySubtitle => summary.isEmpty ? date : summary;

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

  factory ImageScoreItem.favorite(FavoriteItem item) {
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
    return FavoriteItem(
      kind: json['kind'] == ScoreKind.image.name
          ? ScoreKind.image
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
