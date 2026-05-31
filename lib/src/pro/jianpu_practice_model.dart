import '../data/models.dart';

enum PracticeMode {
  listen('听音', '先听旋律和节拍'),
  rhythm('读拍', '只读节奏和歌词'),
  solfege('唱谱', '跟高亮唱数字'),
  lyric('带词', '把歌词贴回旋律');

  const PracticeMode(this.label, this.description);

  final String label;
  final String description;
}

class PracticeLesson {
  const PracticeLesson({
    required this.title,
    required this.key,
    required this.sourceLabel,
    required this.phrases,
  });

  final String title;
  final String key;
  final String sourceLabel;
  final List<PracticePhrase> phrases;

  int get phraseCount => phrases.length;
  double get totalBeats =>
      phrases.fold(0, (previous, phrase) => previous + phrase.totalBeats);
}

class PracticePhrase {
  const PracticePhrase({
    required this.index,
    required this.focus,
    required this.meter,
    required this.rhythm,
    required this.lyric,
    required this.tip,
    required this.notes,
    required this.measureCount,
  });

  final int index;
  final String focus;
  final String meter;
  final String rhythm;
  final String lyric;
  final String tip;
  final List<PracticeNote> notes;
  final int measureCount;

  String get solfegeLine => notes
      .where((note) => !note.isHold)
      .map((note) => note.solfege)
      .join('  ');

  String get beatLine => notes.map((note) => note.beatText).join('  ');

  double get totalBeats =>
      notes.fold(0, (previous, note) => previous + note.beats);
}

class PracticeNote {
  const PracticeNote({
    required this.raw,
    required this.lyric,
    required this.solfege,
    required this.beats,
  });

  final String raw;
  final String lyric;
  final String solfege;
  final double beats;

  bool get isHold => raw == '-';
  bool get isRest => raw.contains('0');
  String get display => isHold ? '-' : raw;
  String get beatText {
    if (isHold) return '延';
    if (isRest) return '停';
    if (beats <= 0.25) return 'da';
    if (beats <= 0.5) return 'da';
    if (beats >= 2) return 'da--';
    if (beats > 1) return 'da-';
    return 'da';
  }
}

class PracticeSymbolTopic {
  const PracticeSymbolTopic({
    required this.symbol,
    required this.title,
    required this.explanation,
    required this.practice,
  });

  final String symbol;
  final String title;
  final String explanation;
  final String practice;
}

class _ParsedMeasure {
  const _ParsedMeasure({
    required this.raw,
    required this.notes,
    required this.lineBreak,
  });

  final List<String> raw;
  final List<PracticeNote> notes;
  final bool lineBreak;

  _ParsedMeasure copyWith({bool? lineBreak}) {
    return _ParsedMeasure(
      raw: raw,
      notes: notes,
      lineBreak: lineBreak ?? this.lineBreak,
    );
  }
}

const practiceSymbolTopics = [
  PracticeSymbolTopic(
    symbol: '1=C',
    title: '调号',
    explanation: '表示 1 按 C 调理解。练习时先固定一个调，把相对音高唱稳。',
    practice: '先不急着转调，连续唱 1-2-3-5 找到调性感。',
  ),
  PracticeSymbolTopic(
    symbol: '4/4',
    title: '拍号',
    explanation: '拍号决定一小节的拍数。练习时先把拍点读稳，再加音高。',
    practice: '用手轻拍强弱：强、弱、次强、弱。',
  ),
  PracticeSymbolTopic(
    symbol: '|',
    title: '小节线',
    explanation: '小节线把旋律切成可练的小块。不要一次硬唱整页。',
    practice: '先循环一个乐句，稳定后再接下一句。',
  ),
  PracticeSymbolTopic(
    symbol: '0',
    title: '休止符',
    explanation: '0 表示不唱，但节拍继续走。休止处不要抢进。',
    practice: '遇到 0 心里数拍，嘴停住，下一音准时进。',
  ),
  PracticeSymbolTopic(
    symbol: '_',
    title: '短时值',
    explanation: '下划线让音变短，一拍里会塞进更多音。',
    practice: '先读 da-da，再换成数字。',
  ),
  PracticeSymbolTopic(
    symbol: '-',
    title: '延长音',
    explanation: '横杠延续前一个音，不重新起音。',
    practice: '唱到横杠时拉住气息，直到拍子结束。',
  ),
  PracticeSymbolTopic(
    symbol: '⌒',
    title: '连音线',
    explanation: '连音线提示几个音要连贯，不要每个音都切断。',
    practice: '慢速连唱，保持气息不断。',
  ),
  PracticeSymbolTopic(
    symbol: '.',
    title: '附点',
    explanation: '附点把当前音延长一半，下一音通常会更靠后进入。',
    practice: '先拉长附点音，再读后面的短音。',
  ),
];

