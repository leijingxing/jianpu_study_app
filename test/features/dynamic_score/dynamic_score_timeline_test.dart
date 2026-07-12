import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/domain/models/models.dart';
import 'package:jianpu_study_app/src/features/dynamic_score/dynamic_score_timeline.dart';

void main() {
  test('builds note durations from bpm and jianpu duration marks', () {
    final timeline = DynamicScoreTimeline.build(
      const ScoreDocument(
        title: '',
        composer: '',
        lyricist: '',
        notation: ['| 1 2_ 3= 4. 5-- |'],
        lyrics: [],
      ),
      _detail(bpm: 120),
    );

    expect(timeline.notes.map((note) => note.endMs - note.startMs), [
      500,
      250,
      125,
      750,
      1500,
    ]);
    expect(timeline.durationMs, 3125);
    expect(timeline.noteIndexAt(749), 1);
    expect(timeline.noteIndexAt(750), 2);
    expect(timeline.noteIndexAt(3125), -1);
  });

  test('uses a safe default tempo for invalid bpm', () {
    final timeline = DynamicScoreTimeline.build(
      const ScoreDocument(
        title: '',
        composer: '',
        lyricist: '',
        notation: ['1'],
        lyrics: [],
      ),
      _detail(bpm: 0),
    );

    expect(timeline.durationMs, 1000);
  });
}

MusicDetail _detail({required int bpm}) => MusicDetail(
  id: 1,
  title: '测试',
  originalKey: 'C',
  selectedKey: 'C',
  timeSignature: '4/4',
  bpm: bpm,
  singer: '',
  arranger: '',
  composer: '',
  lyricist: '',
  scorePath: '/score.txt',
  coverPath: '',
  times: 0,
);
