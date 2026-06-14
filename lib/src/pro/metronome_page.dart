import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../theme/app_icons.dart';

import '../audio/tone_synth.dart';
import '../theme/app_theme.dart';

enum _BeatAccent { strong, normal, soft, mute }

enum _TrainingMode { off, stepUp, silentBars }

class MetronomePage extends StatefulWidget {
  const MetronomePage({super.key});

  static const routeName = '/pro-metronome';

  @override
  State<MetronomePage> createState() => _MetronomePageState();
}

class _MetronomePageState extends State<MetronomePage> {
  final _synth = ToneSynth();
  final _tapTimes = <DateTime>[];
  Timer? _timer;
  DateTime? _nextTickAt;
  var _playing = false;
  var _bpm = 92;
  var _beatsPerBar = 4;
  var _subdivision = 1;
  var _volume = 0.72;
  var _swing = 0.0;
  var _countInBars = 0;
  var _practiceMinutes = 0;
  var _trainingMode = _TrainingMode.off;
  var _stepAmount = 4;
  var _stepEveryBars = 8;
  var _silentAudibleBars = 2;
  var _silentMutedBars = 1;
  var _tickIndex = 0;
  var _barCount = 0;
  var _activeBeat = -1;
  var _activeSubdivision = 0;
  var _countInTicksRemaining = 0;
  var _startedAt = DateTime.now();
  var _accents = List.filled(4, _BeatAccent.normal);
  var _tapCount = 0;
  double _dragAccumulator = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _accents[0] = _BeatAccent.strong;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _synth.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _togglePlay() {
    if (_playing) {
      _stop();
      return;
    }
    setState(() {
      _playing = true;
      _tickIndex = 0;
      _barCount = 0;
      _activeBeat = -1;
      _activeSubdivision = 0;
      _countInTicksRemaining = _countInBars * _beatsPerBar * _subdivision;
      _startedAt = DateTime.now();
      _nextTickAt = DateTime.now();
    });
    WakelockPlus.enable();
    _timer = Timer.periodic(const Duration(milliseconds: 12), (_) => _pulse());
    _startCountdownRefresh();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    WakelockPlus.disable();
    setState(() {
      _playing = false;
      _activeBeat = -1;
      _activeSubdivision = 0;
      _countInTicksRemaining = 0;
    });
  }

  void _pulse() {
    final nextTickAt = _nextTickAt;
    if (!_playing || nextTickAt == null) return;
    final now = DateTime.now();
    if (now.isBefore(nextTickAt)) return;

    _playTick();
    final interval = _currentIntervalMs();
    _nextTickAt = nextTickAt.add(Duration(milliseconds: interval.round()));

    if (_practiceMinutes > 0 &&
        now.difference(_startedAt).inSeconds >= _practiceMinutes * 60) {
      _stop();
    }
  }

  void _playTick() {
    if (_countInTicksRemaining > 0) {
      final totalCountInTicks = _countInBars * _beatsPerBar * _subdivision;
      final countTickIndex = totalCountInTicks - _countInTicksRemaining;
      final beat = (countTickIndex ~/ _subdivision) % _beatsPerBar;
      final subdivision = countTickIndex % _subdivision;
      _synth.playClick(
        accented: beat == 0 && subdivision == 0,
        volume: subdivision == 0 ? _volume * 0.66 : _volume * 0.24,
      );
      setState(() {
        _activeBeat = beat;
        _activeSubdivision = subdivision;
        _countInTicksRemaining--;
      });
      return;
    }

    final beat = (_tickIndex ~/ _subdivision) % _beatsPerBar;
    final subdivision = _tickIndex % _subdivision;
    final isNewBar = beat == 0 && subdivision == 0;
    if (isNewBar && _tickIndex > 0) {
      _barCount++;
      _applyStepTraining();
    }

    final accent = _accents[beat];
    final mutedByTrainer =
        _trainingMode == _TrainingMode.silentBars && _isTrainerSilentBar();
    final shouldPlay =
        !mutedByTrainer &&
        accent != _BeatAccent.mute &&
        (subdivision == 0 || _subdivision > 1);

    if (shouldPlay) {
      final baseVolume = switch (accent) {
        _BeatAccent.strong => _volume,
        _BeatAccent.normal => _volume * 0.78,
        _BeatAccent.soft => _volume * 0.48,
        _BeatAccent.mute => 0.0,
      };
      final clickVolume = subdivision == 0 ? baseVolume : _volume * 0.34;
      _synth.playClick(
        accented: accent == _BeatAccent.strong && subdivision == 0,
        volume: clickVolume,
      );
      if (subdivision == 0) {
        accent == _BeatAccent.strong
            ? HapticFeedback.mediumImpact()
            : HapticFeedback.lightImpact();
      }
    }

    setState(() {
      _activeBeat = beat;
      _activeSubdivision = subdivision;
      _tickIndex++;
    });
  }

