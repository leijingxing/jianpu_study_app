import '../../../audio/tone_synth.dart';
import '../../../core/audio/note_playback_service.dart';

/// 使用应用内 ToneSynth 实现音符播放。
final class ToneNotePlaybackService implements NotePlaybackService {
  ToneNotePlaybackService({ToneSynth? synth}) : _synth = synth ?? ToneSynth();

  final ToneSynth _synth;

  @override
  Future<void> play({
    required String raw,
    required String key,
    required int durationMs,
    required int program,
    required double volume,
  }) => _synth.playNote(
    raw: raw,
    key: key,
    durationMs: durationMs,
    program: program,
    volume: volume,
  );

  @override
  Future<void> stop() => _synth.stopNotes();

  @override
  Future<void> dispose() => _synth.dispose();
}
