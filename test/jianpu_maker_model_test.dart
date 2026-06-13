import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/pro/jianpu_maker_model.dart';

void main() {
  test('starter draft starts with an empty editable score', () {
    final draft = JianpuMakerDraft.starter();

    expect(draft.tokens, isEmpty);
    expect(draft.toDocument().notation, isEmpty);
  });

  test(
    'builds touch-friendly jianpu tokens with octave and duration marks',
    () {
      expect(
        buildJianpuToken(
          degree: '5',
          octave: -1,
          duration: JianpuNoteDuration.eighth,
        ),
        '5,_',
      );
      expect(
        buildJianpuToken(
          degree: '1',
          octave: 2,
          duration: JianpuNoteDuration.half,
        ),
        "1''-",
      );
      expect(
        buildJianpuToken(
          degree: '0',
          octave: 2,
          duration: JianpuNoteDuration.dotted,
        ),
        '0.',
      );
    },
  );

  test('draft converts tokens into preview document and detail', () {
    final draft = JianpuMakerDraft(
      title: '测试曲',
      singer: '演唱者',
      composer: '作曲',
      lyricist: '作词',
      arranger: '编配',
      keyName: 'D',
      timeSignature: '3/4',
      bpm: 96,
      tokens: const ['|', '1', '2', '3', '|', '5', '6', '5', '|'],
      lyricsText: '春 风 来 了',
    );

    final document = draft.toDocument();
    final detail = draft.toDetail();

    expect(document.title, '测试曲');
    expect(document.notation, ['| 1 2 3 | 5 6 5 |']);
    expect(document.lyrics, ['春', '风', '来', '了']);
    expect(detail.selectedKey, 'D');
    expect(detail.timeSignature, '3/4');
    expect(detail.bpm, 96);
  });
}
