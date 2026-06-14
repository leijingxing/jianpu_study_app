import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/audio/analyzer/instrument_analyzer.dart';
import 'package:jianpu_study_app/src/audio/analyzer/note_mapper.dart';
import 'package:jianpu_study_app/src/audio/analyzer/timbre_analyzer.dart';
import 'package:jianpu_study_app/src/audio/analyzer/yin_pitch_detector.dart';

void main() {
  const sampleRate = 44100;

  test('YIN detects a stable A4 sine tone', () {
    final detector = YinPitchDetector();
    final frame = _sineFrame(frequency: 440, sampleRate: sampleRate);

    final pitch = detector.detect(frame, sampleRate);

    expect(pitch.frequencyHz, closeTo(440, 1.2));
    expect(pitch.confidence, greaterThan(0.85));
  });

  test('YIN keeps the fundamental when harmonics are present', () {
    final detector = YinPitchDetector();
    final frame = _harmonicFrame(frequency: 392, sampleRate: sampleRate);

    final pitch = detector.detect(frame, sampleRate);

    expect(pitch.frequencyHz, closeTo(392, 2.0));
    expect(pitch.confidence, greaterThan(0.80));
  });

  test('Note mapper returns note name, jianpu, and cents', () {
    const mapper = NoteMapper(keyName: 'C');

    final note = mapper.mapFrequency(445);

    expect(note.displayName, 'A4');
    expect(note.jianpu, '6');
    expect(note.cents, greaterThan(0));
  });

  test('Timbre analyzer marks harmonic tone richer than plain sine', () {
    const analyzer = TimbreAnalyzer();
    final plain = analyzer.analyze(
      _sineFrame(frequency: 440, sampleRate: sampleRate),
      sampleRate,
      pitchHz: 440,
    );
    final rich = analyzer.analyze(
      _harmonicFrame(frequency: 440, sampleRate: sampleRate),
      sampleRate,
      pitchHz: 440,
    );

    expect(rich.richness, greaterThan(plain.richness));
    expect(rich.harmonicRatio, greaterThan(0.65));
  });

  test('Instrument analyzer rejects quiet input and accepts voiced tone', () {
    final analyzer = InstrumentAnalyzer();
    final quiet = analyzer.analyze(
      List<double>.filled(4096, 0.0002),
      sampleRate,
    );

    expect(quiet.isVoiced, isFalse);

    final voiced = analyzer.analyze(
      _harmonicFrame(frequency: 523.25, sampleRate: sampleRate),
      sampleRate,
    );

    expect(voiced.isVoiced, isTrue);
    expect(voiced.note?.displayName, 'C5');
    expect(voiced.timbre.spectrumBands, hasLength(24));
  });
}

List<double> _sineFrame({
  required double frequency,
  required int sampleRate,
  int length = 4096,
  double amplitude = 0.55,
}) {
  return List<double>.generate(length, (index) {
    return amplitude * math.sin(2 * math.pi * frequency * index / sampleRate);
  });
}

List<double> _harmonicFrame({
  required double frequency,
  required int sampleRate,
  int length = 4096,
}) {
  return List<double>.generate(length, (index) {
    final phase = 2 * math.pi * frequency * index / sampleRate;
    return 0.42 * math.sin(phase) +
        0.34 * math.sin(phase * 2) +
        0.22 * math.sin(phase * 3) +
        0.11 * math.sin(phase * 4);
  });
}
