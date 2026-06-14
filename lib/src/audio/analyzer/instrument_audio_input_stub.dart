import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'instrument_audio_input_base.dart';

InstrumentAudioInput createInstrumentAudioInput() => _RecordAudioInput();

class _RecordAudioInput implements InstrumentAudioInput {
  final _recorder = AudioRecorder();
  final _controller = StreamController<List<double>>.broadcast();
  StreamSubscription<Uint8List>? _subscription;
  var _isDisposed = false;

  @override
  bool get isSupported => !_isDisposed;

  @override
  int get sampleRate => 44100;

  @override
  Stream<List<double>> get frames => _controller.stream;

  @override
  Future<void> start({int frameSize = 2048}) async {
    if (_isDisposed) return;
    await stop();
    final granted = await _recorder.hasPermission();
    if (!granted) {
      throw StateError('未获得麦克风权限');
    }

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
        echoCancel: false,
        noiseSuppress: false,
        autoGain: false,
      ),
    );
    _subscription = stream.listen(
      (chunk) => _controller.add(_pcm16ToDouble(chunk)),
      onError: _controller.addError,
    );
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (!_isDisposed && await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    _isDisposed = true;
    await _recorder.dispose();
    await _controller.close();
  }

  List<double> _pcm16ToDouble(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    final data = ByteData.sublistView(bytes);
    return List<double>.generate(sampleCount, (index) {
      final value = data.getInt16(index * 2, Endian.little);
      return value / 32768.0;
    }, growable: false);
  }
}
