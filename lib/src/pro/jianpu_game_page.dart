import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/tone_synth.dart';
import '../data/app_settings.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'jianpu_game_engine.dart';

class JianpuGamePage extends StatefulWidget {
  const JianpuGamePage({super.key, required this.settings});

  static const routeName = '/game';
  final AppSettings settings;

  @override
  State<JianpuGamePage> createState() => _JianpuGamePageState();
}

class _JianpuGamePageState extends State<JianpuGamePage>
    with SingleTickerProviderStateMixin {
  late ToneSynth _synth;
  late JianpuGameEngine _engine;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _synth = ToneSynth();
    _engine = JianpuGameEngine(
      onPlayNote: (raw, key, durationMs) {
        _synth.playNote(raw: raw, key: key, durationMs: durationMs);
      },
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _engine.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (_engine.lastAnswerCorrect == false) {
      HapticFeedback.heavyImpact();
      _animController.forward(from: 0);
    } else if (_engine.lastAnswerCorrect == true) {
      _animController.forward(from: 0);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _engine.removeListener(_onGameStateChanged);
    _engine.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('读谱挑战'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildScoreBoard(palette),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: _buildMainArea(palette),
              ),
            ),
            _buildControls(palette),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBoard(QingpuPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '得分: ${_engine.score}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_engine.combo > 1)
                Text(
                  '${_engine.combo} 连击!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: palette.brand,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _engine.timeLeftMs / JianpuGameEngine.gameDurationMs,
            backgroundColor: palette.line,
            color: palette.brand,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ],
      ),
    );
  }

  Widget _buildMainArea(QingpuPalette palette) {
    if (_engine.state == GameState.idle) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.videogameAssetRounded, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            '准备好挑战你的读谱速度了吗？\n识别屏幕上的简谱，并在下方按下对应按键！',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => _engine.startGame(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              backgroundColor: palette.brand,
              foregroundColor: palette.paperTint,
            ),
            child: const Text('开始游戏', style: TextStyle(fontSize: 18)),
          ),
        ],
      );
    } else if (_engine.state == GameState.gameOver) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '游戏结束',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            '最终得分: ${_engine.score}',
            style: TextStyle(fontSize: 24, color: palette.brand),
          ),
          const SizedBox(height: 10),
          Text(
            '最高连击: ${_engine.maxCombo}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => _engine.startGame(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              backgroundColor: palette.brand,
              foregroundColor: palette.paperTint,
            ),
            child: const Text('再来一局', style: TextStyle(fontSize: 18)),
          ),
        ],
      );
    }

    // Playing state
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        Color noteColor = palette.text;
        double scale = 1.0;
        double dx = 0.0;

        if (_engine.lastAnswerCorrect == true) {
          noteColor = Colors.green;
          scale = 1.0 + (_animController.value * 0.2);
        } else if (_engine.lastAnswerCorrect == false) {
          noteColor = Colors.red;
          dx = sin(_animController.value * pi * 6) * 10;
        }

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.paper,
                boxShadow: _engine.lastAnswerCorrect == true
                    ? [BoxShadow(color: Colors.green.withAlpha(100), blurRadius: 40)]
                    : null,
              ),
              child: Text(
                _engine.currentNoteRaw,
                style: TextStyle(
                  fontSize: 100,
                  fontWeight: FontWeight.bold,
                  color: noteColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(QingpuPalette palette) {
    if (_engine.state != GameState.playing) {
      return const SizedBox(height: 100); // Placeholder
    }

    final notes = [
      {'num': '1', 'name': 'Do'},
      {'num': '2', 'name': 'Re'},
      {'num': '3', 'name': 'Mi'},
      {'num': '4', 'name': 'Fa'},
      {'num': '5', 'name': 'Sol'},
      {'num': '6', 'name': 'La'},
      {'num': '7', 'name': 'Si'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = (constraints.maxWidth - (6 * 6)) / 7; // 6 gaps of 6px
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: notes.map((note) {
              return SizedBox(
                width: buttonWidth,
                height: 80,
                child: FilledButton(
                  onPressed: () => _engine.submitAnswer(note['num']!),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: palette.soft,
                    foregroundColor: palette.text,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        note['name']!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        note['num']!,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: palette.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
