import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import '../../core/audio/note_playback_service.dart';

enum MetronomeSubdivision {
  quarter('四分音符', 1),
  eighth('八分音符', 2),
  triplet('三连音', 3),
  sixteenth('十六分音符', 4);

  const MetronomeSubdivision(this.label, this.stepsPerBeat);

  final String label;
  final int stepsPerBeat;
}

final class MetronomeState {
  const MetronomeState({
    this.bpm = 100,
    this.beatsPerBar = 4,
    this.beat = 0,
    this.subdivisionStep = 0,
    this.subdivision = MetronomeSubdivision.quarter,
    this.isRunning = false,
    this.isMuted = false,
  });

  final int bpm;
  final int beatsPerBar;
  final int beat;
  final int subdivisionStep;
  final MetronomeSubdivision subdivision;
  final bool isRunning;
  final bool isMuted;

  MetronomeState copyWith({
    int? bpm,
    int? beatsPerBar,
    int? beat,
    int? subdivisionStep,
    MetronomeSubdivision? subdivision,
    bool? isRunning,
    bool? isMuted,
  }) => MetronomeState(
    bpm: bpm ?? this.bpm,
    beatsPerBar: beatsPerBar ?? this.beatsPerBar,
    beat: beat ?? this.beat,
    subdivisionStep: subdivisionStep ?? this.subdivisionStep,
    subdivision: subdivision ?? this.subdivision,
    isRunning: isRunning ?? this.isRunning,
    isMuted: isMuted ?? this.isMuted,
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
    state = state.copyWith(isRunning: true, beat: 0, subdivisionStep: 0);
    _tick();
    _scheduleTicks();
  }

  void stop() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false, beat: 0, subdivisionStep: 0);
    unawaited(_audio.stop());
  }

  void _scheduleTicks() {
    final steps = state.subdivision.stepsPerBeat;
    final interval = Duration(
      microseconds: (60000000 / state.bpm / steps).round(),
    );
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _rescheduleTicks() {
    if (!state.isRunning) return;
    _timer?.cancel();
    _scheduleTicks();
  }

  void _tick() {
    final steps = state.subdivision.stepsPerBeat;
    final isNewBeat = state.beat == 0 || state.subdivisionStep >= steps;
    final nextBeat = isNewBeat
        ? state.beat % state.beatsPerBar + 1
        : state.beat;
    final nextStep = isNewBeat ? 1 : state.subdivisionStep + 1;
    state = state.copyWith(beat: nextBeat, subdivisionStep: nextStep);
    if (state.isMuted) return;

    final isDownbeat = nextBeat == 1 && nextStep == 1;
    final isPrimaryBeat = nextStep == 1;
    unawaited(
      _audio.play(
        raw: isDownbeat ? '5' : '1',
        key: 'C',
        durationMs: isPrimaryBeat ? 80 : 45,
        program: 115,
        volume: isDownbeat ? 0.9 : (isPrimaryBeat ? 0.58 : 0.32),
      ),
    );
  }

  void setBpm(int value) {
    state = state.copyWith(bpm: value.clamp(30, 240));
    _rescheduleTicks();
  }

  void adjustBpm(int delta) => setBpm(state.bpm + delta);

  void setBeatsPerBar(int value) {
    state = state.copyWith(
      beatsPerBar: value.clamp(2, 12),
      beat: 0,
      subdivisionStep: 0,
    );
  }

  void setSubdivision(MetronomeSubdivision value) {
    state = state.copyWith(subdivision: value, subdivisionStep: 0);
    _rescheduleTicks();
  }

  void toggleMuted() => state = state.copyWith(isMuted: !state.isMuted);

  void tapTempo() => registerTap(DateTime.now());

  void registerTap(DateTime now) {
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
