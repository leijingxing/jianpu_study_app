import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../data/key_transpose.dart';

class ToneSynth {
  ToneSynth() {
    for (final player in _players) {
      player.setReleaseMode(ReleaseMode.stop);
    }
  }

  final _players = List.generate(4, (_) => AudioPlayer());
  var _nextPlayer = 0;

  Future<void> playNote({
    required String raw,
    required String key,
    required int durationMs,
    double volume = 0.7,
  }) async {
    final frequency = frequencyForJianpu(raw: raw, key: key);
    if (frequency == null || volume <= 0) return;

    final player = _players[_nextPlayer];
    _nextPlayer = (_nextPlayer + 1) % _players.length;
    await player.stop();
    await player.setVolume(volume.clamp(0, 1));
    await player.play(
      BytesSource(_buildWav(frequency, durationMs.clamp(90, 1400))),
    );
  }

  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
  }

  static double? frequencyForJianpu({
    required String raw,
    required String key,
  }) {
    final match = RegExp(r'[0-7]').firstMatch(raw);
    if (match == null) return null;
    final degree = int.parse(match.group(0)!);
    if (degree == 0) return null;

    final tonic = keySemitone(key);
    final accidental = raw.contains('#') || raw.contains('♯')
        ? 1
        : (raw.contains('b') || raw.contains('♭') ? -1 : 0);
    final semitone = tonic + const [0, 0, 2, 4, 5, 7, 9, 11][degree];
    final octaveShift = "'".allMatches(raw).length - ','.allMatches(raw).length;
    final midi = 60 + semitone + accidental + octaveShift * 12;
    return (440 * math.pow(2, (midi - 69) / 12)).toDouble();
  }

  Uint8List _buildWav(double frequency, int durationMs) {
    const sampleRate = 44100;
    const channelCount = 1;
    const bitsPerSample = 16;
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final dataSize = sampleCount * channelCount * bitsPerSample ~/ 8;
    final bytes = ByteData(44 + dataSize);

    void writeString(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channelCount, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(
      28,
      sampleRate * channelCount * bitsPerSample ~/ 8,
      Endian.little,
    );
    bytes.setUint16(32, channelCount * bitsPerSample ~/ 8, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeString(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final progress = i / sampleCount;
      final attack = math.min(1.0, progress / 0.08);
      final release = math.min(1.0, (1 - progress) / 0.22);
      final envelope = math.max(0, math.min(attack, release));
      final wave =
          math.sin(2 * math.pi * frequency * t) * 0.62 +
          math.sin(2 * math.pi * frequency * 2 * t) * 0.22 +
          math.sin(2 * math.pi * frequency * 3 * t) * 0.10 +
          math.sin(2 * math.pi * frequency * 0.5 * t) * 0.05;
      final sample = (wave * envelope * 24000).round().clamp(-32768, 32767);
      bytes.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }
}
