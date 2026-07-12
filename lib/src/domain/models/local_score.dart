import 'score.dart';
import 'score_document.dart';

enum JianpuNoteDuration {
  quarter('四分', ''),
  half('二分', '-'),
  dotted('附点', '.'),
  eighth('八分', '_'),
  sixteenth('十六', '=');

  const JianpuNoteDuration(this.label, this.suffix);
  final String label;
  final String suffix;
}

/// 简谱制作器的不可变草稿。
final class JianpuMakerDraft {
  const JianpuMakerDraft({
    required this.title,
    required this.singer,
    required this.composer,
    required this.lyricist,
    required this.arranger,
    required this.keyName,
    required this.timeSignature,
    required this.bpm,
    required this.tokens,
    required this.lyricsText,
  });

  factory JianpuMakerDraft.starter() => const JianpuMakerDraft(
    title: '我的简谱',
    singer: '',
    composer: '',
    lyricist: '',
    arranger: '',
    keyName: 'C',
    timeSignature: '4/4',
    bpm: 88,
    tokens: [],
    lyricsText: '',
  );

  final String title;
  final String singer;
  final String composer;
  final String lyricist;
  final String arranger;
  final String keyName;
  final String timeSignature;
  final int bpm;
  final List<String> tokens;
  final String lyricsText;

  JianpuMakerDraft copyWith({
    String? title,
    String? singer,
    String? composer,
    String? lyricist,
    String? arranger,
    String? keyName,
    String? timeSignature,
    int? bpm,
    List<String>? tokens,
    String? lyricsText,
  }) => JianpuMakerDraft(
    title: title ?? this.title,
    singer: singer ?? this.singer,
    composer: composer ?? this.composer,
    lyricist: lyricist ?? this.lyricist,
    arranger: arranger ?? this.arranger,
    keyName: keyName ?? this.keyName,
    timeSignature: timeSignature ?? this.timeSignature,
    bpm: bpm ?? this.bpm,
    tokens: List.unmodifiable(tokens ?? this.tokens),
    lyricsText: lyricsText ?? this.lyricsText,
  );

  ScoreDocument toDocument() => ScoreDocument(
    title: title,
    composer: composer,
    lyricist: lyricist,
    notation: notationLines(tokens),
    lyrics: extractLyricUnits(lyricsText),
  );

  MusicDetail toDetail() => MusicDetail(
    id: 0,
    title: title,
    originalKey: keyName,
    selectedKey: keyName,
    timeSignature: timeSignature,
    bpm: bpm,
    singer: singer,
    arranger: arranger,
    composer: composer,
    lyricist: lyricist,
    scorePath: '',
    coverPath: '',
    times: 0,
  );
}

/// 本地保存的简谱。
final class LocalScore {
  const LocalScore({
    required this.id,
    required this.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final JianpuMakerDraft draft;
  final DateTime createdAt;
  final DateTime updatedAt;
}

String buildJianpuToken({
  required String degree,
  required int octave,
  required JianpuNoteDuration duration,
}) {
  if (degree == '0') return '0${duration.suffix}';
  final mark = octave < 0
      ? List.filled(octave.abs(), ',').join()
      : List.filled(octave, "'").join();
  return '$degree$mark${duration.suffix}';
}

List<String> notationLines(List<String> tokens, {int barsPerLine = 4}) {
  final lines = <String>[];
  final current = <String>[];
  var bars = 0;
  for (final token in tokens.where((token) => token.trim().isNotEmpty)) {
    current.add(token);
    if (token == '|') {
      bars++;
      if (bars >= barsPerLine && current.length > 1) {
        lines.add(current.join(' '));
        current.clear();
        bars = 0;
      }
    }
  }
  if (current.isNotEmpty) lines.add(current.join(' '));
  return lines;
}
