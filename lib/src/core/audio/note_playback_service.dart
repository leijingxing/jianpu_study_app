/// 应用层使用的音符合成边界。
abstract interface class NotePlaybackService {
  Future<void> play({
    required String raw,
    required String key,
    required int durationMs,
    required int program,
    required double volume,
  });

  Future<void> stop();

  Future<void> dispose();
}
