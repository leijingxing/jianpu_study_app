import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import '../../core/audio/note_playback_service.dart';
import '../../core/error/failure.dart';
import '../../domain/models/local_score.dart';
import '../../domain/repositories/local_score_repository.dart';
import 'jianpu_maker_state.dart';

final jianpuMakerViewModelProvider =
    NotifierProvider<JianpuMakerViewModel, JianpuMakerState>(
      JianpuMakerViewModel.new,
      dependencies: [localScoreRepositoryProvider, notePlaybackServiceProvider],
    );

final class JianpuMakerViewModel extends Notifier<JianpuMakerState> {
  late LocalScoreRepository _repository;
  late NotePlaybackService _audio;
  final _undo = <JianpuMakerDraft>[];
  final _redo = <JianpuMakerDraft>[];

  @override
  JianpuMakerState build() {
    _repository = ref.watch(localScoreRepositoryProvider);
    _audio = ref.watch(notePlaybackServiceProvider);
    ref.onDispose(() => unawaited(_audio.stop()));
    return JianpuMakerState(draft: JianpuMakerDraft.starter());
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      state = state.copyWith(savedScores: await _repository.getAll());
    } catch (error) {
      state = state.copyWith(message: _messageOf(error));
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void updateDraft(JianpuMakerDraft next) {
    if (identical(next, state.draft)) return;
    _undo.add(state.draft);
    _redo.clear();
    state = state.copyWith(
      draft: next,
      canUndo: true,
      canRedo: false,
      clearMessage: true,
    );
  }

  void addToken(String token) =>
      updateDraft(state.draft.copyWith(tokens: [...state.draft.tokens, token]));

  void removeLastToken() {
    if (state.draft.tokens.isEmpty) return;
    updateDraft(
      state.draft.copyWith(
        tokens: state.draft.tokens.sublist(0, state.draft.tokens.length - 1),
      ),
    );
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(state.draft);
    state = state.copyWith(
      draft: _undo.removeLast(),
      canUndo: _undo.isNotEmpty,
      canRedo: true,
    );
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(state.draft);
    state = state.copyWith(
      draft: _redo.removeLast(),
      canUndo: true,
      canRedo: _redo.isNotEmpty,
    );
  }

  Future<void> save() async {
    state = state.copyWith(isSaving: true, clearMessage: true);
    try {
      final saved = await _repository.save(
        state.draft,
        existingId: state.currentId,
      );
      state = state.copyWith(
        currentId: saved.id,
        savedScores: await _repository.getAll(),
        message: '已保存',
      );
    } catch (error) {
      state = state.copyWith(message: _messageOf(error));
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  void open(LocalScore score) {
    _undo.clear();
    _redo.clear();
    state = state.copyWith(
      draft: score.draft,
      currentId: score.id,
      canUndo: false,
      canRedo: false,
      clearMessage: true,
    );
  }

  void newDraft() {
    _undo.clear();
    _redo.clear();
    state = state.copyWith(
      draft: JianpuMakerDraft.starter(),
      clearCurrentId: true,
      canUndo: false,
      canRedo: false,
    );
  }

  Future<void> delete(String id) async {
    try {
      final values = await _repository.delete(id);
      state = state.copyWith(
        savedScores: values,
        clearCurrentId: state.currentId == id,
        message: '已删除',
      );
    } catch (error) {
      state = state.copyWith(message: _messageOf(error));
    }
  }

  Future<void> preview(String token) => _audio.play(
    raw: token,
    key: state.draft.keyName,
    durationMs: 420,
    program: 73,
    volume: 0.7,
  );

  String _messageOf(Object error) => switch (error) {
    Failure failure => failure.message,
    _ => '本地乐谱操作失败。',
  };
}