PracticeLesson buildPracticeLesson({
  required String? title,
  required MusicDetail? detail,
  required ScoreDocument? document,
}) {
  final lessonTitle =
      title ?? detail?.title ?? document?.title ?? _demoLesson.title;
  final key = resolvePracticeKey(detail);
  if (detail == null || document == null || document.notation.isEmpty) {
    return _demoLesson;
  }

  final measures = _parseMeasures(document);
  final phrases = _buildPhrasesFromMeasures(detail, measures);
  if (phrases.isEmpty) return _demoLesson;
  return PracticeLesson(
    title: lessonTitle,
    key: key,
    sourceLabel: '来自当前动态谱',
    phrases: phrases,
  );
}

String resolvePracticeKey(MusicDetail? detail) {
  final selected = detail?.selectedKey.trim() ?? '';
  if (selected.isNotEmpty) return selected;
  final original = detail?.originalKey.trim() ?? '';
  return original.isEmpty ? 'C' : original;
}

List<_ParsedMeasure> _parseMeasures(ScoreDocument document) {
  final measures = <_ParsedMeasure>[];
  final lyrics = document.lyrics;
  var lyricIndex = 0;
  var measureNotes = <PracticeNote>[];
  var measureRaw = <String>[];

  void flush() {
    if (measureNotes.isEmpty) {
      measureRaw = [];
      return;
    }
    measures.add(
      _ParsedMeasure(
        raw: List.of(measureRaw),
        notes: List.of(measureNotes),
        lineBreak: false,
      ),
    );
    measureNotes = [];
    measureRaw = [];
  }

  for (final line in document.notation) {
    for (final token in tokenizeNotationLine(line)) {
      if (token == '|') {
        flush();
        if (measures.length >= 96) break;
        continue;
      }
      if (RegExp(r'^\d+/\d+$').hasMatch(token)) continue;
      if (!RegExp(r'[0-7]').hasMatch(token) && !token.contains('-')) continue;

      final lyric = token.contains('-')
          ? '延'
          : token.contains('0')
          ? '停'
          : (lyricIndex < lyrics.length ? lyrics[lyricIndex] : '唱');
      if (!token.contains('-') && !token.contains('0')) {
        lyricIndex++;
      }
      measureRaw.add(token);
      measureNotes.add(
        PracticeNote(
          raw: token,
          lyric: lyric.isEmpty ? '唱' : lyric,
          solfege: _solfegeForToken(token),
          beats: _beatsForToken(token),
        ),
      );
    }
    flush();
    if (measures.isNotEmpty) {
      measures[measures.length - 1] = measures.last.copyWith(lineBreak: true);
    }
    if (measures.length >= 96) break;
  }

  return measures;
}

