import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/data/repositories/local_score_repository_impl.dart';
import 'package:jianpu_study_app/src/data/services/local/local_score_service.dart';
import 'package:jianpu_study_app/src/domain/models/local_score.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saves, reloads, updates, and deletes local jianpu scores', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalScoreRepositoryImpl(const LocalScoreService());
    final draft = JianpuMakerDraft.starter();

    final saved = await store.save(draft);
    expect(await store.getAll(), hasLength(1));

    final reloaded = LocalScoreRepositoryImpl(const LocalScoreService());
    expect((await reloaded.getAll()).single.draft.title, draft.title);

    final updatedDraft = JianpuMakerDraft(
      title: '新标题',
      singer: '',
      composer: '',
      lyricist: '',
      arranger: '',
      keyName: 'D',
      timeSignature: '3/4',
      bpm: 96,
      tokens: const ['1', '2', '|'],
      lyricsText: '',
    );
    await reloaded.save(updatedDraft, existingId: saved.id);
    expect(await reloaded.getAll(), hasLength(1));
    expect((await reloaded.getAll()).single.draft.title, '新标题');

    expect(await reloaded.delete(saved.id), isEmpty);
  });
}
