import 'dart:math' as math;

import '../../domain/models/models.dart';

/// 时间线中的一个可播放音符。
final class TimedScoreNote {
  const TimedScoreNote({
    required this.noteIndex,
    required this.raw,
    required this.startMs,
    required this.endMs,
  });

  final int noteIndex;
  final String raw;
  final int startMs;
  final int endMs;
}

/// 将简谱 token 转换为稳定、可测试的播放时间线。
final class DynamicScoreTimeline {
  const DynamicScoreTimeline(this.notes);

  factory DynamicScoreTimeline.build(
    ScoreDocument document,
    MusicDetail detail,
  ) {
    final beatMs = detail.bpm <= 0 ? 1000.0 : 60000 / detail.bpm;
    var cursor = 0.0;
    var noteIndex = 0;
    final notes = <TimedScoreNote>[];
    for (final line in document.notation) {
      for (final raw in tokenizeNotationLine(line)) {
        if (raw == '|') continue;
        final duration = math.max(80.0, _beatsFor(raw) * beatMs);
        notes.add(
          TimedScoreNote(
            noteIndex: noteIndex++,
            raw: raw,
            startMs: cursor.round(),
            endMs: (cursor + duration).round(),
          ),
        );
        cursor += duration;
      }
    }
    return DynamicScoreTimeline(List.unmodifiable(notes));
  }

  final List<TimedScoreNote> notes;

  int get durationMs => notes.isEmpty ? 0 : notes.last.endMs;

  int noteIndexAt(int elapsedMs) {
    for (final note in notes) {
      if (elapsedMs >= note.startMs && elapsedMs < note.endMs) {
        return note.noteIndex;
      }
    }
    return -1;
  }

  TimedScoreNote? noteAt(int index) =>
      index < 0 || index >= notes.length ? null : notes[index];

  static double _beatsFor(String raw) {
    final base = raw.contains('=') ? 0.25 : (raw.contains('_') ? 0.5 : 1.0);
    final extended = base + '-'.allMatches(raw).length;
    return raw.contains('.') ? extended * 1.5 : extended;
  }
}
