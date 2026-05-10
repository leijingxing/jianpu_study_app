import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/key_transpose.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

class JianpuScoreView extends StatelessWidget {
  const JianpuScoreView({
    super.key,
    required this.document,
    required this.detail,
    required this.zoom,
    this.activeNoteIndex = -1,
    this.activePulse = 1,
    this.selectedKey,
    this.rewriteNotation = false,
  });

  final ScoreDocument document;
  final MusicDetail detail;
  final double zoom;
  final int activeNoteIndex;
  final double activePulse;
  final String? selectedKey;
  final bool rewriteNotation;

  @override
  Widget build(BuildContext context) {
    final width = math.max(360.0, MediaQuery.sizeOf(context).width - 24);
    final displayKey = selectedKey ?? detail.selectedKey;
    final layout = _ScoreLayout.from(
      document,
      width / zoom,
      fromKey: detail.selectedKey,
      toKey: displayKey,
      rewriteNotation: rewriteNotation,
    );
    return CustomPaint(
      size: Size(width, layout.height * zoom),
      painter: _JianpuPainter(
        document: document,
        detail: detail,
        layout: layout,
        zoom: zoom,
        activeNoteIndex: activeNoteIndex,
        activePulse: activePulse,
        selectedKey: displayKey,
      ),
    );
  }
}

class _ScoreNote {
  _ScoreNote({required this.raw, required this.lyric, required this.index});

  final String raw;
  final String lyric;
  final int index;

  bool get isSlurStart => raw.startsWith('(');
  bool get isSlurEnd => raw.endsWith(')');
  bool get isRest => display == '0';
  int get extendCount => '-'.allMatches(raw).length;
  bool get hasSingleUnderline => raw.contains('_');
  bool get hasDoubleUnderline => raw.contains('=');
  bool get hasRhythmDot => raw.contains('.');
  int get lowDotCount => ','.allMatches(raw).length;
  int get highDotCount => "'".allMatches(raw).length;

  String get display {
    return raw.replaceAll(RegExp(r"[()_=\-.,']"), '').trim();
  }
}

class _ScoreMeasure {
  _ScoreMeasure(this.notes);

  final List<_ScoreNote> notes;
}

class _ScoreRow {
  _ScoreRow(this.measures);

  final List<_ScoreMeasure> measures;

  int get noteCount =>
      measures.fold(0, (sum, measure) => sum + measure.notes.length);
}

class _PositionedNote {
  _PositionedNote(this.note, this.offset);

  final _ScoreNote note;
  final Offset offset;
}

class _ScoreLayout {
  _ScoreLayout({required this.rows, required this.width, required this.height});

  final List<_ScoreRow> rows;
  final double width;
  final double height;

  factory _ScoreLayout.from(
    ScoreDocument document,
    double width, {
    required String fromKey,
    required String toKey,
    required bool rewriteNotation,
  }) {
    final measures = _parseMeasures(
      document,
      fromKey: fromKey,
      toKey: toKey,
      rewriteNotation: rewriteNotation,
    );
    final usableWidth = math.max(320.0, width - 32);
    final targetSlots = math.max(12, (usableWidth / 25).floor());
    final rows = <_ScoreRow>[];
    var current = <_ScoreMeasure>[];
    var currentSlots = 0;

    for (final measure in measures) {
      final slots = math.max(1, measure.notes.length) + 1;
      if (current.isNotEmpty && currentSlots + slots > targetSlots) {
        rows.add(_ScoreRow(current));
        current = <_ScoreMeasure>[];
        currentSlots = 0;
      }
      current.add(measure);
      currentSlots += slots;
    }
    if (current.isNotEmpty) rows.add(_ScoreRow(current));

    final height = 106.0 + rows.length * 68.0;
    return _ScoreLayout(rows: rows, width: width, height: height);
  }

  static List<_ScoreMeasure> _parseMeasures(
    ScoreDocument document, {
    required String fromKey,
    required String toKey,
    required bool rewriteNotation,
  }) {
    final noteTexts = <String>[];
    for (final line in document.notation) {
      final matches = RegExp(r'\||[^\s|]+').allMatches(line);
      for (final match in matches) {
        final raw = match.group(0)!.trim();
        if (raw.isEmpty) continue;
        if (RegExp(r'^\d+/\d+$').hasMatch(raw)) continue;
        noteTexts.add(raw);
      }
    }

    final measures = <_ScoreMeasure>[];
    var notes = <_ScoreNote>[];
    var lyricIndex = 0;
    var noteIndex = 0;
    for (final text in noteTexts) {
      if (text == '|') {
        if (notes.isNotEmpty) {
          measures.add(_ScoreMeasure(notes));
          notes = <_ScoreNote>[];
        }
        continue;
      }
      final displayRaw = rewriteNotation
          ? transposeJianpuToken(raw: text, fromKey: fromKey, toKey: toKey)
          : text;
      notes.add(
        _ScoreNote(
          raw: displayRaw,
          lyric: lyricIndex < document.lyrics.length
              ? document.lyrics[lyricIndex++]
              : '',
          index: noteIndex++,
        ),
      );
    }
    if (notes.isNotEmpty) measures.add(_ScoreMeasure(notes));
    return measures;
  }
}

