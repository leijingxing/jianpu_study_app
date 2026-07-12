import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import 'jianpu_game_engine.dart';

final class JianpuGameState {
  const JianpuGameState({
    this.gameState = GameState.idle,
    this.score = 0,
    this.combo = 0,
    this.timeLeftMs = 0,
    this.currentNote = '',
    this.lastCorrect,
  });
  final GameState gameState;
  final int score;
  final int combo;
  final int timeLeftMs;
  final String currentNote;
  final bool? lastCorrect;
}

final jianpuGameViewModelProvider =
    NotifierProvider<JianpuGameViewModel, JianpuGameState>(
      JianpuGameViewModel.new,
      dependencies: [notePlaybackServiceProvider],
    );

final class JianpuGameViewModel extends Notifier<JianpuGameState> {
  late JianpuGameEngine _engine;
  @override
  JianpuGameState build() {
    final audio = ref.watch(notePlaybackServiceProvider);
    _engine = JianpuGameEngine(
      onPlayNote: (raw, key, duration) => audio.play(
        raw: raw,
        key: key,
        durationMs: duration,
        program: 0,
        volume: 0.75,
      ),
    )..addListener(_sync);
    ref.onDispose(() {
      _engine
        ..removeListener(_sync)
        ..dispose();
    });
    return const JianpuGameState();
  }

  void _sync() {
    state = JianpuGameState(
      gameState: _engine.state,
      score: _engine.score,
      combo: _engine.combo,
      timeLeftMs: _engine.timeLeftMs,
      currentNote: _engine.currentNoteRaw,
      lastCorrect: _engine.lastAnswerCorrect,
    );
  }

  void start() => _engine.startGame();
  void stop() => _engine.stopGame();
  void answer(String value) => _engine.submitAnswer(value);
}
