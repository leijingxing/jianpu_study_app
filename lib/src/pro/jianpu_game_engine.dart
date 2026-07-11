import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/tone_synth.dart';

enum GameState { idle, playing, gameOver }

class JianpuGameEngine extends ChangeNotifier {
  JianpuGameEngine({this.onPlayNote});

  final void Function(String raw, String key, int durationMs)? onPlayNote;

  GameState _state = GameState.idle;
  GameState get state => _state;

  int _score = 0;
  int get score => _score;

  int _combo = 0;
  int get combo => _combo;

  int _maxCombo = 0;
  int get maxCombo => _maxCombo;

  int _timeLeftMs = 0;
  int get timeLeftMs => _timeLeftMs;

  static const int gameDurationMs = 60 * 1000;
  static const int tickIntervalMs = 50;
  
  String _currentNoteRaw = '';
  String get currentNoteRaw => _currentNoteRaw;
  
  // Track correctness for UI animation
  bool? _lastAnswerCorrect;
  bool? get lastAnswerCorrect => _lastAnswerCorrect;

  Timer? _timer;
  final _random = Random();

  void startGame() {
    _state = GameState.playing;
    _score = 0;
    _combo = 0;
    _maxCombo = 0;
    _timeLeftMs = gameDurationMs;
    _lastAnswerCorrect = null;
    _nextNote();
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: tickIntervalMs),
      _tick,
    );
    notifyListeners();
  }

  void stopGame() {
    _timer?.cancel();
    _timer = null;
    _state = GameState.idle;
    notifyListeners();
  }

  void _tick(Timer timer) {
    if (_state != GameState.playing) return;
    _timeLeftMs -= tickIntervalMs;
    if (_timeLeftMs <= 0) {
      _timeLeftMs = 0;
      _state = GameState.gameOver;
      _timer?.cancel();
    }
    notifyListeners();
  }

  void submitAnswer(String answerNumber) {
    if (_state != GameState.playing) return;

    final correctNumber = _extractBaseNumber(_currentNoteRaw);
    final correct = answerNumber == correctNumber;
    _lastAnswerCorrect = correct;

    if (correct) {
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      _score += 10 + (_combo * 5); // Combo multiplier
      
      // Play note
      onPlayNote?.call(_currentNoteRaw, 'C', 400);
      
      _nextNote();
    } else {
      _combo = 0;
      // You can add a subtle vibration or error sound here later
    }
    notifyListeners();
    
    // Clear the correctness flag after a short delay so animation can reset
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_lastAnswerCorrect != null) {
        _lastAnswerCorrect = null;
        notifyListeners();
      }
    });
  }

  void _nextNote() {
    const baseNotes = ['1', '2', '3', '4', '5', '6', '7'];
    String note = baseNotes[_random.nextInt(baseNotes.length)];
    
    // Randomly add modifiers for difficulty based on combo/score
    if (_combo >= 10) {
      // Add sharp/flat occasionally
      if (_random.nextDouble() < 0.2) {
        note = '#$note';
      } else if (_random.nextDouble() < 0.1 && note != '1' && note != '4') {
        note = 'b$note';
      }
    }
    
    if (_combo >= 5) {
      // Add octave dots
      final r = _random.nextDouble();
      if (r < 0.2) {
        note = '$note.'; // high
      } else if (r < 0.4) {
        note = '.$note'; // low
      }
    }
    
    _currentNoteRaw = note;
  }

  String _extractBaseNumber(String raw) {
    final match = RegExp(r'[1-7]').firstMatch(raw);
    return match?.group(0) ?? '1';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
