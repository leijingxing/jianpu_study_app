import 'dart:math' as math;

class PitchDetection {
  const PitchDetection({
    required this.frequencyHz,
    required this.confidence,
    required this.rms,
  });

  final double frequencyHz;
  final double confidence;
  final double rms;

  bool get hasPitch => frequencyHz.isFinite && frequencyHz > 0;
}

class NoteMatch {
  const NoteMatch({
    required this.midi,
    required this.noteName,
    required this.jianpu,
    required this.octave,
    required this.frequencyHz,
    required this.cents,
  });

  final int midi;
  final String noteName;
  final String jianpu;
  final int octave;
  final double frequencyHz;
  final double cents;

  String get displayName => '$noteName$octave';
  String get centsLabel {
    if (cents.abs() < 1) return '准';
    return cents > 0 ? '偏高 ${cents.round()}' : '偏低 ${cents.abs().round()}';
  }
}

class TimbreProfile {
  const TimbreProfile({
    required this.rms,
    required this.peak,
    required this.spectralCentroidHz,
    required this.spectralRolloffHz,
    required this.spectralFlatness,
    required this.harmonicRatio,
    required this.brightness,
    required this.richness,
    required this.noise,
    required this.spectrumBands,
    required this.label,
  });

  final double rms;
  final double peak;
  final double spectralCentroidHz;
  final double spectralRolloffHz;
  final double spectralFlatness;
  final double harmonicRatio;
  final double brightness;
  final double richness;
  final double noise;
  final List<double> spectrumBands;
  final String label;
}

class InstrumentAnalysisResult {
  const InstrumentAnalysisResult({
    required this.isVoiced,
    required this.pitch,
    required this.note,
    required this.timbre,
    required this.stability,
    required this.message,
  });

  final bool isVoiced;
  final PitchDetection? pitch;
  final NoteMatch? note;
  final TimbreProfile timbre;
  final double stability;
  final String message;

  static InstrumentAnalysisResult silence(TimbreProfile timbre) {
    return InstrumentAnalysisResult(
      isVoiced: false,
      pitch: null,
      note: null,
      timbre: timbre,
      stability: 0,
      message: '等待稳定单音',
    );
  }
}

double clampUnit(double value) => value.clamp(0.0, 1.0).toDouble();

double log2(num value) => math.log(value) / math.ln2;
