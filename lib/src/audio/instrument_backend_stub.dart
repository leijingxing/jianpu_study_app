class PlatformInstrumentBackend {
  Future<bool> playMidiNote({
    required int midi,
    required int durationMs,
    required double volume,
    required int program,
  }) async {
    return false;
  }

  Future<void> dispose() async {}
}
