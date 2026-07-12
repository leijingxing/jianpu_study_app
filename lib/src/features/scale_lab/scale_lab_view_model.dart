import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import '../../core/audio/note_playback_service.dart';

final class ScaleLabState {
  const ScaleLabState({this.keyName = 'C', this.octave = 0, this.activeDegree});
  final String keyName;
  final int octave;
  final int? activeDegree;
  ScaleLabState copyWith({
    String? keyName,
    int? octave,
    int? activeDegree,
    bool clear = false,
  }) => ScaleLabState(
    keyName: keyName ?? this.keyName,
    octave: octave ?? this.octave,
    activeDegree: clear ? null : activeDegree ?? this.activeDegree,
  );
}

final scaleLabViewModelProvider =
    NotifierProvider<ScaleLabViewModel, ScaleLabState>(
      ScaleLabViewModel.new,
      dependencies: [notePlaybackServiceProvider],
    );

final class ScaleLabViewModel extends Notifier<ScaleLabState> {
  late NotePlaybackService _audio;
  @override
  ScaleLabState build() {
    _audio = ref.watch(notePlaybackServiceProvider);
    return const ScaleLabState();
  }

  void setKey(String value) => state = state.copyWith(keyName: value);
  void setOctave(int value) =>
      state = state.copyWith(octave: value.clamp(-2, 2));
  Future<void> play(int degree) async {
    state = state.copyWith(activeDegree: degree);
    final mark = state.octave < 0
        ? List.filled(-state.octave, ',').join()
        : List.filled(state.octave, "'").join();
    await _audio.play(
      raw: '$degree$mark',
      key: state.keyName,
      durationMs: 520,
      program: 0,
      volume: 0.75,
    );
  }
}
