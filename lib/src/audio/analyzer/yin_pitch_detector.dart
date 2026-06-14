import 'dart:math' as math;

import 'analysis_models.dart';

class YinPitchDetector {
  const YinPitchDetector({
    this.threshold = 0.12,
    this.minFrequencyHz = 65,
    this.maxFrequencyHz = 1600,
  });

  final double threshold;
  final double minFrequencyHz;
  final double maxFrequencyHz;

  PitchDetection detect(List<double> samples, int sampleRate) {
    if (samples.length < 64 || sampleRate <= 0) {
      return const PitchDetection(frequencyHz: 0, confidence: 0, rms: 0);
    }

    final prepared = _removeDc(samples);
    final rms = _rms(prepared);
    if (rms <= 0) {
      return const PitchDetection(frequencyHz: 0, confidence: 0, rms: 0);
    }

    final tauMin = math.max(2, (sampleRate / maxFrequencyHz).floor());
    final tauMax = math.min(
      prepared.length ~/ 2,
      (sampleRate / minFrequencyHz).ceil(),
    );
    if (tauMax <= tauMin + 2) {
      return PitchDetection(frequencyHz: 0, confidence: 0, rms: rms);
    }

    final difference = List<double>.filled(tauMax + 1, 0);
    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      final limit = prepared.length - tau;
      for (var i = 0; i < limit; i++) {
        final delta = prepared[i] - prepared[i + tau];
        sum += delta * delta;
      }
      difference[tau] = sum;
    }

    final cmnd = List<double>.filled(tauMax + 1, 1);
    var runningSum = 0.0;
    for (var tau = 1; tau <= tauMax; tau++) {
      runningSum += difference[tau];
      cmnd[tau] = runningSum == 0 ? 1 : difference[tau] * tau / runningSum;
    }

    var tauEstimate = -1;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      if (cmnd[tau] >= threshold) continue;
      while (tau + 1 <= tauMax && cmnd[tau + 1] < cmnd[tau]) {
        tau++;
      }
      tauEstimate = tau;
      break;
    }

    if (tauEstimate < 0) {
      var bestTau = tauMin;
      var bestValue = cmnd[tauMin];
      for (var tau = tauMin + 1; tau <= tauMax; tau++) {
        if (cmnd[tau] < bestValue) {
          bestTau = tau;
          bestValue = cmnd[tau];
        }
      }
      tauEstimate = bestValue < 0.22 ? bestTau : -1;
    }

    if (tauEstimate < 0) {
      return PitchDetection(frequencyHz: 0, confidence: 0, rms: rms);
    }

    final refinedTau = _parabolicMinimum(cmnd, tauEstimate);
    final frequency = sampleRate / refinedTau;
    final confidence = clampUnit(1 - cmnd[tauEstimate]);
    return PitchDetection(
      frequencyHz: frequency,
      confidence: confidence,
      rms: rms,
    );
  }

  List<double> _removeDc(List<double> samples) {
    final mean =
        samples.fold<double>(0, (sum, value) => sum + value) / samples.length;
    return List<double>.generate(
      samples.length,
      (index) => samples[index] - mean,
    );
  }

  double _rms(List<double> samples) {
    var energy = 0.0;
    for (final sample in samples) {
      energy += sample * sample;
    }
    return math.sqrt(energy / samples.length);
  }

  double _parabolicMinimum(List<double> values, int index) {
    if (index <= 0 || index >= values.length - 1) return index.toDouble();
    final left = values[index - 1];
    final center = values[index];
    final right = values[index + 1];
    final denominator = left - 2 * center + right;
    if (denominator.abs() < 1e-12) return index.toDouble();
    final offset = 0.5 * (left - right) / denominator;
    return index + offset.clamp(-0.5, 0.5);
  }
}
