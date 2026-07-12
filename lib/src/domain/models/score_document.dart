import 'dart:convert';

/// 解析后的简谱文档。
final class ScoreDocument {
  const ScoreDocument({
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

  /// 解析项目使用的文本简谱格式。
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
      notation: List.unmodifiable(notationLines),
      lyrics: List.unmodifiable(lyricUnits),
    );
  }
}

/// 将歌词文本拆成与音符对齐的单元。
List<String> extractLyricUnits(String text) => text
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .map((part) => part.startsWith('+') ? '' : part)
    .toList(growable: false);

/// 将一行简谱拆成音符和小节线 token。
List<String> tokenizeNotationLine(String line) {
  final tokens = <String>[];
  for (final match in RegExp(r'\||[^\s|]+').allMatches(line)) {
    var raw = match.group(0)!.trim();
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

/// 返回倚音组合中的主音 token。
String mainJianpuToken(String raw) {
  if (!raw.startsWith('@')) return raw;
  final parts = raw.split('@').where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? raw : parts.last;
}
