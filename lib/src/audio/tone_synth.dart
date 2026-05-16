import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../data/key_transpose.dart';

class ToneSynth {
  ToneSynth() {
    for (final player in [..._notePlayers, ..._clickPlayers]) {
      player.setReleaseMode(ReleaseMode.stop);
    }
  }

  final _notePlayers = List.generate(5, (_) => AudioPlayer());
  final _clickPlayers = List.generate(3, (_) => AudioPlayer());
  var _nextNotePlayer = 0;
  var _nextClickPlayer = 0;

  Future<void> playNote({
    required String raw,
    required String key,
    required int durationMs,
    double volume = 0.7,
  }) async {
    final frequency = frequencyForJianpu(raw: raw, key: key);
    if (frequency == null || volume <= 0) return;

    final player = _notePlayers[_nextNotePlayer];
    _nextNotePlayer = (_nextNotePlayer + 1) % _notePlayers.length;
    await player.stop();
    await player.setVolume(volume.clamp(0, 1).toDouble());
    await player.play(
      BytesSource(_buildNoteWav(frequency, durationMs.clamp(110, 720).toInt())),
    );
  }

  Future<void> playClick({required bool accented, double volume = 0.7}) async {
    if (volume <= 0) return;
    final player = _clickPlayers[_nextClickPlayer];
    _nextClickPlayer = (_nextClickPlayer + 1) % _clickPlayers.length;
    await player.stop();
    await player.setVolume(volume.clamp(0, 1).toDouble());
    await player.play(
      BytesSource(
        _buildClickWav(
          accented ? 1760 : 1120,
          accented ? 72 : 46,
          accented ? 0.92 : 0.62,
        ),
      ),
    );
  }

  Future<void> dispose() async {
    for (final player in [..._notePlayers, ..._clickPlayers]) {
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

  Uint8List _buildNoteWav(double frequency, int durationMs) {
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
      final attack = math.min(1.0, progress / 0.025);
      final decay = math.exp(-4.4 * progress);
      final release = math.min(1.0, (1 - progress) / 0.16);
      final envelope = math.max(0, math.min(attack * decay, release));
      final wave =
          math.sin(2 * math.pi * frequency * t) * 0.78 +
          math.sin(2 * math.pi * frequency * 2.01 * t) * 0.17 +
          math.sin(2 * math.pi * frequency * 3.02 * t) * 0.05;
      final sample = (wave * envelope * 21000)
          .round()
          .clamp(-32768, 32767)
          .toInt();
      bytes.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }

  Uint8List _buildClickWav(double frequency, int durationMs, double gain) {
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
      final envelope = math.pow(1 - progress, 5).toDouble();
      final noise = math.sin(2 * math.pi * frequency * 7.3 * t) * 0.12;
      final wave = math.sin(2 * math.pi * frequency * t) + noise;
      final sample = (wave * envelope * gain * 30000)
          .round()
          .clamp(-32768, 32767)
          .toInt();
      bytes.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }
}
