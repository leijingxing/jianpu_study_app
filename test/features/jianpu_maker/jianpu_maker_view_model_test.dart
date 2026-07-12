import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/app/app_dependencies.dart';
import 'package:jianpu_study_app/src/core/audio/note_playback_service.dart';
import 'package:jianpu_study_app/src/domain/models/local_score.dart';
import 'package:jianpu_study_app/src/domain/repositories/local_score_repository.dart';
import 'package:jianpu_study_app/src/features/jianpu_maker/jianpu_maker_view_model.dart';

void main() {
  test('editing supports undo, redo, and repository save', () async {
    final repository = _Repository();
    final container = ProviderContainer(
      overrides: [
        localScoreRepositoryProvider.overrideWithValue(repository),
        notePlaybackServiceProvider.overrideWithValue(_Audio()),
      ],
    );
    addTearDown(container.dispose);
    final viewModel = container.read(jianpuMakerViewModelProvider.notifier);

    viewModel.addToken('1');
    viewModel.addToken('2');
    viewModel.undo();
    expect(container.read(jianpuMakerViewModelProvider).draft.tokens, ['1']);
    viewModel.redo();
    await viewModel.save();

    expect(repository.values.single.draft.tokens, ['1', '2']);
    expect(container.read(jianpuMakerViewModelProvider).message, '已保存');
  });
}

final class _Repository implements LocalScoreRepository {
  final values = <LocalScore>[];
  @override
  Future<List<LocalScore>> getAll() async => List.unmodifiable(values);
  @override
  Future<LocalScore> save(JianpuMakerDraft draft, {String? existingId}) async {
    final now = DateTime(2026);
    final value = LocalScore(
      id: existingId ?? 'local-1',
      draft: draft,
      createdAt: now,
      updatedAt: now,
    );
    values
      ..removeWhere((item) => item.id == value.id)
      ..add(value);
    return value;
  }

  @override
  Future<List<LocalScore>> delete(String id) async {
    values.removeWhere((item) => item.id == id);
    return getAll();
  }
}

final class _Audio implements NotePlaybackService {
  @override
  Future<void> dispose() async {}
  @override
  Future<void> play({
    required String raw,
    required String key,
    required int durationMs,
    required int program,
    required double volume,
  }) async {}
  @override
  Future<void> stop() async {}
}
