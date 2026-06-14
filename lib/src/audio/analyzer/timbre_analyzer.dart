import 'dart:math' as math;

import 'analysis_models.dart';

class TimbreAnalyzer {
  const TimbreAnalyzer({this.bandCount = 24});

  final int bandCount;

  TimbreProfile analyze(
    List<double> samples,
    int sampleRate, {
    double? pitchHz,
  }) {
    if (samples.isEmpty || sampleRate <= 0) {
      return _empty();
    }

    final frame = _prepareFrame(samples);
    final rms = _rms(frame);
    final peak = frame.fold<double>(
      0,
      (maxValue, value) => math.max(maxValue, value.abs()),
    );
    final spectrum = _fftMagnitudes(frame);
    if (spectrum.isEmpty) {
      return _empty();
    }

    final binHz = sampleRate / frame.length;
    final total = spectrum.fold<double>(0, (sum, value) => sum + value);
    if (total <= 1e-12) {
      return TimbreProfile(
        rms: rms,
        peak: peak,
        spectralCentroidHz: 0,
        spectralRolloffHz: 0,
        spectralFlatness: 0,
        harmonicRatio: 0,
        brightness: 0,
        richness: 0,
        noise: 0,
        spectrumBands: List<double>.filled(bandCount, 0),
        label: '安静',
      );
    }

    var weightedFrequency = 0.0;
    var highEnergy = 0.0;
    var accumulated = 0.0;
    var rolloffHz = 0.0;
    final rolloffTarget = total * 0.85;
    for (var i = 1; i < spectrum.length; i++) {
      final frequency = i * binHz;
      final magnitude = spectrum[i];
      weightedFrequency += frequency * magnitude;
      if (frequency >= 2000) highEnergy += magnitude;
      accumulated += magnitude;
      if (rolloffHz == 0 && accumulated >= rolloffTarget) {
        rolloffHz = frequency;
      }
    }

    final centroid = weightedFrequency / total;
    final flatness = _spectralFlatness(spectrum);
    final harmonicRatio = pitchHz == null || pitchHz <= 0
        ? 0.0
        : _harmonicRatio(spectrum, binHz, pitchHz);
    final overtoneRatio = pitchHz == null || pitchHz <= 0
        ? 0.0
        : _overtoneRatio(spectrum, binHz, pitchHz);
    final brightness = clampUnit((centroid - 550) / 2850);
    final richness = clampUnit(overtoneRatio * 1.5 + highEnergy / total * 0.35);
    final noise = clampUnit(flatness * 2.4);
    final bands = _spectrumBands(spectrum);

    return TimbreProfile(
      rms: rms,
      peak: peak,
      spectralCentroidHz: centroid,
      spectralRolloffHz: rolloffHz,
      spectralFlatness: flatness,
      harmonicRatio: harmonicRatio,
      brightness: brightness,
      richness: richness,
      noise: noise,
      spectrumBands: bands,
      label: _labelFor(
        brightness: brightness,
        richness: richness,
        noise: noise,
      ),
    );
  }

  TimbreProfile _empty() {
    return TimbreProfile(
      rms: 0,
      peak: 0,
      spectralCentroidHz: 0,
      spectralRolloffHz: 0,
      spectralFlatness: 0,
      harmonicRatio: 0,
      brightness: 0,
      richness: 0,
      noise: 0,
      spectrumBands: List<double>.filled(bandCount, 0),
      label: '等待输入',
    );
  }

  List<double> _prepareFrame(List<double> samples) {
    final size = _previousPowerOfTwo(samples.length);
    final start = samples.length - size;
    final mean =
        samples.fold<double>(0, (sum, value) => sum + value) / samples.length;
    return List<double>.generate(size, (index) {
      final window = 0.5 - 0.5 * math.cos(2 * math.pi * index / (size - 1));
      return (samples[start + index] - mean) * window;
    });
  }

  int _previousPowerOfTwo(int value) {
    var size = 1;
    while (size * 2 <= value) {
      size *= 2;
    }
    return math.max(64, size);
  }