List<PracticePhrase> _buildPhrasesFromMeasures(
  MusicDetail detail,
  List<_ParsedMeasure> measures,
) {
  final result = <PracticePhrase>[];
  final buffer = <_ParsedMeasure>[];

  void flush() {
    if (buffer.isEmpty) return;
    final phraseIndex = result.length + 1;
    final notes = buffer.expand((measure) => measure.notes).toList();
    final raw = buffer.map((measure) => measure.raw.join(' ')).join(' | ');
    final lyricLine = notes
        .where((note) => !note.isHold)
        .map((note) => note.lyric)
        .where((text) => text.isNotEmpty && text != '唱' && text != '停')
        .join(' ');
    result.add(
      PracticePhrase(
        index: phraseIndex,
        focus: _focusForMeasure(notes),
        meter:
            [
              _meterKeyFor(detail),
              detail.timeSignature,
            ].where((text) => text.isNotEmpty).join('  ').trim().isEmpty
            ? '第 $phraseIndex 句'
            : [
                _meterKeyFor(detail),
                detail.timeSignature,
              ].where((text) => text.isNotEmpty).join('  '),
        rhythm: '$raw |',
        lyric: lyricLine.isEmpty ? '第 $phraseIndex 句' : lyricLine,
        tip: _tipForPhrase(notes, buffer.length),
        notes: notes,
        measureCount: buffer.length,
      ),
    );
    buffer.clear();
  }

  for (final measure in measures) {
    buffer.add(measure);
    if (_shouldClosePhrase(buffer)) flush();
    if (result.length >= 24) break;
  }
  flush();
  return result;
}

bool _shouldClosePhrase(List<_ParsedMeasure> buffer) {
  if (buffer.isEmpty) return false;
  final measureCount = buffer.length;
  final notes = buffer.expand((measure) => measure.notes).toList();
  final last = buffer.last;
  if (measureCount >= 4) return true;
  if (measureCount < 2 && !last.lineBreak) return false;
  final lyricText = notes.map((note) => note.lyric).join('');
  final phrasePunctuation = RegExp(r'[，,。.!！？?；;：:]').hasMatch(lyricText);
  final hasRest = notes.any((note) => note.raw.contains('0'));
  final hasHold = notes.any((note) => note.raw.contains('-'));
  return phrasePunctuation || hasRest || hasHold || last.lineBreak;
}

String _meterKeyFor(MusicDetail detail) {
  final key = resolvePracticeKey(detail);
  return key.isEmpty ? '' : '1=$key';
}

String _focusForMeasure(List<PracticeNote> notes) {
  if (notes.any((note) => note.raw.contains('-'))) return '延长音';
  if (notes.any((note) => note.raw.contains('0'))) return '休止';
  if (notes.any((note) => note.raw.contains('.') || note.beats > 1)) {
    return '附点与长音';
  }
  if (notes.any((note) => note.raw.contains('_') || note.beats < 1)) {
    return '短音节奏';
  }
  if (notes.any((note) => note.raw.contains("'"))) return '高音';
  return '唱谱';
}

String _tipForMeasure(List<PracticeNote> notes) {
  if (notes.any((note) => note.raw.contains('-'))) {
    return '横杠表示前一个音继续保持，别重新起音。';
  }
  if (notes.any((note) => note.raw.contains('0'))) {
    return '0 是休止，嘴停住，拍子继续走。';
  }
  if (notes.any((note) => note.raw.contains('.'))) {
    return '附点音要唱满，后面的音不要提前进。';
  }
  if (notes.any((note) => note.raw.contains('_') || note.beats < 1)) {
    return '这一句有短音，先读节奏，再跟音高。';
  }
  if (notes.any((note) => note.raw.contains("'"))) {
    return '这里出现高音，先听音高再跟唱。';
  }
  return '先听一遍，再读节奏，然后唱数字，最后带歌词。';
}

String _tipForPhrase(List<PracticeNote> notes, int measureCount) {
  final base = _tipForMeasure(notes);
  if (measureCount <= 1) return '$base 这一句较短，适合循环精练。';
  return '$base 当前乐句合并了 $measureCount 个小节，注意换气位置。';
}

double _beatsForToken(String raw) {
  if (raw.contains('-') && !RegExp(r'[0-7]').hasMatch(raw)) return 1;
  final base = raw.contains('=') ? 0.25 : (raw.contains('_') ? 0.5 : 1.0);
  final extended = base + '-'.allMatches(raw).length;
  return raw.contains('.') ? extended * 1.5 : extended;
}

