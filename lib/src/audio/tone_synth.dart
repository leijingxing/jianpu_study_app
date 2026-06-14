import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'instrument_backend.dart';
import '../data/key_transpose.dart';
import '../data/models.dart';

class ToneSynth {
  ToneSynth() {
    for (final player in [..._notePlayers, ..._clickPlayers]) {
      player.setReleaseMode(ReleaseMode.stop);
    }
  }

  final _notePlayers = List.generate(5, (_) => AudioPlayer());
  final _clickPlayers = List.generate(3, (_) => AudioPlayer());
  final _instrument = PlatformInstrumentBackend();
  var _nextNotePlayer = 0;
  var _nextClickPlayer = 0;

  Future<void> playNote({
    required String raw,
    required String key,
    required int durationMs,
    int program = MelodyInstrument.defaultProgram,
    double volume = 0.7,
  }) async {
    final playableRaw = mainJianpuToken(raw);
    final frequency = frequencyForJianpu(raw: playableRaw, key: key);
    if (frequency == null || volume <= 0) return;

    final midi = midiNoteForJianpu(raw: playableRaw, key: key);
    if (midi != null) {
      final played = await _instrument.playMidiNote(
        midi: midi,
        durationMs: durationMs,
        volume: volume,
        program: program,
      );
      if (played) return;
    }

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
    await _instrument.dispose();
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

  static int? midiNoteForJianpu({required String raw, required String key}) {
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
    return 60 + semitone + accidental + octaveShift * 12;
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

class MelodyInstrument {
  const MelodyInstrument({
    required this.name,
    required this.program,
    required this.group,
  });

  static const defaultProgram = 73;

  final String name;
  final int program;
  final String group;
}

const melodyInstruments = [
  MelodyInstrument(name: '原声钢琴', program: 0, group: '钢琴'),
  MelodyInstrument(name: '明亮钢琴', program: 1, group: '钢琴'),
  MelodyInstrument(name: '电平台钢琴', program: 2, group: '钢琴'),
  MelodyInstrument(name: '酒吧钢琴', program: 3, group: '钢琴'),
  MelodyInstrument(name: '电钢琴 1', program: 4, group: '钢琴'),
  MelodyInstrument(name: '电钢琴 2', program: 5, group: '钢琴'),
  MelodyInstrument(name: '羽管键琴', program: 6, group: '钢琴'),
  MelodyInstrument(name: '击弦古钢琴', program: 7, group: '钢琴'),
  MelodyInstrument(name: '钢片琴', program: 8, group: '打击键盘'),
  MelodyInstrument(name: '钟琴', program: 9, group: '打击键盘'),
  MelodyInstrument(name: '八音盒', program: 10, group: '打击键盘'),
  MelodyInstrument(name: '颤音琴', program: 11, group: '打击键盘'),
  MelodyInstrument(name: '马林巴', program: 12, group: '打击键盘'),
  MelodyInstrument(name: '木琴', program: 13, group: '打击键盘'),
  MelodyInstrument(name: '管钟', program: 14, group: '打击键盘'),
  MelodyInstrument(name: '扬琴', program: 15, group: '打击键盘'),
  MelodyInstrument(name: '拉杆风琴', program: 16, group: '风琴'),
  MelodyInstrument(name: '打击风琴', program: 17, group: '风琴'),
  MelodyInstrument(name: '摇滚风琴', program: 18, group: '风琴'),
  MelodyInstrument(name: '教堂管风琴', program: 19, group: '风琴'),
  MelodyInstrument(name: '簧风琴', program: 20, group: '风琴'),
  MelodyInstrument(name: '手风琴', program: 21, group: '风琴'),
  MelodyInstrument(name: '口琴', program: 22, group: '簧片'),
  MelodyInstrument(name: '探戈手风琴', program: 23, group: '风琴'),
  MelodyInstrument(name: '尼龙吉他', program: 24, group: '吉他'),
  MelodyInstrument(name: '钢弦吉他', program: 25, group: '吉他'),
  MelodyInstrument(name: '爵士电吉他', program: 26, group: '吉他'),
  MelodyInstrument(name: '清音电吉他', program: 27, group: '吉他'),
  MelodyInstrument(name: '闷音电吉他', program: 28, group: '吉他'),
  MelodyInstrument(name: '过载吉他', program: 29, group: '吉他'),
  MelodyInstrument(name: '失真吉他', program: 30, group: '吉他'),
  MelodyInstrument(name: '吉他泛音', program: 31, group: '吉他'),
  MelodyInstrument(name: '原声贝司', program: 32, group: '贝司'),
  MelodyInstrument(name: '指弹贝司', program: 33, group: '贝司'),
  MelodyInstrument(name: '拨片贝司', program: 34, group: '贝司'),
  MelodyInstrument(name: '无品贝司', program: 35, group: '贝司'),
  MelodyInstrument(name: '拍弦贝司 1', program: 36, group: '贝司'),
  MelodyInstrument(name: '拍弦贝司 2', program: 37, group: '贝司'),
  MelodyInstrument(name: '合成贝司 1', program: 38, group: '贝司'),
  MelodyInstrument(name: '合成贝司 2', program: 39, group: '贝司'),
  MelodyInstrument(name: '小提琴', program: 40, group: '弦乐'),
  MelodyInstrument(name: '中提琴', program: 41, group: '弦乐'),
  MelodyInstrument(name: '大提琴', program: 42, group: '弦乐'),
  MelodyInstrument(name: '低音提琴', program: 43, group: '弦乐'),
  MelodyInstrument(name: '颤音弦乐', program: 44, group: '弦乐'),
  MelodyInstrument(name: '拨弦', program: 45, group: '弦乐'),
  MelodyInstrument(name: '竖琴', program: 46, group: '弦乐'),
  MelodyInstrument(name: '定音鼓', program: 47, group: '弦乐'),
  MelodyInstrument(name: '弦乐合奏 1', program: 48, group: '合奏'),
  MelodyInstrument(name: '弦乐合奏 2', program: 49, group: '合奏'),
  MelodyInstrument(name: '合成弦乐 1', program: 50, group: '合奏'),
  MelodyInstrument(name: '合成弦乐 2', program: 51, group: '合奏'),
  MelodyInstrument(name: '人声合唱', program: 52, group: '人声'),
  MelodyInstrument(name: '啊声合唱', program: 53, group: '人声'),
  MelodyInstrument(name: '合成人声', program: 54, group: '人声'),
  MelodyInstrument(name: '乐队齐奏', program: 55, group: '合奏'),
  MelodyInstrument(name: '小号', program: 56, group: '铜管'),
  MelodyInstrument(name: '长号', program: 57, group: '铜管'),
  MelodyInstrument(name: '大号', program: 58, group: '铜管'),
  MelodyInstrument(name: '弱音小号', program: 59, group: '铜管'),
  MelodyInstrument(name: '圆号', program: 60, group: '铜管'),
  MelodyInstrument(name: '铜管组', program: 61, group: '铜管'),
  MelodyInstrument(name: '合成铜管 1', program: 62, group: '铜管'),
  MelodyInstrument(name: '合成铜管 2', program: 63, group: '铜管'),
  MelodyInstrument(name: '高音萨克斯', program: 64, group: '萨克斯'),
  MelodyInstrument(name: '中音萨克斯', program: 65, group: '萨克斯'),
  MelodyInstrument(name: '次中音萨克斯', program: 66, group: '萨克斯'),
  MelodyInstrument(name: '上低音萨克斯', program: 67, group: '萨克斯'),
  MelodyInstrument(name: '双簧管', program: 68, group: '管乐'),
  MelodyInstrument(name: '英国管', program: 69, group: '管乐'),
  MelodyInstrument(name: '巴松管', program: 70, group: '管乐'),
  MelodyInstrument(name: '单簧管', program: 71, group: '管乐'),
  MelodyInstrument(name: '短笛', program: 72, group: '管乐'),
  MelodyInstrument(name: '长笛', program: 73, group: '管乐'),
  MelodyInstrument(name: '竖笛', program: 74, group: '管乐'),
  MelodyInstrument(name: '排笛', program: 75, group: '管乐'),
  MelodyInstrument(name: '吹瓶', program: 76, group: '管乐'),
  MelodyInstrument(name: '尺八', program: 77, group: '管乐'),
  MelodyInstrument(name: '口哨', program: 78, group: '管乐'),
  MelodyInstrument(name: '陶笛', program: 79, group: '管乐'),
  MelodyInstrument(name: '方波主音', program: 80, group: '合成主音'),
  MelodyInstrument(name: '锯齿主音', program: 81, group: '合成主音'),
  MelodyInstrument(name: '风琴主音', program: 82, group: '合成主音'),
  MelodyInstrument(name: '合成笛主音', program: 83, group: '合成主音'),
  MelodyInstrument(name: '变调主音', program: 84, group: '合成主音'),
  MelodyInstrument(name: '人声主音', program: 85, group: '合成主音'),
  MelodyInstrument(name: '五度主音', program: 86, group: '合成主音'),
  MelodyInstrument(name: '贝司主音', program: 87, group: '合成主音'),
  MelodyInstrument(name: '新时代音垫', program: 88, group: '合成音垫'),
  MelodyInstrument(name: '柔和音垫', program: 89, group: '合成音垫'),
  MelodyInstrument(name: '多声音垫', program: 90, group: '合成音垫'),
  MelodyInstrument(name: '合唱音垫', program: 91, group: '合成音垫'),
  MelodyInstrument(name: '弓弦音垫', program: 92, group: '合成音垫'),
  MelodyInstrument(name: '金属音垫', program: 93, group: '合成音垫'),
  MelodyInstrument(name: '光环音垫', program: 94, group: '合成音垫'),
  MelodyInstrument(name: '扫频音垫', program: 95, group: '合成音垫'),
  MelodyInstrument(name: '雨声效果', program: 96, group: '合成效果'),
  MelodyInstrument(name: '音轨效果', program: 97, group: '合成效果'),
  MelodyInstrument(name: '水晶效果', program: 98, group: '合成效果'),
  MelodyInstrument(name: '氛围效果', program: 99, group: '合成效果'),
  MelodyInstrument(name: '明亮效果', program: 100, group: '合成效果'),
  MelodyInstrument(name: '奇幻效果', program: 101, group: '合成效果'),
  MelodyInstrument(name: '回声效果', program: 102, group: '合成效果'),
  MelodyInstrument(name: '科幻效果', program: 103, group: '合成效果'),
  MelodyInstrument(name: '西塔琴', program: 104, group: '民族乐器'),
  MelodyInstrument(name: '班卓琴', program: 105, group: '民族乐器'),
  MelodyInstrument(name: '三味线', program: 106, group: '民族乐器'),
  MelodyInstrument(name: '筝', program: 107, group: '民族乐器'),
  MelodyInstrument(name: '卡林巴', program: 108, group: '民族乐器'),
  MelodyInstrument(name: '风笛', program: 109, group: '民族乐器'),
  MelodyInstrument(name: '民间提琴', program: 110, group: '民族乐器'),
  MelodyInstrument(name: '唢呐', program: 111, group: '民族乐器'),
  MelodyInstrument(name: '叮当铃', program: 112, group: '打击效果'),
  MelodyInstrument(name: '阿哥哥鼓', program: 113, group: '打击效果'),
  MelodyInstrument(name: '钢鼓', program: 114, group: '打击效果'),
  MelodyInstrument(name: '木鱼', program: 115, group: '打击效果'),
  MelodyInstrument(name: '太鼓', program: 116, group: '打击效果'),
  MelodyInstrument(name: '旋律鼓', program: 117, group: '打击效果'),
  MelodyInstrument(name: '合成鼓', program: 118, group: '打击效果'),
  MelodyInstrument(name: '反向镲', program: 119, group: '打击效果'),
  MelodyInstrument(name: '吉他品噪', program: 120, group: '声音效果'),
  MelodyInstrument(name: '呼吸声', program: 121, group: '声音效果'),
  MelodyInstrument(name: '海浪声', program: 122, group: '声音效果'),
  MelodyInstrument(name: '鸟鸣', program: 123, group: '声音效果'),
  MelodyInstrument(name: '电话铃', program: 124, group: '声音效果'),
  MelodyInstrument(name: '直升机', program: 125, group: '声音效果'),
  MelodyInstrument(name: '掌声', program: 126, group: '声音效果'),
  MelodyInstrument(name: '枪声', program: 127, group: '声音效果'),
];
