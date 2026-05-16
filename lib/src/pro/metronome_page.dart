import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _accents[0] = _BeatAccent.strong;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _synth.dispose();
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
    _timer = Timer.periodic(const Duration(milliseconds: 12), (_) => _pulse());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
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
    if (_tapTimes.length < 2) return;

    final intervals = <int>[];
    for (var i = 1; i < _tapTimes.length; i++) {
      intervals.add(_tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds);
    }
    final average = intervals.reduce((a, b) => a + b) / intervals.length;
    if (average <= 0) return;
    setState(() => _bpm = (60000 / average).round().clamp(30, 300));
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
            onPlay: _togglePlay,
            onBpmChanged: (value) => setState(() => _bpm = value),
            onTapTempo: _tapTempo,
            onAccentTap: _cycleAccent,
          ),
          const SizedBox(height: 12),
          _Panel(
            title: '速度',
            icon: Icons.speed_rounded,
            child: Column(
              children: [
                _BpmControl(
                  bpm: _bpm,
                  onChanged: (value) => setState(() => _bpm = value),
                ),
                const SizedBox(height: 10),
                Slider(
                  min: 30,
                  max: 300,
                  divisions: 270,
                  value: _bpm.toDouble(),
                  label: '$_bpm BPM',
                  onChanged: (value) => setState(() => _bpm = value.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Panel(
            title: '节奏',
            icon: Icons.grid_4x4_rounded,
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
            icon: Icons.fitness_center_rounded,
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
            icon: Icons.tune_rounded,
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
            icon: Icons.library_music_outlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ActionChip(
                    avatar: const Icon(Icons.playlist_play_rounded, size: 18),
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
    required this.onPlay,
    required this.onBpmChanged,
    required this.onTapTempo,
    required this.onAccentTap,
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
  final VoidCallback onPlay;
  final ValueChanged<int> onBpmChanged;
  final VoidCallback onTapTempo;
  final ValueChanged<int> onAccentTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _MetricPill(
                icon: Icons.music_note_rounded,
                text: '$beatsPerBar/4',
              ),
              const SizedBox(width: 8),
              _MetricPill(
                icon: Icons.call_split_rounded,
                text: '${subdivision}x',
              ),
              const Spacer(),
              if (silent)
                const _MetricPill(
                  icon: Icons.volume_off_rounded,
                  text: '静音训练',
                  alert: true,
                ),
              if (silent && countIn) const SizedBox(width: 8),
              if (countIn)
                const _MetricPill(
                  icon: Icons.timer_rounded,
                  text: '预备',
                  alert: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
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
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$bpm',
                      style: const TextStyle(
                        color: inkColor,
                        fontSize: 68,
                        height: 0.9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'BPM',
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onPlay,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(playing ? '暂停' : '开始'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: '-5 BPM',
                onPressed: () => onBpmChanged((bpm - 5).clamp(30, 300)),
                icon: const Icon(Icons.keyboard_double_arrow_down_rounded),
              ),
              IconButton.filledTonal(
                tooltip: '-1 BPM',
                onPressed: () => onBpmChanged((bpm - 1).clamp(30, 300)),
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: OutlinedButton.icon(
                    onPressed: onTapTempo,
                    icon: const Icon(Icons.touch_app_rounded),
                    label: const Text('Tap Tempo'),
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: '+1 BPM',
                onPressed: () => onBpmChanged((bpm + 1).clamp(30, 300)),
                icon: const Icon(Icons.add_rounded),
              ),
              IconButton.filledTonal(
                tooltip: '+5 BPM',
                onPressed: () => onBpmChanged((bpm + 5).clamp(30, 300)),
                icon: const Icon(Icons.keyboard_double_arrow_up_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
  });

  final int beatsPerBar;
  final int activeBeat;
  final int activeSubdivision;
  final int subdivision;
  final List<_BeatAccent> accents;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 14;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = lineColor;
    canvas.drawCircle(center, radius, basePaint);

    for (var i = 0; i < beatsPerBar; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / beatsPerBar;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final accent = accents[i];
      final active = playing && i == activeBeat;
      final color = switch (accent) {
        _BeatAccent.strong => accentColor,
        _BeatAccent.normal => brandColor,
        _BeatAccent.soft => amberColor,
        _BeatAccent.mute => mutedTextColor,
      };
      final paint = Paint()
        ..color = active ? color : color.withValues(alpha: 0.3);
      canvas.drawCircle(point, active ? 14 : 9, paint);
    }

    if (playing && activeBeat >= 0) {
      final progress =
          (activeBeat + activeSubdivision / subdivision) /
          math.max(1, beatsPerBar);
      final angle = -math.pi / 2 + progress * 2 * math.pi;
      final handPaint = Paint()
        ..color = accentColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 20),
        handPaint,
      );
      canvas.drawCircle(center, 5, Paint()..color = inkColor);
    }
  }

  @override
  bool shouldRepaint(covariant _MetronomeRingPainter oldDelegate) {
    return beatsPerBar != oldDelegate.beatsPerBar ||
        activeBeat != oldDelegate.activeBeat ||
        activeSubdivision != oldDelegate.activeSubdivision ||
        subdivision != oldDelegate.subdivision ||
        accents != oldDelegate.accents ||
        playing != oldDelegate.playing;
  }
}

class _BpmControl extends StatelessWidget {
  const _BpmControl({required this.bpm, required this.onChanged});

  final int bpm;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final marks = const [60, 72, 80, 96, 108, 120, 144];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mark in marks)
          ChoiceChip(
            label: Text('$mark'),
            selected: bpm == mark,
            onSelected: (_) => onChanged(mark),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
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
        border: Border.all(color: lineColor),
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
                style: const TextStyle(
                  color: inkColor,
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
    return Row(
      children: [
        _ControlLabel(label),
        IconButton.filledTonal(
          tooltip: '减少',
          onPressed: onDecrease,
          icon: const Icon(Icons.remove_rounded),
        ),
        Expanded(
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: inkColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: '增加',
          onPressed: onIncrease,
          icon: const Icon(Icons.add_rounded),
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
            style: const TextStyle(
              color: mutedTextColor,
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
    return SizedBox(
      width: 76,
      child: Text(
        text,
        style: const TextStyle(
          color: mutedTextColor,
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
    final color = switch (accent) {
      _BeatAccent.strong => accentColor,
      _BeatAccent.normal => brandColor,
      _BeatAccent.soft => amberColor,
      _BeatAccent.mute => mutedTextColor,
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
            color: active ? Colors.white : color,
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
    return const Row(
      children: [
        _LegendDot(color: accentColor, text: '强'),
        SizedBox(width: 10),
        _LegendDot(color: brandColor, text: '中'),
        SizedBox(width: 10),
        _LegendDot(color: amberColor, text: '弱'),
        SizedBox(width: 10),
        _LegendDot(color: mutedTextColor, text: '静音'),
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
          style: const TextStyle(
            color: mutedTextColor,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: alert
            ? accentColor.withValues(alpha: 0.12)
            : softGreenColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: alert ? accentColor : brandColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: alert ? accentColor : brandDarkColor,
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
