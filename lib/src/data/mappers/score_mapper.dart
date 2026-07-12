import '../../domain/models/score.dart';

/// 将各上游响应映射为领域乐谱模型。
final class ScoreMapper {
  const ScoreMapper._();

  static MusicSummary gujiSummary(Map<String, dynamic> json) => MusicSummary(
    id: intValue(json['id']),
    title: textValue(json['song_name']),
    singer: textValue(json['singer']),
    arranger: textValue(json['arranger']),
    times: intValue(json['times']),
    level: intValue(json['deerjs']),
  );

  static MusicSummary yuepuSummary(Map<String, dynamic> json) => MusicSummary(
    id: 0,
    title: textValue(json['specName']),
    singer: textValue(json['shakeLight']),
    arranger: textValue(json['uploaderName']),
    times: intValue(json['playNum']),
    level: intValue(json['degreePoint']),
    source: ResourceSource.yuepu,
    externalId: textValue(json['specId']),
    category: textValue(json['categoryName']),
    previewVideoUrl: textValue(json['noSpecUrl']),
    encryptedVideoUrl: textValue(json['specUrl']),
    tracks: (json['trackList'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .map(
          (item) => AudioTrackItem(
            id: textValue(item['id'] ?? item['trackId']),
            name: textValue(
              item['name'] ?? item['trackName'] ?? item['mp3Name'],
            ),
            mp3Url: textValue(item['mp3Url']),
          ),
        )
        .where((item) => item.mp3Url.isNotEmpty)
        .toList(growable: false),
  );

  static MusicDetail gujiDetail(Map<String, dynamic> json) => MusicDetail(
    id: intValue(json['id']),
    title: textValue(json['song_name']),
    originalKey: textValue(json['o_signature']),
    selectedKey: textValue(json['key_signature']),
    timeSignature: textValue(json['time_signature']),
    bpm: intValue(json['beats_per_minute']),
    singer: textValue(json['singer']),
    arranger: textValue(json['arranger']),
    composer: textValue(json['composer']),
    lyricist: textValue(json['lyricist']),
    scorePath: textValue(json['xml_filename']),
    coverPath: textValue(json['cover_img']),
    times: intValue(json['times']),
  );

  static ImageScoreItem forumImage(Map<String, dynamic> json) => ImageScoreItem(
    id: textValue(json['aid']),
    title: textValue(json['title']),
    summary: textValue(json['summary']),
    pic: textValue(json['pic']),
    views: intValue(json['viewnum']),
    hasVideo: intValue(json['hasmp4']) == 1,
    date: textValue(json['dateline']),
  );

  static ImageScoreItem yuepuImage(Map<String, dynamic> json) => ImageScoreItem(
    id: 'yuepu-mus:${textValue(json['musId'])}',
    title: textValue(json['musTitle']),
    summary: [
      if (textValue(json['wordWriter']).isNotEmpty)
        '词：${textValue(json['wordWriter'])}',
      if (textValue(json['songWriter']).isNotEmpty)
        '曲：${textValue(json['songWriter'])}',
    ].join(' · '),
    pic: '',
    views: intValue(json['playNum']),
    hasVideo: false,
    date: textValue(json['uploadTime']),
    source: ResourceSource.yuepu,
    fileUrl: textValue(json['musFileUrl']),
    encryptedUrl: textValue(json['musEncryUrl']),
    fileType: textValue(json['musType']).toLowerCase(),
    category: textValue(json['classifyName'] ?? json['categoryName']),
  );

  static AccompanimentItem yuepuAccompaniment(Map<String, dynamic> json) =>
      AccompanimentItem(
        id: textValue(json['accId']),
        title: textValue(json['accName']),
        subtitle: [
          if (textValue(json['accAuthor']).isNotEmpty)
            textValue(json['accAuthor']),
          if (textValue(json['accUserName']).isNotEmpty)
            '上传：${textValue(json['accUserName'])}',
        ].join(' · '),
        fileUrl: textValue(json['fileUrl'] ?? json['accFileUrl']),
        encryptedUrl: textValue(json['accEncryUrl']),
        category: textValue(json['classifyName'] ?? json['categoryName']),
        playCount: intValue(json['playNum']),
        isEncrypted: intValue(json['isEncry']) == 1,
      );
}

String textValue(Object? value) {
  final text = (value ?? '').toString().trim();
  return text == 'null' ? '' : text;
}

int intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '0').toString()) ?? 0;
}