  bool _isTrainerSilentBar() {
    final cycle = _silentAudibleBars + _silentMutedBars;
    if (cycle <= 0) return false;
    return _barCount % cycle >= _silentAudibleBars;
  }

  void _applyStepTraining() {
    if (_trainingMode != _TrainingMode.stepUp || _stepEveryBars <= 0) return;
    if (_barCount > 0 && _barCount % _stepEveryBars == 0) {
      _bpm = (_bpm + _stepAmount).clamp(30, 300);
    }
  }

  double _currentIntervalMs() {
    final base = 60000 / _bpm / _subdivision;
    if (_countInTicksRemaining > 0) return base;
    if (_subdivision != 2 || _swing <= 0) return base;
    final subdivision = _tickIndex % _subdivision;
    final swingOffset = base * 0.42 * _swing;
    return subdivision == 0 ? base + swingOffset : base - swingOffset;
  }

  void _setBeatsPerBar(int value) {
    final next = value.clamp(1, 16);
    setState(() {
      _beatsPerBar = next;
      _accents = List.generate(next, (index) {
        if (index < _accents.length) return _accents[index];
        return index == 0 ? _BeatAccent.strong : _BeatAccent.normal;
      });
      if (_accents.isNotEmpty && _accents.first == _BeatAccent.normal) {
        _accents[0] = _BeatAccent.strong;
      }
      _activeBeat = -1;
      _tickIndex = 0;
    });
  }

  void _cycleAccent(int index) {
    setState(() {
      _accents[index] = switch (_accents[index]) {
        _BeatAccent.strong => _BeatAccent.normal,
        _BeatAccent.normal => _BeatAccent.soft,
        _BeatAccent.soft => _BeatAccent.mute,
        _BeatAccent.mute => _BeatAccent.strong,
      };
    });
  }

  void _tapTempo() {
    final now = DateTime.now();
    _tapTimes.removeWhere((time) => now.difference(time).inSeconds > 3);
    _tapTimes.add(now);
    if (_tapTimes.length < 2) {
      setState(() => _tapCount = 1);
      return;
    }

    final intervals = <int>[];
    for (var i = 1; i < _tapTimes.length; i++) {
      intervals.add(_tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds);
    }
    final average = intervals.reduce((a, b) => a + b) / intervals.length;
    if (average <= 0) return;
    setState(() {
      _bpm = (60000 / average).round().clamp(30, 300);
      _tapCount = _tapTimes.length;
    });
  }

  void _loadPreset(_MetronomePreset preset) {
    setState(() {
      _bpm = preset.bpm;
      _beatsPerBar = preset.beatsPerBar;
      _subdivision = preset.subdivision;
      _swing = preset.swing;
      _accents = List.generate(
        preset.beatsPerBar,
        (index) => index == 0 ? _BeatAccent.strong : _BeatAccent.normal,
      );
      for (final muted in preset.mutedBeats) {
        if (muted >= 0 && muted < _accents.length) {
          _accents[muted] = _BeatAccent.mute;
        }
      }
      _activeBeat = -1;
      _tickIndex = 0;
      _barCount = 0;
      _countInTicksRemaining = 0;
    });
  }