class _JianpuPainter extends CustomPainter {
  _JianpuPainter({
    required this.document,
    required this.detail,
    required this.layout,
    required this.zoom,
    required this.activeNoteIndex,
    required this.activePulse,
    required this.selectedKey,
  });

  final ScoreDocument document;
  final MusicDetail detail;
  final _ScoreLayout layout;
  final double zoom;
  final int activeNoteIndex;
  final double activePulse;
  final String selectedKey;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(zoom);
    final width = size.width / zoom;
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    _drawHeader(canvas, width);

    var y = 102.0;
    for (final row in layout.rows) {
      _drawRow(canvas, row, y, width, linePaint);
      y += 68;
    }
    canvas.restore();
  }

  void _drawHeader(Canvas canvas, double width) {
    _paintText(
      canvas,
      detail.title.isNotEmpty ? detail.title : document.title,
      Offset(width / 2, 14),
      fontSize: 22,
      weight: FontWeight.w800,
      align: TextAlign.center,
      anchor: _Anchor.topCenter,
    );
    _paintText(
      canvas,
      '歌手:${detail.singer.isEmpty ? '-' : detail.singer}',
      Offset(width - 14, 22),
      fontSize: 12.5,
      weight: FontWeight.w700,
      align: TextAlign.right,
      anchor: _Anchor.topRight,
    );
    _paintText(
      canvas,
      '曲:${detail.composer.isEmpty ? document.composer : detail.composer}',
      Offset(width - 14, 52),
      fontSize: 12.5,
      weight: FontWeight.w700,
      align: TextAlign.right,
      anchor: _Anchor.topRight,
    );
    _paintText(
      canvas,
      '词:${detail.lyricist.isEmpty ? document.lyricist : detail.lyricist}',
      Offset(width - 14, 77),
      fontSize: 12.5,
      weight: FontWeight.w700,
      align: TextAlign.right,
      anchor: _Anchor.topRight,
    );
    _paintText(
      canvas,
      '节奏:',
      const Offset(14, 44),
      fontSize: 14,
      weight: FontWeight.w700,
    );
    _drawFraction(canvas, detail.timeSignature, const Offset(55, 39));
    _paintText(
      canvas,
      '速度:${detail.bpm}',
      const Offset(14, 74),
      fontSize: 14,
      weight: FontWeight.w700,
    );
    _paintText(
      canvas,
      '原调:1=${detail.originalKey}  选调:1=$selectedKey',
      const Offset(118, 56),
      fontSize: 13.5,
      color: brandColor,
      weight: FontWeight.w800,
    );
  }

  void _drawFraction(Canvas canvas, String text, Offset offset) {
    final parts = text.split('/');
    if (parts.length != 2) {
      _paintText(
        canvas,
        text,
        offset,
        fontSize: 15,
        color: const Color(0xFF80D7D5),
        weight: FontWeight.w800,
      );
      return;
    }
    _paintText(
      canvas,
      parts.first,
      offset,
      fontSize: 15,
      color: const Color(0xFF80D7D5),
      weight: FontWeight.w800,
      anchor: _Anchor.topCenter,
      align: TextAlign.center,
    );
    canvas.drawLine(
      Offset(offset.dx - 7, offset.dy + 18),
      Offset(offset.dx + 7, offset.dy + 18),
      Paint()
        ..color = const Color(0xFF80D7D5)
        ..strokeWidth = 1.5,
    );
    _paintText(
      canvas,
      parts.last,
      Offset(offset.dx, offset.dy + 19),
      fontSize: 15,
      color: const Color(0xFF80D7D5),
      weight: FontWeight.w800,
      anchor: _Anchor.topCenter,
      align: TextAlign.center,
    );
  }

  void _drawRow(
    Canvas canvas,
    _ScoreRow row,
    double y,
    double width,
    Paint linePaint,
  ) {
    final slots = math.max(row.noteCount + row.measures.length + 1, 2);
    final step = (width - 32) / slots;
    var x = 16.0;
    Offset? slurStart;

    _drawBar(canvas, x, y, linePaint);
    x += step * 0.58;

    for (final measure in row.measures) {
      final measureNotes = <_PositionedNote>[];
      for (final note in measure.notes) {
        if (note.isSlurStart) slurStart = Offset(x, y - 7);
        final positionedNote = _PositionedNote(note, Offset(x, y));
        measureNotes.add(positionedNote);
        _drawNote(
          canvas,
          note,
          Offset(x, y),
          linePaint,
          note.index == activeNoteIndex,
        );

        if (note.isSlurEnd && slurStart != null) {
          final path = Path()
            ..moveTo(slurStart.dx - 8, slurStart.dy + 9)
            ..quadraticBezierTo((slurStart.dx + x) / 2, y - 18, x + 8, y);
          canvas.drawPath(path, linePaint..strokeWidth = 1.5);
          slurStart = null;
        }

        x += step;
      }
      _drawBeamGroups(canvas, measureNotes, y, linePaint);
      _drawBar(canvas, x - step * 0.36, y, linePaint);
      x += step * 0.72;
    }
  }

  void _drawNote(
    Canvas canvas,
    _ScoreNote note,
    Offset offset,
    Paint linePaint,
    bool active,
  ) {
    if (active) {
      final highlight = Paint()
        ..color = accentColor.withValues(alpha: 0.08 + 0.14 * activePulse)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(offset.dx, offset.dy + 18),
            width: 24 + 4 * activePulse,
            height: 34 + 4 * activePulse,
          ),
          const Radius.circular(8),
        ),
        highlight,
      );
    }

    _paintText(
      canvas,
      note.display,
      offset,
      fontSize: 18,
      weight: FontWeight.w800,
      color: active
          ? accentColor
          : (note.isRest ? mutedTextColor : Colors.black),
      anchor: _Anchor.topCenter,
      align: TextAlign.center,
    );

    if (note.extendCount > 0) {
      final length = 9.0 + note.extendCount * 10.0;
      canvas.drawLine(
        Offset(offset.dx + 9, offset.dy + 15),
        Offset(offset.dx + length, offset.dy + 15),
        linePaint..strokeWidth = 1.8,
      );
    }

    if (note.hasRhythmDot) {
      canvas.drawCircle(
        Offset(offset.dx + 10, offset.dy + 15),
        1.8,
        Paint()..color = active ? accentColor : Colors.black,
      );
    }

    for (var i = 0; i < note.lowDotCount; i++) {
      canvas.drawCircle(
        Offset(offset.dx, offset.dy + 24 + i * 4),
        1.7,
        Paint()..color = active ? accentColor : Colors.black,
      );
    }
    for (var i = 0; i < note.highDotCount; i++) {
      canvas.drawCircle(
        Offset(offset.dx, offset.dy - 4 - i * 4),
        1.7,
        Paint()..color = active ? accentColor : Colors.black,
      );
    }

    if (note.lyric.isNotEmpty) {
      _paintText(
        canvas,
        note.lyric,
        Offset(offset.dx, offset.dy + 37),
        fontSize: 13.5,
        weight: FontWeight.w700,
        anchor: _Anchor.topCenter,
        align: TextAlign.center,
      );
    }
  }

  void _drawBar(Canvas canvas, double x, double y, Paint linePaint) {
    canvas.drawLine(Offset(x, y + 2), Offset(x, y + 30), linePaint);
  }

  void _drawBeamGroups(
    Canvas canvas,
    List<_PositionedNote> notes,
    double y,
    Paint linePaint,
  ) {
    _drawBeamLine(
      canvas,
      notes,
      y + 29,
      (note) => note.hasSingleUnderline || note.hasDoubleUnderline,
      linePaint,
      1.8,
    );
    _drawBeamLine(
      canvas,
      notes,
      y + 33,
      (note) => note.hasDoubleUnderline,
      linePaint,
      1.4,
    );
  }

  void _drawBeamLine(
    Canvas canvas,
    List<_PositionedNote> notes,
    double y,
    bool Function(_ScoreNote note) test,
    Paint linePaint,
    double strokeWidth,
  ) {
    _PositionedNote? start;
    _PositionedNote? previous;

    void flush() {
      final first = start;
      final last = previous;
      if (first == null || last == null) return;
      canvas.drawLine(
        Offset(first.offset.dx - 9, y),
        Offset(last.offset.dx + 10, y),
        linePaint..strokeWidth = strokeWidth,
      );
    }

    for (final item in notes) {
      if (test(item.note)) {
        start ??= item;
        previous = item;
      } else {
        flush();
        start = null;
        previous = null;
      }
    }
    flush();
  }

  @override
  bool shouldRepaint(covariant _JianpuPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.detail != detail ||
        oldDelegate.zoom != zoom ||
        oldDelegate.activeNoteIndex != activeNoteIndex ||
        oldDelegate.activePulse != activePulse ||
        oldDelegate.selectedKey != selectedKey;
  }
}

enum _Anchor { topLeft, topCenter, topRight }

void _paintText(
  Canvas canvas,
  String text,
  Offset offset, {
  double fontSize = 14,
  Color color = Colors.black,
  FontWeight weight = FontWeight.normal,
  TextAlign align = TextAlign.left,
  _Anchor anchor = _Anchor.topLeft,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        height: 1.1,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: 420);
  final dx = switch (anchor) {
    _Anchor.topLeft => offset.dx,
    _Anchor.topCenter => offset.dx - painter.width / 2,
    _Anchor.topRight => offset.dx - painter.width,
  };
  painter.paint(canvas, Offset(dx, offset.dy));
}