String _solfegeForToken(String raw) {
  final match = RegExp(r'[0-7]').firstMatch(raw);
  if (match == null) return 'hold';
  return switch (match.group(0)) {
    '1' => 'do',
    '2' => 're',
    '3' => 'mi',
    '4' => 'fa',
    '5' => 'sol',
    '6' => 'la',
    '7' => 'si',
    _ => 'rest',
  };
}

const _demoLesson = PracticeLesson(
  title: '小兔乖乖',
  key: 'C',
  sourceLabel: '内置练习',
  phrases: [
    PracticePhrase(
      index: 1,
      focus: '从低 5 进到高 1',
      meter: '1=C  2/4',
      rhythm: '5  1 6  |',
      lyric: '小 兔 子',
      tip: '先唱 sol-do-la，注意 1 上面的点是高音 do。',
      measureCount: 1,
      notes: [
        PracticeNote(raw: '5', lyric: '小', solfege: 'sol', beats: 1),
        PracticeNote(raw: "1'", lyric: '兔', solfege: 'do', beats: 0.5),
        PracticeNote(raw: '6', lyric: '子', solfege: 'la', beats: 0.5),
      ],
    ),
    PracticePhrase(
      index: 2,
      focus: '同音重复',
      meter: '1=C  2/4',
      rhythm: '5  5  |',
      lyric: '乖 乖',
      tip: '两个 5 都要重新唱出来，别拖成一个长音。',
      measureCount: 1,
      notes: [
        PracticeNote(raw: '5', lyric: '乖', solfege: 'sol', beats: 1),
        PracticeNote(raw: '5', lyric: '乖', solfege: 'sol', beats: 1),
      ],
    ),
    PracticePhrase(
      index: 3,
      focus: '连线唱法',
      meter: '1=C  2/4',
      rhythm: '⌒ 3 5  6 1 |',
      lyric: '把 门 儿 开 开',
      tip: '3 到 5 有连线，先慢慢连过去，再接 6 和高音 1。',
      measureCount: 1,
      notes: [
        PracticeNote(raw: '3', lyric: '把', solfege: 'mi', beats: 0.5),
        PracticeNote(raw: '5', lyric: '门', solfege: 'sol', beats: 0.5),
        PracticeNote(raw: '6', lyric: '儿', solfege: 'la', beats: 0.5),
        PracticeNote(raw: "1'", lyric: '开', solfege: 'do', beats: 0.5),
        PracticeNote(raw: '5', lyric: '开', solfege: 'sol', beats: 1),
      ],
    ),
    PracticePhrase(
      index: 4,
      focus: '下行音阶',
      meter: '1=C  2/4',
      rhythm: '6  5 3  2 2 |',
      lyric: '快 点 儿 开 开',
      tip: '这是 la-sol-mi-re-re，下行时保持每个音清楚。',
      measureCount: 1,
      notes: [
        PracticeNote(raw: '6', lyric: '快', solfege: 'la', beats: 1),
        PracticeNote(raw: '5', lyric: '点', solfege: 'sol', beats: 0.5),
        PracticeNote(raw: '3', lyric: '儿', solfege: 'mi', beats: 0.5),
        PracticeNote(raw: '2', lyric: '开', solfege: 're', beats: 1),
        PracticeNote(raw: '2', lyric: '开', solfege: 're', beats: 1),
      ],
    ),
    PracticePhrase(
      index: 5,
      focus: '长音收句',
      meter: '1=C  2/4',
      rhythm: '3 6  5 - |',
      lyric: '我 不 开',
      tip: '最后的横杠要把 5 拉满两拍，唱到节拍结束再停。',
      measureCount: 1,
      notes: [
        PracticeNote(raw: '3', lyric: '我', solfege: 'mi', beats: 0.5),
        PracticeNote(raw: '6', lyric: '不', solfege: 'la', beats: 0.5),
        PracticeNote(raw: '5', lyric: '开', solfege: 'sol', beats: 1),
        PracticeNote(raw: '-', lyric: '延', solfege: 'hold', beats: 1),
      ],
    ),
  ],
);
