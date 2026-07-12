import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import '../../core/audio/note_playback_service.dart';

final class MetronomeState {
  const MetronomeState({
    this.bpm = 100,
    this.beatsPerBar = 4,
    this.beat = 0,
    this.isRunning = false,
  });
  final int bpm;
  final int beatsPerBar;
  final int beat;
  final bool isRunning;

  MetronomeState copyWith({
    int? bpm,
    int? beatsPerBar,
    int? beat,
    bool? isRunning,
  }) => MetronomeState(
    bpm: bpm ?? this.bpm,
    beatsPerBar: beatsPerBar ?? this.beatsPerBar,
    beat: beat ?? this.beat,
    isRunning: isRunning ?? this.isRunning,
  );
}

final metronomeViewModelProvider =
    NotifierProvider<MetronomeViewModel, MetronomeState>(
      MetronomeViewModel.new,
      dependencies: [notePlaybackServiceProvider],
    );

final class MetronomeViewModel extends Notifier<MetronomeState> {
  late NotePlaybackService _audio;
  Timer? _timer;
  final _taps = <DateTime>[];

  @override
  MetronomeState build() {
    _audio = ref.watch(notePlaybackServiceProvider);
    ref.onDispose(() => _timer?.cancel());
    return const MetronomeState();
  }

  void toggle() => state.isRunning ? stop() : start();

  void start() {
    _timer?.cancel();
    state = state.copyWith(isRunning: true, beat: 0);
    _tick();
    _timer = Timer.periodic(
      Duration(milliseconds: (60000 / state.bpm).round()),
      (_) => _tick(),
    );
  }

  void stop() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false, beat: 0);
  }

  void _tick() {
    final next = state.beat % state.beatsPerBar + 1;
    state = state.copyWith(beat: next);
    _audio.play(
      raw: next == 1 ? '5' : '1',
      key: 'C',
      durationMs: 80,
      program: 115,
      volume: next == 1 ? 0.9 : 0.55,
    );
  }

  void setBpm(int value) {
    state = state.copyWith(bpm: value.clamp(30, 240));
    if (state.isRunning) start();
  }

  void setBeatsPerBar(int value) {
    state = state.copyWith(beatsPerBar: value.clamp(2, 12), beat: 0);
  }

  void tapTempo() {
    final now = DateTime.now();
    _taps.removeWhere((tap) => now.difference(tap).inSeconds > 3);
    _taps.add(now);
    if (_taps.length < 2) return;
    final intervals = <int>[];
    for (var i = 1; i < _taps.length; i++) {
      intervals.add(_taps[i].difference(_taps[i - 1]).inMilliseconds);
    }
    final average = intervals.reduce((a, b) => a + b) / intervals.length;
    setBpm((60000 / average).round());
  }
}
