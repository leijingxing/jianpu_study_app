import 'dart:math' as math;

import 'analysis_models.dart';
import 'note_mapper.dart';
import 'timbre_analyzer.dart';
import 'yin_pitch_detector.dart';

class InstrumentAnalyzer {
  InstrumentAnalyzer({
    YinPitchDetector pitchDetector = const YinPitchDetector(),
    TimbreAnalyzer timbreAnalyzer = const TimbreAnalyzer(),
    this.minimumRms = 0.012,
    this.minimumConfidence = 0.68,
  }) : _pitchDetector = pitchDetector,
       _timbreAnalyzer = timbreAnalyzer;

  final YinPitchDetector _pitchDetector;
  final TimbreAnalyzer _timbreAnalyzer;
  final double minimumRms;
  final double minimumConfidence;
  final _recentFrequencies = <double>[];
  final _recentRms = <double>[];
  double? _smoothedFrequency;

  InstrumentAnalysisResult analyze(
    List<double> samples,
    int sampleRate, {
    String keyName = 'C',
    double a4Hz = 440,
  }) {
    final rawPitch = _pitchDetector.detect(samples, sampleRate);
    final voiced =
        rawPitch.rms >= minimumRms &&
        rawPitch.confidence >= minimumConfidence &&
        rawPitch.hasPitch;

    final frequency = voiced ? _smoothFrequency(rawPitch.frequencyHz) : null;
    final timbre = _timbreAnalyzer.analyze(
      samples,
      sampleRate,
      pitchHz: frequency,
    );

    if (!voiced || frequency == null) {
      _remember(null, rawPitch.rms);
      _smoothedFrequency = null;
      return InstrumentAnalysisResult.silence(timbre);
    }

    _remember(frequency, rawPitch.rms);
    final mapper = NoteMapper(a4Hz: a4Hz, keyName: keyName);
    final note = mapper.mapFrequency(frequency);
    final stability = _stability();
    final pitch = PitchDetection(
      frequencyHz: frequency,
      confidence: rawPitch.confidence,
      rms: rawPitch.rms,
    );

    return InstrumentAnalysisResult(
      isVoiced: true,
      pitch: pitch,
      note: note,
      timbre: timbre,
      stability: stability,
      message: stability > 0.76 ? '声音稳定' : '声音在波动',
    );
  }

  void reset() {
    _recentFrequencies.clear();
    _recentRms.clear();
    _smoothedFrequency = null;
  }

  double? _smoothFrequency(double frequency) {
    final previous = _smoothedFrequency;
    if (previous == null) {
      _smoothedFrequency = frequency;
      return frequency;
    }
    final centsApart = (1200 * log2(frequency / previous)).abs();
    if (centsApart > 180) {
      _smoothedFrequency = frequency;
      return frequency;
    }
    _smoothedFrequency = previous * 0.78 + frequency * 0.22;
    return _smoothedFrequency;
  }

  void _remember(double? frequency, double rms) {
    if (frequency != null && frequency.isFinite) {
      _recentFrequencies.add(frequency);
      if (_recentFrequencies.length > 12) {
        _recentFrequencies.removeAt(0);
      }
    }
    _recentRms.add(rms);
    if (_recentRms.length > 12) {
      _recentRms.removeAt(0);
    }
  }

  double _stability() {
    if (_recentFrequencies.length < 3) return 0.55;
    final reference =
        _recentFrequencies.reduce((a, b) => a + b) / _recentFrequencies.length;
    var centsVariance = 0.0;
    for (final frequency in _recentFrequencies) {
      final cents = 1200 * log2(frequency / reference);
      centsVariance += cents * cents;
    }
    final centsStdDev = math.sqrt(centsVariance / _recentFrequencies.length);

    final rmsMean = _recentRms.reduce((a, b) => a + b) / _recentRms.length;
    var rmsVariance = 0.0;
    for (final rms in _recentRms) {
      final normalized = rmsMean == 0 ? 0 : (rms - rmsMean) / rmsMean;
      rmsVariance += normalized * normalized;
    }
    final rmsStdDev = math.sqrt(rmsVariance / _recentRms.length);
    return clampUnit(1 - centsStdDev / 45 - rmsStdDev / 0.9);
  }
}
