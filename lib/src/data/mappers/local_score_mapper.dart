import '../../domain/models/local_score.dart';
import 'score_mapper.dart';

final class LocalScoreMapper {
  const LocalScoreMapper._();

  static LocalScore fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final draftJson =
        (json['draft'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LocalScore(
      id: textValue(json['id']),
      draft: JianpuMakerDraft(
        title: textValue(draftJson['title']).isEmpty
            ? '我的简谱'
            : textValue(draftJson['title']),
        singer: textValue(draftJson['singer']),
        composer: textValue(draftJson['composer']),
        lyricist: textValue(draftJson['lyricist']),
        arranger: textValue(draftJson['arranger']),
        keyName: textValue(draftJson['keyName']).isEmpty
            ? 'C'
            : textValue(draftJson['keyName']),
        timeSignature: textValue(draftJson['timeSignature']).isEmpty
            ? '4/4'
            : textValue(draftJson['timeSignature']),
        bpm: intValue(draftJson['bpm']).clamp(40, 220),
        tokens: (draftJson['tokens'] as List? ?? const [])
            .map(textValue)
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        lyricsText: textValue(draftJson['lyricsText']),
      ),
      createdAt: DateTime.tryParse(textValue(json['createdAt'])) ?? now,
      updatedAt: DateTime.tryParse(textValue(json['updatedAt'])) ?? now,
    );
  }

  static Map<String, dynamic> toJson(LocalScore score) => {
    'id': score.id,
    'createdAt': score.createdAt.toIso8601String(),
    'updatedAt': score.updatedAt.toIso8601String(),
    'draft': {
      'title': score.draft.title,
      'singer': score.draft.singer,
      'composer': score.draft.composer,
      'lyricist': score.draft.lyricist,
      'arranger': score.draft.arranger,
      'keyName': score.draft.keyName,
      'timeSignature': score.draft.timeSignature,
      'bpm': score.draft.bpm,
      'tokens': score.draft.tokens,
      'lyricsText': score.draft.lyricsText,
    },
  };
}
