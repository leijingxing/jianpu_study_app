import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/pro/jianpu_local_score_store.dart';
import 'package:jianpu_study_app/src/pro/jianpu_maker_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saves, reloads, updates, and deletes local jianpu scores', () async {
    SharedPreferences.setMockInitialValues({});
    final store = JianpuLocalScoreStore();
    final draft = JianpuMakerDraft.starter();

    final saved = await store.saveDraft(draft: draft);
    expect(store.items, hasLength(1));
    expect(store.items.single.id, saved.id);

    final reloaded = JianpuLocalScoreStore();
    await reloaded.load();
    expect(reloaded.items.single.title, draft.title);

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
    await reloaded.saveDraft(draft: updatedDraft, existingId: saved.id);
    expect(reloaded.items, hasLength(1));
    expect(reloaded.items.single.title, '新标题');

    await reloaded.delete(saved.id);
    expect(reloaded.items, isEmpty);
  });
}
