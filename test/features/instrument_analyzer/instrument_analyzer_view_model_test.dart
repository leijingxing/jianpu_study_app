import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/app/app_dependencies.dart';
import 'package:jianpu_study_app/src/audio/analyzer/instrument_audio_input_base.dart';
import 'package:jianpu_study_app/src/features/instrument_analyzer/instrument_analyzer_view_model.dart';

void main() {
  test('starts, consumes frames, and releases microphone input', () async {
    final input = _Input();
    final container = ProviderContainer(
      overrides: [instrumentAudioInputProvider.overrideWithValue(input)],
    );
    addTearDown(container.dispose);
    final viewModel = container.read(
      instrumentAnalyzerViewModelProvider.notifier,
    );

    await viewModel.start();
    input.controller.add(List.filled(2048, 0));
    await Future<void>.delayed(Duration.zero);

    expect(input.startCalls, 1);
    expect(
      container.read(instrumentAnalyzerViewModelProvider).status,
      AnalyzerStatus.listening,
    );
    await viewModel.stop();
    expect(input.stopCalls, 1);
  });
}

final class _Input implements InstrumentAudioInput {
  final controller = StreamController<List<double>>.broadcast();
  var startCalls = 0;
  var stopCalls = 0;
  @override
  Stream<List<double>> get frames => controller.stream;
  @override
  bool get isSupported => true;
  @override
  int get sampleRate => 44100;
  @override
  Future<void> start({int frameSize = 2048}) async => startCalls++;
  @override
  Future<void> stop() async => stopCalls++;
  @override
  Future<void> dispose() => controller.close();
}
