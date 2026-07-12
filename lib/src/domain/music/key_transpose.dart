const jianpuKeys = <String>[
  'C',
  'C#',
  'D',
  'Eb',
  'E',
  'F',
  'F#',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];

const _degreeOffsets = <int, int>{1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11};

int keySemitone(String key) {
  final normalized = key
      .trim()
      .replaceAll('♯', '#')
      .replaceAll('＃', '#')
      .replaceAll('♭', 'b')
      .replaceAll('降', 'b')
      .replaceAll('升', '#')
      .toUpperCase();
  return switch (normalized) {
    'C' => 0,
    'C#' || 'DB' => 1,
    'D' => 2,
    'D#' || 'EB' => 3,
    'E' => 4,
    'F' => 5,
    'F#' || 'GB' => 6,
    'G' => 7,
    'G#' || 'AB' => 8,
    'A' => 9,
    'A#' || 'BB' => 10,
    'B' => 11,
    _ => 0,
  };
}

String transposeJianpuToken({
  required String raw,
  required String fromKey,
  required String toKey,
}) {
  if (fromKey.trim().toUpperCase() == toKey.trim().toUpperCase()) return raw;
  final match = RegExp(r"([#b♯♭]?)([0-7])([,']*)").firstMatch(raw);
  if (match == null) return raw;
  final degree = int.parse(match.group(2)!);
  if (degree == 0) return raw;

  final accidentalText = match.group(1) ?? '';
  final octaveMarks = match.group(3) ?? '';
  final accidental = switch (accidentalText) {
    '#' || '♯' => 1,
    'b' || '♭' => -1,
    _ => 0,
  };
  final octave =
      "'".allMatches(octaveMarks).length - ','.allMatches(octaveMarks).length;
  final sourcePitch =
      keySemitone(fromKey) + _degreeOffsets[degree]! + accidental + octave * 12;
  final relative = sourcePitch - keySemitone(toKey);

  _Candidate? best;
  for (var octave = -3; octave <= 3; octave++) {
    for (final entry in _degreeOffsets.entries) {
      for (var accidental = -1; accidental <= 1; accidental++) {
        final pitch = octave * 12 + entry.value + accidental;
        final distance = (pitch - relative).abs();
        final candidate = _Candidate(
          degree: entry.key,
          accidental: accidental,
          octave: octave,
          distance: distance,
        );
        if (best == null ||
            candidate.distance < best.distance ||
            (candidate.distance == best.distance &&
                candidate.accidental.abs() < best.accidental.abs())) {
          best = candidate;
        }
      }
    }
  }

  final replacement = [
    if (best!.accidental > 0) '#',
    if (best.accidental < 0) 'b',
    '${best.degree}',
    if (best.octave > 0) List.filled(best.octave, "'").join(),
    if (best.octave < 0) List.filled(-best.octave, ',').join(),
  ].join();
  return raw.replaceRange(match.start, match.end, replacement);
}

class _Candidate {
  const _Candidate({
    required this.degree,
    required this.accidental,
    required this.octave,
    required this.distance,
  });

  final int degree;
  final int accidental;
  final int octave;
  final int distance;
}