  List<double> _fftMagnitudes(List<double> frame) {
    final n = frame.length;
    final real = List<double>.of(frame);
    final imag = List<double>.filled(n, 0);

    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tempReal = real[i];
        final tempImag = imag[i];
        real[i] = real[j];
        imag[i] = imag[j];
        real[j] = tempReal;
        imag[j] = tempImag;
      }
    }

    for (var length = 2; length <= n; length <<= 1) {
      final angle = -2 * math.pi / length;
      final wLenReal = math.cos(angle);
      final wLenImag = math.sin(angle);
      for (var i = 0; i < n; i += length) {
        var wReal = 1.0;
        var wImag = 0.0;
        for (var k = 0; k < length ~/ 2; k++) {
          final evenReal = real[i + k];
          final evenImag = imag[i + k];
          final oddReal =
              real[i + k + length ~/ 2] * wReal -
              imag[i + k + length ~/ 2] * wImag;
          final oddImag =
              real[i + k + length ~/ 2] * wImag +
              imag[i + k + length ~/ 2] * wReal;
          real[i + k] = evenReal + oddReal;
          imag[i + k] = evenImag + oddImag;
          real[i + k + length ~/ 2] = evenReal - oddReal;
          imag[i + k + length ~/ 2] = evenImag - oddImag;

          final nextReal = wReal * wLenReal - wImag * wLenImag;
          wImag = wReal * wLenImag + wImag * wLenReal;
          wReal = nextReal;
        }
      }
    }

    return List<double>.generate(
      n ~/ 2,
      (index) =>
          math.sqrt(real[index] * real[index] + imag[index] * imag[index]),
    );
  }

  double _spectralFlatness(List<double> spectrum) {
    var logSum = 0.0;
    var linearSum = 0.0;
    var count = 0;
    for (var i = 1; i < spectrum.length; i++) {
      final value = spectrum[i] + 1e-12;
      logSum += math.log(value);
      linearSum += value;
      count++;
    }
    if (count == 0 || linearSum <= 0) return 0;
    final geometricMean = math.exp(logSum / count);
    final arithmeticMean = linearSum / count;
    return clampUnit(geometricMean / arithmeticMean);
  }

  double _harmonicRatio(List<double> spectrum, double binHz, double pitchHz) {
    var harmonicEnergy = 0.0;
    var totalEnergy = 0.0;
    for (var i = 1; i < spectrum.length; i++) {
      final energy = spectrum[i] * spectrum[i];
      totalEnergy += energy;
    }
    if (totalEnergy <= 0) return 0;

    for (var harmonic = 1; harmonic <= 10; harmonic++) {
      final centerBin = (pitchHz * harmonic / binHz).round();
      if (centerBin <= 0 || centerBin >= spectrum.length) break;
      for (var offset = -1; offset <= 1; offset++) {
        final bin = centerBin + offset;
        if (bin > 0 && bin < spectrum.length) {
          harmonicEnergy += spectrum[bin] * spectrum[bin];
        }
      }
    }
    return clampUnit(harmonicEnergy / totalEnergy);
  }

  double _overtoneRatio(List<double> spectrum, double binHz, double pitchHz) {
    var overtoneEnergy = 0.0;
    var totalEnergy = 0.0;
    for (var i = 1; i < spectrum.length; i++) {
      final energy = spectrum[i] * spectrum[i];
      totalEnergy += energy;
    }
    if (totalEnergy <= 0) return 0;

    for (var harmonic = 2; harmonic <= 10; harmonic++) {
      final centerBin = (pitchHz * harmonic / binHz).round();
      if (centerBin <= 0 || centerBin >= spectrum.length) break;
      for (var offset = -1; offset <= 1; offset++) {
        final bin = centerBin + offset;
        if (bin > 0 && bin < spectrum.length) {
          overtoneEnergy += spectrum[bin] * spectrum[bin];
        }
      }
    }
    return clampUnit(overtoneEnergy / totalEnergy);
  }

  List<double> _spectrumBands(List<double> spectrum) {
    if (spectrum.isEmpty) return List<double>.filled(bandCount, 0);
    final bands = List<double>.filled(bandCount, 0);
    for (var band = 0; band < bandCount; band++) {
      final start = (math.pow(spectrum.length, band / bandCount)).floor();
      final end = (math.pow(spectrum.length, (band + 1) / bandCount)).ceil();
      var sum = 0.0;
      var count = 0;
      for (
        var i = math.max(1, start);
        i < math.min(spectrum.length, end);
        i++
      ) {
        sum += spectrum[i];
        count++;
      }
      bands[band] = count == 0 ? 0 : sum / count;
    }
    final maxBand = bands.fold<double>(0, math.max);
    if (maxBand <= 0) return bands;
    return [for (final band in bands) clampUnit(band / maxBand)];
  }

  double _rms(List<double> samples) {
    var energy = 0.0;
    for (final sample in samples) {
      energy += sample * sample;
    }
    return math.sqrt(energy / samples.length);
  }

  String _labelFor({
    required double brightness,
    required double richness,
    required double noise,
  }) {
    if (noise > 0.58) return '气声偏多';
    if (brightness > 0.65 && richness > 0.58) return '明亮厚实';
    if (brightness > 0.65) return '明亮';
    if (richness > 0.62) return '泛音丰富';
    if (brightness < 0.28) return '柔和';
    return '均衡';
  }
}
