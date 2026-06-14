import 'dart:math' as math;

import 'analysis_models.dart';

class NoteMapper {
  const NoteMapper({this.a4Hz = 440, this.keyName = 'C'});

  final double a4Hz;
  final String keyName;

  NoteMatch mapFrequency(double frequencyHz) {
    final midiFloat = 69 + 12 * log2(frequencyHz / a4Hz);
    final midi = midiFloat.round();
    final targetHz = a4Hz * math.pow(2, (midi - 69) / 12);
    final cents = 1200 * log2(frequencyHz / targetHz);
    final noteIndex = midi % 12;
    final octave = midi ~/ 12 - 1;
    return NoteMatch(
      midi: midi,
      noteName: _noteNames[noteIndex],
      jianpu: _jianpuFor(midi),
      octave: octave,
      frequencyHz: targetHz.toDouble(),
      cents: cents,
    );
  }

  String _jianpuFor(int midi) {
    final tonic = _keySemitone(keyName);
    final relative = (midi - tonic) % 12;
    final degree = _semitoneToDegree[relative];
    if (degree == null) return _chromaticJianpu[relative] ?? '?';
    final tonicMidiNearC4 = 60 + tonic;
    final octaveOffset = ((midi - tonicMidiNearC4) / 12).floor();
    if (octaveOffset > 0) {
      return '$degree${List.filled(octaveOffset, "'").join()}';
    }
    if (octaveOffset < 0) {
      return '$degree${List.filled(octaveOffset.abs(), ',').join()}';
    }
    return degree;
  }

  int _keySemitone(String key) {
    return switch (key) {
      'C' => 0,
      'C#' || 'Db' => 1,
      'D' => 2,
      'D#' || 'Eb' => 3,
      'E' => 4,
      'F' => 5,
      'F#' || 'Gb' => 6,
      'G' => 7,
      'G#' || 'Ab' => 8,
      'A' => 9,
      'A#' || 'Bb' => 10,
      'B' => 11,
      _ => 0,
    };
  }
}

const _noteNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

const _semitoneToDegree = {
  0: '1',
  2: '2',
  4: '3',
  5: '4',
  7: '5',
  9: '6',
  11: '7',
};

const _chromaticJianpu = {1: '#1', 3: '#2', 6: '#4', 8: '#5', 10: '#6'};
