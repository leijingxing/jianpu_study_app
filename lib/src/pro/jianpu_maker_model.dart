import 'dart:convert';

import '../data/models.dart';

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

class JianpuMakerDraft {
  JianpuMakerDraft({
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

  factory JianpuMakerDraft.starter() {
    return JianpuMakerDraft(
      title: '我的简谱',
      singer: '',
      composer: '',
      lyricist: '',
      arranger: '',
      keyName: 'C',
      timeSignature: '4/4',
      bpm: 88,
      tokens: const [],
      lyricsText: '',
    );
  }

  factory JianpuMakerDraft.fromJson(Map<String, dynamic> json) {
    return JianpuMakerDraft(
      title: cleanText(json['title']).isEmpty
          ? '我的简谱'
          : cleanText(json['title']),
      singer: cleanText(json['singer']),
      composer: cleanText(json['composer']),
      lyricist: cleanText(json['lyricist']),
      arranger: cleanText(json['arranger']),
      keyName: cleanText(json['keyName']).isEmpty
          ? 'C'
          : cleanText(json['keyName']),
      timeSignature: cleanText(json['timeSignature']).isEmpty
          ? '4/4'
          : cleanText(json['timeSignature']),
      bpm: asInt(json['bpm']).clamp(40, 220),
      tokens:
          (json['tokens'] as List?)
              ?.map(cleanText)
              .where((token) => token.isNotEmpty)
              .toList() ??
          const [],
      lyricsText: cleanText(json['lyricsText']),
    );
  }

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

  Map<String, dynamic> toJson() => {
    'title': title,
    'singer': singer,
    'composer': composer,
    'lyricist': lyricist,
    'arranger': arranger,
    'keyName': keyName,
    'timeSignature': timeSignature,
    'bpm': bpm,
    'tokens': tokens,
    'lyricsText': lyricsText,
  };

  String encode() => jsonEncode(toJson());

  ScoreDocument toDocument() {
    return ScoreDocument(
      title: title,
      composer: composer,
      lyricist: lyricist,
      notation: notationLines(tokens),
      lyrics: extractLyricUnits(lyricsText),
    );
  }

  MusicDetail toDetail() {
    return MusicDetail(
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
}

String buildJianpuToken({
  required String degree,
  required int octave,
  required JianpuNoteDuration duration,
}) {
  if (degree == '0') return '0${duration.suffix}';
  final octaveMark = octave < 0
      ? List.filled(octave.abs(), ',').join()
      : List.filled(octave, "'").join();
  return '$degree$octaveMark${duration.suffix}';
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
