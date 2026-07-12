import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import '../../audio/analyzer/analysis_models.dart';
import '../../audio/analyzer/instrument_analyzer.dart';
import '../../audio/analyzer/instrument_audio_input_base.dart';

enum AnalyzerStatus { idle, listening, failure }

final class InstrumentAnalyzerState {
  const InstrumentAnalyzerState({
    this.status = AnalyzerStatus.idle,
    this.result,
    this.message,
  });
  final AnalyzerStatus status;
  final InstrumentAnalysisResult? result;
  final String? message;
}

final instrumentAnalyzerViewModelProvider =
    NotifierProvider<InstrumentAnalyzerViewModel, InstrumentAnalyzerState>(
      InstrumentAnalyzerViewModel.new,
      dependencies: [instrumentAudioInputProvider],
    );

final class InstrumentAnalyzerViewModel
    extends Notifier<InstrumentAnalyzerState> {
  late InstrumentAudioInput _input;
  final _analyzer = InstrumentAnalyzer();
  StreamSubscription<List<double>>? _subscription;

  @override
  InstrumentAnalyzerState build() {
    _input = ref.watch(instrumentAudioInputProvider);
    ref.onDispose(() {
      _subscription?.cancel();
      unawaited(_input.stop());
    });
    return const InstrumentAnalyzerState();
  }

  Future<void> start() async {
    if (!_input.isSupported) {
      state = const InstrumentAnalyzerState(
        status: AnalyzerStatus.failure,
        message: '当前平台不支持麦克风分析。',
      );
      return;
    }
    try {
      await _subscription?.cancel();
      _subscription = _input.frames.listen(
        (frame) {
          final result = _analyzer.analyze(frame, _input.sampleRate);
          state = InstrumentAnalyzerState(
            status: AnalyzerStatus.listening,
            result: result,
          );
        },
        onError: (Object error) {
          state = InstrumentAnalyzerState(
            status: AnalyzerStatus.failure,
            message: '$error',
          );
        },
      );
      await _input.start();
      state = const InstrumentAnalyzerState(status: AnalyzerStatus.listening);
    } catch (error) {
      state = InstrumentAnalyzerState(
        status: AnalyzerStatus.failure,
        message: '$error',
      );
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _input.stop();
    _analyzer.reset();
    state = const InstrumentAnalyzerState();
  }
}