  void _startCountdownRefresh() {
    _countdownTimer?.cancel();
    if (_practiceMinutes > 0) {
      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    }
  }

  static String _tempoMarking(int bpm) {
    if (bpm <= 24) return 'Larghissimo';
    if (bpm <= 40) return 'Grave';
    if (bpm <= 55) return 'Largo';
    if (bpm <= 65) return 'Larghetto';
    if (bpm <= 76) return 'Adagio';
    if (bpm <= 92) return 'Andante';
    if (bpm <= 108) return 'Moderato';
    if (bpm <= 120) return 'Allegretto';
    if (bpm <= 140) return 'Allegro';
    if (bpm <= 168) return 'Vivace';
    if (bpm <= 200) return 'Presto';
    return 'Prestissimo';
  }

  void _onBpmVerticalDrag(double dy) {
    _dragAccumulator -= dy * 0.3;
    if (_dragAccumulator.abs() >= 1) {
      final delta = _dragAccumulator.truncate();
      setState(() => _bpm = (_bpm + delta).clamp(30, 300));
      _dragAccumulator -= delta;
    }
  }

  String? _remainingTimeText() {
    if (!_playing || _practiceMinutes <= 0) return null;
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    final total = _practiceMinutes * 60;
    final remaining = total - elapsed;
    if (remaining <= 0) return null;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('专业节拍器')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          _MetronomeDeck(
            bpm: _bpm,
            beatsPerBar: _beatsPerBar,
            subdivision: _subdivision,
            playing: _playing,
            activeBeat: _activeBeat,
            activeSubdivision: _activeSubdivision,
            accents: _accents,
            silent:
                _trainingMode == _TrainingMode.silentBars &&
                _isTrainerSilentBar(),
            countIn: _countInTicksRemaining > 0,
            barCount: _barCount,
            tapCount: _tapCount,
            tempoMarking: _tempoMarking(_bpm),
            remainingTime: _remainingTimeText(),
            onPlay: _togglePlay,
            onBpmChanged: (value) => setState(() => _bpm = value),
            onTapTempo: _tapTempo,
            onAccentTap: _cycleAccent,
            onBpmDrag: _onBpmVerticalDrag,
          ),
          const SizedBox(height: 12),
          _Panel(
            title: '节奏',
            icon: AppIcons.grid4x4Rounded,
            child: Column(
              children: [
                _NumberStepper(
                  label: '拍号',
                  value: '$_beatsPerBar/4',
                  onDecrease: () => _setBeatsPerBar(_beatsPerBar - 1),
                  onIncrease: () => _setBeatsPerBar(_beatsPerBar + 1),
                ),
                const SizedBox(height: 10),
                _SegmentRow<int>(
                  label: '细分',
                  value: _subdivision,
                  values: const [1, 2, 3, 4, 6, 8],
                  labels: const ['1', '2', '3', '4', '6', '8'],
                  onChanged: (value) => setState(() => _subdivision = value),
                ),
                const SizedBox(height: 10),
                _LabeledSlider(
                  label: 'Swing',
                  value: _swing,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  text: '${(_swing * 100).round()}%',
                  onChanged: _subdivision == 2
                      ? (value) => setState(() => _swing = value)
                      : null,
                ),
                const SizedBox(height: 6),
                _AccentLegend(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Panel(
            title: '练习',
            icon: AppIcons.fitnessCenterRounded,
            child: Column(
              children: [
                _SegmentRow<_TrainingMode>(
                  label: '模式',
                  value: _trainingMode,
                  values: _TrainingMode.values,
                  labels: const ['普通', '提速', '静音'],
                  onChanged: (value) => setState(() => _trainingMode = value),
                ),
                if (_trainingMode == _TrainingMode.stepUp) ...[
                  const SizedBox(height: 10),
                  _NumberStepper(
                    label: '每几小节',
                    value: '$_stepEveryBars',
                    onDecrease: () => setState(
                      () => _stepEveryBars = (_stepEveryBars - 1).clamp(1, 64),
                    ),
                    onIncrease: () => setState(
                      () => _stepEveryBars = (_stepEveryBars + 1).clamp(1, 64),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _NumberStepper(
                    label: '提速',
                    value: '+$_stepAmount BPM',
                    onDecrease: () => setState(
                      () => _stepAmount = (_stepAmount - 1).clamp(1, 20),
                    ),
                    onIncrease: () => setState(
                      () => _stepAmount = (_stepAmount + 1).clamp(1, 20),
                    ),
                  ),
                ],
                if (_trainingMode == _TrainingMode.silentBars) ...[
                  const SizedBox(height: 10),
                  _NumberStepper(
                    label: '有声小节',
                    value: '$_silentAudibleBars',
                    onDecrease: () => setState(
                      () => _silentAudibleBars = (_silentAudibleBars - 1).clamp(
                        1,
                        16,
                      ),
                    ),
                    onIncrease: () => setState(
                      () => _silentAudibleBars = (_silentAudibleBars + 1).clamp(
                        1,
                        16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _NumberStepper(
                    label: '静音小节',
                    value: '$_silentMutedBars',
                    onDecrease: () => setState(
                      () => _silentMutedBars = (_silentMutedBars - 1).clamp(
                        1,
                        16,
                      ),
                    ),
                    onIncrease: () => setState(
                      () => _silentMutedBars = (_silentMutedBars + 1).clamp(
                        1,
                        16,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _SegmentRow<int>(
                  label: '计时',
                  value: _practiceMinutes,
                  values: const [0, 5, 10, 15, 30],
                  labels: const ['关闭', '5', '10', '15', '30'],
                  onChanged: (value) =>
                      setState(() => _practiceMinutes = value),
                ),
                const SizedBox(height: 10),
                _SegmentRow<int>(
                  label: '预备',
                  value: _countInBars,
                  values: const [0, 1, 2, 4],
                  labels: const ['关', '1', '2', '4'],
                  onChanged: (value) => setState(() => _countInBars = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Panel(
            title: '声音',
            icon: AppIcons.tuneRounded,
            child: _LabeledSlider(
              label: '音量',
              value: _volume,
              min: 0,
              max: 1,
              divisions: 10,
              text: '${(_volume * 100).round()}%',
              onChanged: (value) => setState(() => _volume = value),
            ),
          ),
          const SizedBox(height: 12),
          _Panel(
            title: '预设',
            icon: AppIcons.libraryMusicOutlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ActionChip(
                    avatar: const Icon(AppIcons.playlistPlayRounded, size: 18),
                    label: Text(preset.name),
                    onPressed: () => _loadPreset(preset),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetronomeDeck extends StatelessWidget {
  const _MetronomeDeck({
    required this.bpm,
    required this.beatsPerBar,
    required this.subdivision,
    required this.playing,
    required this.activeBeat,
    required this.activeSubdivision,
    required this.accents,
    required this.silent,
    required this.countIn,
    required this.barCount,
    required this.tapCount,
    required this.tempoMarking,
    required this.remainingTime,
    required this.onPlay,
    required this.onBpmChanged,
    required this.onTapTempo,
    required this.onAccentTap,
    required this.onBpmDrag,
  });

  final int bpm;
  final int beatsPerBar;
  final int subdivision;
  final bool playing;
  final int activeBeat;
  final int activeSubdivision;
  final List<_BeatAccent> accents;
  final bool silent;
  final bool countIn;
  final int barCount;
  final int tapCount;
  final String tempoMarking;
  final String? remainingTime;
  final VoidCallback onPlay;
  final ValueChanged<int> onBpmChanged;
  final VoidCallback onTapTempo;
  final ValueChanged<int> onAccentTap;
  final ValueChanged<double> onBpmDrag;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        children: [
          // --- Status pill row ---
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetricPill(
                icon: AppIcons.musicNoteRounded,
                text: '$beatsPerBar/4',
              ),
              _MetricPill(
                icon: AppIcons.callSplitRounded,
                text: '${subdivision}x',
              ),
              if (playing && barCount > 0)
                _MetricPill(
                  icon: AppIcons.factCheckOutlined,
                  text: '第$barCount小节',
                ),
              if (remainingTime != null)
                _MetricPill(
                  icon: AppIcons.timerRounded,
                  text: remainingTime!,
                  alert: true,
                ),
              if (silent)
                const _MetricPill(
                  icon: AppIcons.volumeOffRounded,
                  text: '静音训练',
                  alert: true,
                ),
              if (countIn)
                const _MetricPill(
                  icon: AppIcons.timerRounded,
                  text: '预备',
                  alert: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          // --- Ring + BPM center (with drag gesture) ---
          SizedBox(
            height: 246,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(236),
                  painter: _MetronomeRingPainter(
                    beatsPerBar: beatsPerBar,
                    activeBeat: activeBeat,
                    activeSubdivision: activeSubdivision,
                    subdivision: subdivision,
                    accents: accents,
                    playing: playing,
                    lineColor: palette.line,
                    textColor: palette.text,
                    accentColor: palette.accent,
                    brandColor: palette.brand,
                    amberColor: palette.amber,
                    mutedColor: palette.textMuted,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) => onBpmDrag(d.delta.dy),
                  child: SizedBox(
                    width: 140,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Small drag hint
                        Icon(
                          AppIcons.keyboardDoubleArrowUpRounded,
                          size: 14,
                          color: palette.textMuted.withValues(alpha: 0.4),
                        ),
                        Text(
                          '$bpm',
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 68,
                            height: 0.9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tempoMarking,
                          style: TextStyle(
                            color: palette.brand,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        // Small drag hint
                        Icon(
                          AppIcons.keyboardDoubleArrowDownRounded,
                          size: 14,
                          color: palette.textMuted.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 6),
                        FilledButton.icon(
                          onPressed: onPlay,
                          icon: Icon(
                            playing
                                ? AppIcons.pauseRounded
                                : AppIcons.playArrowRounded,
                          ),
                          label: Text(playing ? '暂停' : '开始'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // --- BPM ± buttons row (with long-press repeat) ---
          Row(
            children: [
              _RepeatIconButton(
                tooltip: '-5 BPM',
                onPressed: () => onBpmChanged((bpm - 5).clamp(30, 300)),
                icon: const Icon(AppIcons.keyboardDoubleArrowDownRounded),
              ),
              _RepeatIconButton(
                tooltip: '-1 BPM',
                onPressed: () => onBpmChanged((bpm - 1).clamp(30, 300)),
                icon: const Icon(AppIcons.removeRounded),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: OutlinedButton.icon(
                    onPressed: onTapTempo,
                    icon: const Icon(AppIcons.touchAppRounded),
                    label: Text(
                      tapCount > 0 ? 'Tap ×$tapCount' : 'Tap Tempo',
                    ),
                  ),
                ),
              ),
              _RepeatIconButton(
                tooltip: '+1 BPM',
                onPressed: () => onBpmChanged((bpm + 1).clamp(30, 300)),
                icon: const Icon(AppIcons.addRounded),
              ),
              _RepeatIconButton(
                tooltip: '+5 BPM',
                onPressed: () => onBpmChanged((bpm + 5).clamp(30, 300)),
                icon: const Icon(AppIcons.keyboardDoubleArrowUpRounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // --- Accent buttons grid ---
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: beatsPerBar,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 54,
              mainAxisExtent: 42,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
            ),
            itemBuilder: (context, index) {
              final accent = accents[index];
              final active = playing && index == activeBeat;
              return _AccentButton(
                index: index,
                accent: accent,
                active: active,
                onTap: () => onAccentTap(index),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetronomeRingPainter extends CustomPainter {
  _MetronomeRingPainter({
    required this.beatsPerBar,
    required this.activeBeat,
    required this.activeSubdivision,
    required this.subdivision,
    required this.accents,
    required this.playing,
    required this.lineColor,
    required this.textColor,
    required this.accentColor,
    required this.brandColor,
    required this.amberColor,
    required this.mutedColor,
  });

  final int beatsPerBar;
  final int activeBeat;
  final int activeSubdivision;
  final int subdivision;
  final List<_BeatAccent> accents;
  final bool playing;
  final Color lineColor;
  final Color textColor;
  final Color accentColor;
  final Color brandColor;
  final Color amberColor;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 14;

    // 1. Draw glowing outer ring backdrop when playing
    if (playing) {
      final pulseAuraPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = brandColor.withValues(alpha: 0.08);
      canvas.drawCircle(center, radius + 2, pulseAuraPaint);
    }

    // 2. Draw outer boundary thin circle
    final thinOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = lineColor.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius + 5, thinOutline);

    // 3. Draw DAW tick marks around the ring
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = lineColor.withValues(alpha: 0.45);
    const tickCount = 60;
    for (var i = 0; i < tickCount; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / tickCount;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 5);
      canvas.drawLine(outer, inner, tickPaint);
    }

    // 4. Draw beat node markers
    for (var i = 0; i < beatsPerBar; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / beatsPerBar;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final accent = accents[i];
      final active = playing && i == activeBeat;
      final color = switch (accent) {
        _BeatAccent.strong => accentColor,
        _BeatAccent.normal => brandColor,
        _BeatAccent.soft => amberColor,
        _BeatAccent.mute => mutedColor,
      };

      if (active) {
        // Glowing halo for active beat
        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: 0.35);
        canvas.drawCircle(point, 18, glowPaint);

        // Core fill ring
        final strokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = color;
        canvas.drawCircle(point, 11, strokePaint);

        // Center dot
        final centerDot = Paint()
          ..style = PaintingStyle.fill
          ..color = textColor;
        canvas.drawCircle(point, 5, centerDot);
      } else {
        // Regular inactive beat indicator
        final dotPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: 0.3);
        canvas.drawCircle(point, 8, dotPaint);

        // Draw a tiny index number next to it
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              color: color.withValues(alpha: 0.75),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final textOffset = center +
            Offset(math.cos(angle), math.sin(angle)) * (radius - 20) -
            Offset(textPainter.width / 2, textPainter.height / 2);
        textPainter.paint(canvas, textOffset);
      }
    }

    // 5. Draw DAW Pointer Needle
    if (playing && activeBeat >= 0) {
      final progress =
          (activeBeat + activeSubdivision / subdivision) /
          math.max(1, beatsPerBar);
      final angle = -math.pi / 2 + progress * 2 * math.pi;

      // Glow sweep arc path
      final sweepPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = accentColor.withValues(alpha: 0.12);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 8),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        sweepPaint,
      );

      // Main needle arm
      final needlePaint = Paint()
        ..color = accentColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * 16,
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 12),
        needlePaint,
      );
    }

    // 6. Draw central hub
    final hubPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = textColor;
    canvas.drawCircle(center, 9, hubPaint);
    
    final hubInner = Paint()
      ..style = PaintingStyle.fill
      ..color = lineColor;
    canvas.drawCircle(center, 4, hubInner);
  }

  @override
  bool shouldRepaint(covariant _MetronomeRingPainter oldDelegate) {
    return beatsPerBar != oldDelegate.beatsPerBar ||
        activeBeat != oldDelegate.activeBeat ||
        activeSubdivision != oldDelegate.activeSubdivision ||
        subdivision != oldDelegate.subdivision ||
        accents != oldDelegate.accents ||
        playing != oldDelegate.playing ||
        lineColor != oldDelegate.lineColor ||
        textColor != oldDelegate.textColor ||
        accentColor != oldDelegate.accentColor ||
        brandColor != oldDelegate.brandColor ||
        amberColor != oldDelegate.amberColor ||
        mutedColor != oldDelegate.mutedColor;
  }
}



class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.brand, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SegmentRow<T> extends StatelessWidget {
  const _SegmentRow({
    required this.label,
    required this.value,
    required this.values,
    required this.labels,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final List<String> labels;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ControlLabel(label),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < values.length; i++)
                ChoiceChip(
                  label: Text(labels[i]),
                  selected: value == values[i],
                  onSelected: (_) => onChanged(values[i]),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final String value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Row(
      children: [
        _ControlLabel(label),
        _RepeatIconButton(
          tooltip: '减少',
          onPressed: onDecrease,
          icon: const Icon(AppIcons.removeRounded),
        ),
        Expanded(
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: palette.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        _RepeatIconButton(
          tooltip: '增加',
          onPressed: onIncrease,
          icon: const Icon(AppIcons.addRounded),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.text,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String text;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Row(
      children: [
        _ControlLabel(label),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value,
            label: text,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return SizedBox(
      width: 76,
      child: Text(
        text,
        style: TextStyle(
          color: palette.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AccentButton extends StatelessWidget {
  const _AccentButton({
    required this.index,
    required this.accent,
    required this.active,
    required this.onTap,
  });

  final int index;
  final _BeatAccent accent;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final color = switch (accent) {
      _BeatAccent.strong => palette.accent,
      _BeatAccent.normal => palette.brand,
      _BeatAccent.soft => palette.amber,
      _BeatAccent.mute => palette.textMuted,
    };
    final label = switch (accent) {
      _BeatAccent.strong => '强',
      _BeatAccent.normal => '中',
      _BeatAccent.soft => '弱',
      _BeatAccent.mute => '静',
    };
    return InkWell(
      borderRadius: BorderRadius.circular(radiusMedium),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        alignment: Alignment.center,
        child: Text(
          '${index + 1}$label',
          style: TextStyle(
            color: active ? Theme.of(context).colorScheme.onPrimary : color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AccentLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Row(
      children: [
        _LegendDot(color: palette.accent, text: '强'),
        const SizedBox(width: 10),
        _LegendDot(color: palette.brand, text: '中'),
        const SizedBox(width: 10),
        _LegendDot(color: palette.amber, text: '弱'),
        const SizedBox(width: 10),
        _LegendDot(color: palette.textMuted, text: '静音'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: palette.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.text,
    this.alert = false,
  });

  final IconData icon;
  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: alert ? palette.accent.withValues(alpha: 0.12) : palette.soft,
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: alert ? palette.accent : palette.brand),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: alert ? palette.accent : palette.brandDark,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetronomePreset {
  const _MetronomePreset({
    required this.name,
    required this.bpm,
    required this.beatsPerBar,
    required this.subdivision,
    this.swing = 0,
    this.mutedBeats = const [],
  });

  final String name;
  final int bpm;
  final int beatsPerBar;
  final int subdivision;
  final double swing;
  final List<int> mutedBeats;
}

const _presets = [
  _MetronomePreset(name: '慢练 60', bpm: 60, beatsPerBar: 4, subdivision: 1),
  _MetronomePreset(name: '基础 4/4', bpm: 92, beatsPerBar: 4, subdivision: 2),
  _MetronomePreset(name: '圆舞曲', bpm: 108, beatsPerBar: 3, subdivision: 1),
  _MetronomePreset(name: '复合 6/8', bpm: 72, beatsPerBar: 6, subdivision: 3),
  _MetronomePreset(
    name: 'Shuffle',
    bpm: 118,
    beatsPerBar: 4,
    subdivision: 2,
    swing: 0.55,
  ),
  _MetronomePreset(
    name: '反拍练习',
    bpm: 84,
    beatsPerBar: 4,
    subdivision: 2,
    mutedBeats: [0, 2],
  ),
];

/// An [IconButton.filledTonal] that repeats its [onPressed] callback when held.
class _RepeatIconButton extends StatefulWidget {
  const _RepeatIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  State<_RepeatIconButton> createState() => _RepeatIconButtonState();
}

class _RepeatIconButtonState extends State<_RepeatIconButton> {
  Timer? _delayTimer;
  Timer? _repeatTimer;

  void _startRepeat() {
    _delayTimer = Timer(const Duration(milliseconds: 400), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        widget.onPressed();
      });
    });
  }

  void _stopRepeat() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startRepeat(),
      onLongPressEnd: (_) => _stopRepeat(),
      child: IconButton.filledTonal(
        tooltip: widget.tooltip,
        onPressed: widget.onPressed,
        icon: widget.icon,
      ),
    );
  }
}
