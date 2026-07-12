import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import '../../core/audio/note_playback_service.dart';
import '../../core/error/failure.dart';
import '../../domain/models/models.dart';
import '../../domain/music/key_transpose.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/repositories/score_repository.dart';
import 'dynamic_score_state.dart';
import 'dynamic_score_timeline.dart';

final currentDynamicScoreProvider = Provider<MusicSummary>((ref) {
  throw UnimplementedError('Current dynamic score must be provided by route.');
});

final dynamicScoreViewModelProvider =
    NotifierProvider<DynamicScoreViewModel, DynamicScoreState>(
      DynamicScoreViewModel.new,
      dependencies: [
        currentDynamicScoreProvider,
        scoreRepositoryProvider,
        favoritesRepositoryProvider,
        notePlaybackServiceProvider,
      ],
    );

/// 协调动态谱加载、收藏和播放状态。
final class DynamicScoreViewModel extends Notifier<DynamicScoreState> {
  late ScoreRepository _scoreRepository;
  late FavoritesRepository _favoritesRepository;
  late NotePlaybackService _audio;
  final _clock = Stopwatch();
  Timer? _timer;
  var _playbackAnchorMs = 0;
  var _lastSoundNoteIndex = -1;
  var _requestVersion = 0;

  @override
  DynamicScoreState build() {
    final summary = ref.watch(currentDynamicScoreProvider);
    _scoreRepository = ref.watch(scoreRepositoryProvider);
    _favoritesRepository = ref.watch(favoritesRepositoryProvider);
    _audio = ref.watch(notePlaybackServiceProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _clock.stop();
      unawaited(_audio.stop());
    });
    return DynamicScoreState(
      summary: summary,
      isFavorite: _favoritesRepository.contains(
        ScoreKind.dynamic,
        summary.favoriteId,
      ),
    );
  }

  Future<void> load() async {
    final request = ++_requestVersion;
    stop();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final content = await _scoreRepository.getDynamicScore(state.summary.id);
      if (request != _requestVersion) return;
      final selectedKey = content.detail.selectedKey.isEmpty
          ? content.detail.originalKey
          : content.detail.selectedKey;
      state = state.copyWith(
        content: content,
        timeline: DynamicScoreTimeline.build(content.document, content.detail),
        selectedKey: selectedKey,
        elapsedMs: 0,
        activeNoteIndex: -1,
      );
    } catch (error) {
      if (request == _requestVersion) {
        state = state.copyWith(errorMessage: _messageOf(error));
      }
    } finally {
      if (request == _requestVersion) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> toggleFavorite() async {
    final detail = state.content?.detail;
    if (detail == null) return;
    final item = FavoriteItem(
      kind: ScoreKind.dynamic,
      id: state.summary.favoriteId,
      title: detail.title,
      subtitle: [
        if (detail.singer.isNotEmpty) detail.singer,
        if (detail.arranger.isNotEmpty) '编：${detail.arranger}',
      ].join(' · '),
      scorePath: detail.scorePath,
    );
    try {
      final items = await _favoritesRepository.toggle(item);
      state = state.copyWith(
        isFavorite: items.any((value) => value.key == item.key),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _messageOf(error));
    }
  }

  void togglePlayback() {
    if (state.isPlaying) {
      _pause();
      return;
    }
    if (state.timeline.notes.isEmpty) return;
    var elapsed = state.elapsedMs;
    if (elapsed >= state.timeline.durationMs) elapsed = 0;
    _playbackAnchorMs = elapsed;
    _lastSoundNoteIndex = -1;
    _clock
      ..reset()
      ..start();
    state = state.copyWith(isPlaying: true, elapsedMs: elapsed);
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 32), (_) => _tick());
  }

  void _pause() {
    final elapsed = _playbackAnchorMs + _clock.elapsedMilliseconds;
    _timer?.cancel();
    _clock.stop();
    unawaited(_audio.stop());
    state = state.copyWith(isPlaying: false, elapsedMs: elapsed);
  }

  void stop() {
    _timer?.cancel();
    _clock
      ..stop()
      ..reset();
    _playbackAnchorMs = 0;
    _lastSoundNoteIndex = -1;
    unawaited(_audio.stop());
    if (state.isPlaying ||
        state.elapsedMs != 0 ||
        state.activeNoteIndex != -1) {
      state = state.copyWith(
        isPlaying: false,
        elapsedMs: 0,
        activeNoteIndex: -1,
      );
    }
  }

  void _tick() {
    if (!state.isPlaying) return;
    final elapsed = _playbackAnchorMs + _clock.elapsedMilliseconds;
    if (elapsed >= state.timeline.durationMs) {
      stop();
      return;
    }
    final noteIndex = state.timeline.noteIndexAt(elapsed);
    if (noteIndex != _lastSoundNoteIndex) {
      _lastSoundNoteIndex = noteIndex;
      _playNote(noteIndex);
    }
    state = state.copyWith(elapsedMs: elapsed, activeNoteIndex: noteIndex);
  }

  void _playNote(int index) {
    if (!state.soundEnabled) return;
    final note = state.timeline.noteAt(index);
    final detail = state.content?.detail;
    if (note == null || detail == null) return;
    final raw = state.rewriteNotation
        ? transposeJianpuToken(
            raw: note.raw,
            fromKey: detail.selectedKey.isEmpty
                ? detail.originalKey
                : detail.selectedKey,
            toKey: state.selectedKey,
          )
        : note.raw;
    unawaited(
      _audio.play(
        raw: raw,
        key: state.selectedKey,
        durationMs: note.endMs - note.startMs,
        program: state.instrumentProgram,
        volume: state.volume,
      ),
    );
  }

  void setZoom(double value) => state = state.copyWith(zoom: value);
  void setScrollSpeed(double value) =>
      state = state.copyWith(scrollSpeed: value);
  void setSoundEnabled(bool value) {
    state = state.copyWith(soundEnabled: value);
    if (!value) unawaited(_audio.stop());
  }

  void setRewriteNotation(bool value) =>
      state = state.copyWith(rewriteNotation: value);
  void setVolume(double value) => state = state.copyWith(volume: value);
  void setInstrumentProgram(int value) =>
      state = state.copyWith(instrumentProgram: value);
  void setSelectedKey(String value) =>
      state = state.copyWith(selectedKey: value);

  String _messageOf(Object error) => switch (error) {
    Failure failure => failure.message,
    _ => '动态谱加载失败，请稍后重试。',
  };
}
