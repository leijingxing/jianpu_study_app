import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/audio/tone_synth.dart';
import 'package:jianpu_study_app/src/pro/jianpu_game_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('JianpuGameEngine', () {
    late JianpuGameEngine engine;

    setUp(() {
      engine = JianpuGameEngine();
    });

    test('initial state is idle', () {
      expect(engine.state, GameState.idle);
      expect(engine.score, 0);
      expect(engine.combo, 0);
    });

    test('startGame sets state to playing and resets stats', () {
      engine.startGame();
      expect(engine.state, GameState.playing);
      expect(engine.timeLeftMs, 60000);
      expect(engine.currentNoteRaw, isNotEmpty);
      engine.stopGame();
    });

    test('submitAnswer increases score and combo when correct', () {
      engine.startGame();
      final currentNote = engine.currentNoteRaw;
      
      // Extract base number to simulate correct answer
      final match = RegExp(r'[1-7]').firstMatch(currentNote);
      final answer = match?.group(0) ?? '1';

      engine.submitAnswer(answer);

      expect(engine.combo, 1);
      expect(engine.score, 15); // 10 + 1 * 5
      expect(engine.maxCombo, 1);
      
      // Current note should have changed
      // (Unless random generates same note, but it works in principle)
      engine.stopGame();
    });

    test('submitAnswer resets combo when wrong', () {
      engine.startGame();
      
      // Submit a correct answer first
      final match1 = RegExp(r'[1-7]').firstMatch(engine.currentNoteRaw);
      final answer1 = match1?.group(0) ?? '1';
      engine.submitAnswer(answer1);
      expect(engine.combo, 1);

      // Submit wrong answer
      final currentNote = engine.currentNoteRaw;
      final match2 = RegExp(r'[1-7]').firstMatch(currentNote);
      final base = match2?.group(0) ?? '1';
      final wrongAnswer = base == '1' ? '2' : '1';

      engine.submitAnswer(wrongAnswer);

      expect(engine.combo, 0);
      expect(engine.maxCombo, 1); // Max combo stays
      engine.stopGame();
    });
  });
}
