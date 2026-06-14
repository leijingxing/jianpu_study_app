abstract class InstrumentAudioInput {
  bool get isSupported;

  int get sampleRate;

  Stream<List<double>> get frames;

  Future<void> start({int frameSize = 2048});

  Future<void> stop();

  Future<void> dispose();
}
