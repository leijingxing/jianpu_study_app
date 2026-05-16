import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/tone_synth.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

enum _PracticeMode { listen, solfege, lyric }

class JianpuPracticePage extends StatefulWidget {
  const JianpuPracticePage({super.key, this.title, this.detail, this.document});

  static const routeName = '/jianpu-practice';

  final String? title;
  final MusicDetail? detail;
  final ScoreDocument? document;

  @override
  State<JianpuPracticePage> createState() => _JianpuPracticePageState();
}

class _JianpuPracticePageState extends State<JianpuPracticePage> {
  final _synth = ToneSynth();
  Timer? _timer;
  late final List<_PracticeMeasure> _measures;
  late final String _lessonTitle;
  late final String _practiceKey;
  var _selectedTopic = 0;
  var _measureIndex = 0;
  var _activeNoteIndex = -1;
  var _playing = false;
  var _loop = true;
  var _showSymbols = false;
  var _mode = _PracticeMode.solfege;
  var _bpm = 72;
  var _elapsedMs = 0;
  var _lastNoteIndex = -1;
  var _lastBeatIndex = -1;

  _PracticeMeasure get _measure => _measures[_measureIndex];

  @override
  void initState() {
    super.initState();
    _lessonTitle =
        widget.title ??
        widget.detail?.title ??
        widget.document?.title ??
        '小兔乖乖';
    _practiceKey = _resolvePracticeKey(widget.detail);
    _measures = _buildPracticeMeasures(
      detail: widget.detail,
      document: widget.document,
    );
    final sourceBpm = widget.detail?.bpm ?? 0;
    if (sourceBpm > 0) {
      _bpm = sourceBpm.clamp(48, 168);
    }
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
    _start();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _playing = true;
      _elapsedMs = 0;
      _activeNoteIndex = -1;
      _lastNoteIndex = -1;
      _lastBeatIndex = -1;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 32), (_) => _tick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _playing = false;
      _activeNoteIndex = -1;
      _lastNoteIndex = -1;
      _lastBeatIndex = -1;
    });
  }

  void _tick() {
    if (!_playing) return;
    final beatMs = 60000 / _bpm;
    final totalMs = (_measure.totalBeats * beatMs).round();
    final elapsed = _elapsedMs + 32;
    final beatIndex = (elapsed / beatMs).floor();
    if (beatIndex != _lastBeatIndex) {
      _lastBeatIndex = beatIndex;
      _synth.playClick(accented: beatIndex % 4 == 0, volume: 0.36);
    }

    final noteIndex = _noteIndexAt(elapsed, beatMs);
    if (noteIndex != _lastNoteIndex) {
      _lastNoteIndex = noteIndex;
      if (noteIndex >= 0) {
        final note = _measure.notes[noteIndex];
        if (!note.isHold) {
          _synth.playNote(
            raw: note.raw,
            key: _practiceKey,
            durationMs: (note.beats * beatMs).round(),
            volume: 0.58,
          );
        }
      }
    }

    if (elapsed >= totalMs) {
      if (_loop) {
        setState(() {
          _elapsedMs = 0;
          _activeNoteIndex = -1;
          _lastNoteIndex = -1;
          _lastBeatIndex = -1;
        });
      } else {
        _stop();
      }
      return;
    }

    setState(() {
      _elapsedMs = elapsed;
      _activeNoteIndex = noteIndex;
    });
  }

  int _noteIndexAt(int elapsedMs, double beatMs) {
    var cursor = 0.0;
    for (var i = 0; i < _measure.notes.length; i++) {
      final duration = _measure.notes[i].beats * beatMs;
      if (elapsedMs >= cursor && elapsedMs < cursor + duration) return i;
      cursor += duration;
    }
    return -1;
  }

  void _selectMeasure(int value) {
    _timer?.cancel();
    setState(() {
      _measureIndex = value;
      _playing = false;
      _activeNoteIndex = -1;
      _elapsedMs = 0;
      _lastNoteIndex = -1;
      _lastBeatIndex = -1;
    });
  }

  void _nextStep() {
    if (_mode == _PracticeMode.listen) {
      setState(() => _mode = _PracticeMode.solfege);
      return;
    }
    if (_mode == _PracticeMode.solfege) {
      setState(() => _mode = _PracticeMode.lyric);
      return;
    }
    if (_measureIndex < _measures.length - 1) {
      _selectMeasure(_measureIndex + 1);
      setState(() => _mode = _PracticeMode.listen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('简谱练习')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _IntroCard(
            onStart: _start,
            mode: _mode,
            title: _lessonTitle,
            fromScore: widget.document != null,
          ),
          const SizedBox(height: 12),
          _LearningFlowCard(
            mode: _mode,
            measureIndex: _measureIndex,
            measureCount: _measures.length,
            onNext: _nextStep,
          ),
          const SizedBox(height: 12),
          _MeasurePracticePanel(
            measure: _measure,
            measureIndex: _measureIndex,
            measureCount: _measures.length,
            activeNoteIndex: _activeNoteIndex,
            playing: _playing,
            loop: _loop,
            mode: _mode,
            bpm: _bpm,
            onPlay: _togglePlay,
            onPrevious: () => _selectMeasure(
              (_measureIndex - 1).clamp(0, _measures.length - 1),
            ),
            onNext: () => _selectMeasure(
              (_measureIndex + 1).clamp(0, _measures.length - 1),
            ),
            onMeasureChanged: _selectMeasure,
            onLoopChanged: (value) => setState(() => _loop = value),
            onModeChanged: (value) => setState(() => _mode = value),
            onBpmChanged: (value) => setState(() => _bpm = value),
          ),
          const SizedBox(height: 12),
          _SymbolTeachingPanel(
            selectedIndex: _selectedTopic,
            expanded: _showSymbols,
            onExpandedChanged: (value) => setState(() => _showSymbols = value),
            onSelected: (index) => setState(() => _selectedTopic = index),
          ),
          const SizedBox(height: 12),
          const _PracticeStepsPanel(),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.onStart,
    required this.mode,
    required this.title,
    required this.fromScore,
  });

  final VoidCallback onStart;
  final _PracticeMode mode;
  final String title;
  final bool fromScore;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
            child: Icon(Icons.menu_book_rounded, color: palette.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title：从唱谱开始',
                  style: const TextStyle(
                    color: inkColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  fromScore
                      ? '已按当前曲谱自动拆成乐句，先听音，再唱数字，最后带歌词。'
                      : '先听音，再唱 5 1 6，最后把歌词放回去。',
                  style: const TextStyle(color: mutedTextColor, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: mode == _PracticeMode.lyric ? '开始带词练' : '开始唱谱',
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}

class _SymbolTeachingPanel extends StatelessWidget {
  const _SymbolTeachingPanel({
    required this.selectedIndex,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final topic = _topics[selectedIndex];
    return _Panel(
      title: '简谱符号教学',
      icon: Icons.school_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: expanded,
            title: const Text('显示符号讲解'),
            subtitle: const Text('练习时可收起，减少干扰'),
            onChanged: onExpandedChanged,
          ),
          if (!expanded)
            const Text(
              '当前先专注乐句唱谱；需要时再展开符号说明。',
              style: TextStyle(color: mutedTextColor, fontSize: 13),
            ),
          if (!expanded) const SizedBox.shrink(),
          if (expanded) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _topics.length; i++)
                  ChoiceChip(
                    label: Text(_topics[i].symbol),
                    selected: selectedIndex == i,
                    onSelected: (_) => onSelected(i),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: softGreenColor.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(radiusMedium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        topic.symbol,
                        style: const TextStyle(
                          color: brandDarkColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          topic.title,
                          style: const TextStyle(
                            color: inkColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic.explanation,
                    style: const TextStyle(
                      color: inkColor,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '练法：${topic.practice}',
                    style: const TextStyle(
                      color: mutedTextColor,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LearningFlowCard extends StatelessWidget {
  const _LearningFlowCard({
    required this.mode,
    required this.measureIndex,
    required this.measureCount,
    required this.onNext,
  });

  final _PracticeMode mode;
  final int measureIndex;
  final int measureCount;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final step = switch (mode) {
      _PracticeMode.listen => 0,
      _PracticeMode.solfege => 1,
      _PracticeMode.lyric => 2,
    };
    final buttonText = mode == _PracticeMode.listen
        ? '下一步：唱谱'
        : mode == _PracticeMode.solfege
        ? '下一步：带词'
        : measureIndex < measureCount - 1
        ? '下一乐句'
        : '继续巩固';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.soft.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(radiusMedium),
        border: Border.all(color: lineColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '学习流程',
                style: TextStyle(
                  color: inkColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${measureIndex + 1}/$measureCount 乐句',
                style: const TextStyle(
                  color: mutedTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _FlowStep(label: '听', active: step >= 0, current: step == 0),
              _FlowLine(active: step >= 1),
              _FlowStep(label: '唱谱', active: step >= 1, current: step == 1),
              _FlowLine(active: step >= 2),
              _FlowStep(label: '带词', active: step >= 2, current: step == 2),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.label,
    required this.active,
    required this.current,
  });

  final String label;
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: current
            ? accentColor
            : active
            ? brandColor
            : lineColor,
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : mutedTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FlowLine extends StatelessWidget {
  const _FlowLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? brandColor : lineColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _MeasurePracticePanel extends StatelessWidget {
  const _MeasurePracticePanel({
    required this.measure,
    required this.measureIndex,
    required this.measureCount,
    required this.activeNoteIndex,
    required this.playing,
    required this.loop,
    required this.mode,
    required this.bpm,
    required this.onPlay,
    required this.onPrevious,
    required this.onNext,
    required this.onMeasureChanged,
    required this.onLoopChanged,
    required this.onModeChanged,
    required this.onBpmChanged,
  });

  final _PracticeMeasure measure;
  final int measureIndex;
  final int measureCount;
  final int activeNoteIndex;
  final bool playing;
  final bool loop;
  final _PracticeMode mode;
  final int bpm;
  final VoidCallback onPlay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onMeasureChanged;
  final ValueChanged<bool> onLoopChanged;
  final ValueChanged<_PracticeMode> onModeChanged;
  final ValueChanged<int> onBpmChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '乐句练习',
      icon: Icons.repeat_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: '上一乐句',
                onPressed: onPrevious,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '第 ${measureIndex + 1} 句 · ${measure.focus}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: inkColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: '下一乐句',
                onPressed: onNext,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ModeSelector(mode: mode, onChanged: onModeChanged),
          const SizedBox(height: 10),
          _MeasureStaff(
            measure: measure,
            activeNoteIndex: activeNoteIndex,
            mode: mode,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < measureCount; i++)
                ChoiceChip(
                  label: Text('${i + 1}'),
                  selected: i == measureIndex,
                  onSelected: (_) => onMeasureChanged(i),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onPlay,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(playing ? '暂停' : '播放'),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('循环'),
                selected: loop,
                onSelected: onLoopChanged,
                avatar: const Icon(Icons.loop_rounded, size: 18),
              ),
              const Spacer(),
              Text(
                '$bpm BPM',
                style: const TextStyle(
                  color: brandDarkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            min: 48,
            max: 132,
            divisions: 84,
            value: bpm.toDouble(),
            label: '$bpm BPM',
            onChanged: (value) => onBpmChanged(value.round()),
          ),
          Text(
            measure.tip,
            style: const TextStyle(
              color: mutedTextColor,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final _PracticeMode mode;
  final ValueChanged<_PracticeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ModeChip(
          value: _PracticeMode.listen,
          selected: mode == _PracticeMode.listen,
          icon: Icons.hearing_rounded,
          label: '听音',
          onSelected: onChanged,
        ),
        _ModeChip(
          value: _PracticeMode.solfege,
          selected: mode == _PracticeMode.solfege,
          icon: Icons.record_voice_over_rounded,
          label: '唱谱',
          onSelected: onChanged,
        ),
        _ModeChip(
          value: _PracticeMode.lyric,
          selected: mode == _PracticeMode.lyric,
          icon: Icons.lyrics_rounded,
          label: '带词',
          onSelected: onChanged,
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.value,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final _PracticeMode value;
  final bool selected;
  final IconData icon;
  final String label;
  final ValueChanged<_PracticeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MeasureStaff extends StatelessWidget {
  const _MeasureStaff({
    required this.measure,
    required this.activeNoteIndex,
    required this.mode,
  });

  final _PracticeMeasure measure;
  final int activeNoteIndex;
  final _PracticeMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: paperTintColor,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${measure.meter}   ${measure.rhythm}',
            style: const TextStyle(
              color: mutedTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < measure.notes.length; i++)
                _NoteTile(
                  note: measure.notes[i],
                  active: i == activeNoteIndex,
                  mode: mode,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            mode == _PracticeMode.listen
                ? '先听准音高走向'
                : mode == _PracticeMode.solfege
                ? measure.solfegeLine
                : measure.lyric,
            style: const TextStyle(
              color: brandDarkColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            mode == _PracticeMode.lyric ? measure.solfegeLine : measure.lyric,
            style: const TextStyle(
              color: mutedTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.active,
    required this.mode,
  });

  final _PracticeNote note;
  final bool active;
  final _PracticeMode mode;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: active ? accentColor : softGreenColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radiusMedium),
        border: Border.all(color: active ? accentColor : lineColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mode == _PracticeMode.lyric ? note.lyric : note.display,
            style: TextStyle(
              color: active ? Colors.white : inkColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            mode == _PracticeMode.lyric ? note.display : note.solfege,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? Colors.white : mutedTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeStepsPanel extends StatelessWidget {
  const _PracticeStepsPanel();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      title: '推荐练法',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepText('1. 先拍手读 X 节奏，只读歌词，不唱音高。'),
          _StepText('2. 切到“唱谱”，跟着高亮唱数字：sol-mi-la。'),
          _StepText('3. 切到“带词”，把“小 兔 子”贴回同样的节奏。'),
          _StepText('4. 一个乐句循环稳定后，再进入下一句。'),
        ],
      ),
    );
  }
}

class _StepText extends StatelessWidget {
  const _StepText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: inkColor,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
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

class _SymbolTopic {
  const _SymbolTopic({
    required this.symbol,
    required this.title,
    required this.explanation,
    required this.practice,
  });

  final String symbol;
  final String title;
  final String explanation;
  final String practice;
}

class _PracticeMeasure {
  const _PracticeMeasure({
    required this.focus,
    required this.meter,
    required this.rhythm,
    required this.lyric,
    required this.tip,
    required this.notes,
  });

  final String focus;
  final String meter;
  final String rhythm;
  final String lyric;
  final String tip;
  final List<_PracticeNote> notes;

  String get solfegeLine => notes
      .where((note) => !note.isHold)
      .map((note) => note.solfege)
      .join('  ');

  double get totalBeats =>
      notes.fold(0, (previous, note) => previous + note.beats);
}

class _ParsedMeasure {
  const _ParsedMeasure({
    required this.raw,
    required this.notes,
    required this.lineBreak,
  });

  final List<String> raw;
  final List<_PracticeNote> notes;
  final bool lineBreak;

  _ParsedMeasure copyWith({bool? lineBreak}) {
    return _ParsedMeasure(
      raw: raw,
      notes: notes,
      lineBreak: lineBreak ?? this.lineBreak,
    );
  }
}

class _PracticeNote {
  const _PracticeNote({
    required this.raw,
    required this.lyric,
    required this.solfege,
    required this.beats,
  });

  final String raw;
  final String lyric;
  final String solfege;
  final double beats;

  bool get isHold => raw == '-';
  String get display => isHold ? '-' : raw;
}

const _topics = [
  _SymbolTopic(
    symbol: '1=C',
    title: '调号',
    explanation: '这里表示所有数字都按 C 调理解，1 是 Do，也就是 C 音。',
    practice: '先固定 C 调练，别急着转调。',
  ),
  _SymbolTopic(
    symbol: '4/4',
    title: '拍号',
    explanation: '拍号说明一小节有几拍。4/4 是四拍，2/4 是两拍，儿歌里很常见。',
    practice: '小兔乖乖是 2/4，可以用“1 2、1 2”稳定数拍。',
  ),
  _SymbolTopic(
    symbol: '|',
    title: '小节线',
    explanation: '竖线把音乐切成小节。专业谱不要一口气看一整行，要一小节一小节处理。',
    practice: '只循环一个小节，稳定后再接下一个。',
  ),
  _SymbolTopic(
    symbol: '0',
    title: '休止符',
    explanation: '0 表示这一拍或半拍不唱，但拍子还要继续走。',
    practice: '遇到 0 时嘴巴停，手上的拍子不停。',
  ),
  _SymbolTopic(
    symbol: '_',
    title: '下划线',
    explanation: '数字下面一条线通常表示时值变短，常见是一拍里唱两个八分音。',
    practice: '把一拍分成“哒-哒”两个位置。',
  ),
  _SymbolTopic(
    symbol: '-',
    title: '延长线',
    explanation: '横杠表示前一个音继续延长，不重新唱一个新音。',
    practice: '唱到横杠时拉住声音，别重新起音。',
  ),
  _SymbolTopic(
    symbol: '⌒',
    title: '连音线',
    explanation: '弧线通常表示几个音要连贯唱，歌词也要贴着旋律走。',
    practice: '先慢速连唱，不要每个音都断开。',
  ),
  _SymbolTopic(
    symbol: 'X',
    title: '节奏音',
    explanation: 'X 只表示节奏，不表示音高。你图上方的 X 是先读歌词节奏用的。',
    practice: '先只读 X 那一层，再练下面的旋律数字。',
  ),
];

String _resolvePracticeKey(MusicDetail? detail) {
  final selected = detail?.selectedKey.trim() ?? '';
  if (selected.isNotEmpty) return selected;
  final original = detail?.originalKey.trim() ?? '';
  return original.isEmpty ? 'C' : original;
}

List<_PracticeMeasure> _buildPracticeMeasures({
  required MusicDetail? detail,
  required ScoreDocument? document,
}) {
  if (detail == null || document == null || document.notation.isEmpty) {
    return _demoMeasures;
  }

  final measures = <_ParsedMeasure>[];
  final lyrics = document.lyrics;
  var lyricIndex = 0;
  var measureNotes = <_PracticeNote>[];
  var measureRaw = <String>[];

  void flush() {
    if (measureNotes.isEmpty) {
      measureRaw = [];
      return;
    }
    measures.add(
      _ParsedMeasure(
        raw: List.of(measureRaw),
        notes: List.of(measureNotes),
        lineBreak: false,
      ),
    );
    measureNotes = [];
    measureRaw = [];
  }

  for (final line in document.notation) {
    final matches = RegExp(r'\||[^\s|]+').allMatches(line);
    for (final match in matches) {
      final token = match.group(0)!.trim();
      if (token.isEmpty) continue;
      if (token == '|') {
        flush();
        if (measures.length >= 96) break;
        continue;
      }
      if (RegExp(r'^\d+/\d+$').hasMatch(token)) continue;
      if (!RegExp(r'[0-7]').hasMatch(token) && !token.contains('-')) continue;

      final lyric = token.contains('-')
          ? '延'
          : token.contains('0')
          ? '停'
          : (lyricIndex < lyrics.length ? lyrics[lyricIndex] : '唱');
      if (!token.contains('-') && !token.contains('0')) {
        lyricIndex++;
      }
      measureRaw.add(token);
      measureNotes.add(
        _PracticeNote(
          raw: token,
          lyric: lyric.isEmpty ? '唱' : lyric,
          solfege: _solfegeForToken(token),
          beats: _beatsForToken(token),
        ),
      );
    }
    flush();
    if (measures.isNotEmpty) {
      measures[measures.length - 1] = measures.last.copyWith(lineBreak: true);
    }
    if (measures.length >= 96) break;
  }

  final phrases = _buildPhrasesFromMeasures(detail, measures);
  return phrases.isEmpty ? _demoMeasures : phrases;
}

List<_PracticeMeasure> _buildPhrasesFromMeasures(
  MusicDetail detail,
  List<_ParsedMeasure> measures,
) {
  final result = <_PracticeMeasure>[];
  final buffer = <_ParsedMeasure>[];

  void flush() {
    if (buffer.isEmpty) return;
    final phraseIndex = result.length + 1;
    final notes = buffer.expand((measure) => measure.notes).toList();
    final raw = buffer.map((measure) => measure.raw.join(' ')).join(' | ');
    final lyricLine = notes
        .where((note) => !note.isHold)
        .map((note) => note.lyric)
        .where((text) => text.isNotEmpty && text != '唱' && text != '停')
        .join(' ');
    result.add(
      _PracticeMeasure(
        focus: _focusForMeasure(notes),
        meter:
            [
              _meterKeyFor(detail),
              detail.timeSignature,
            ].where((text) => text.isNotEmpty).join('  ').trim().isEmpty
            ? '第 $phraseIndex 句'
            : [
                _meterKeyFor(detail),
                detail.timeSignature,
              ].where((text) => text.isNotEmpty).join('  '),
        rhythm: '$raw |',
        lyric: lyricLine.isEmpty ? '第 $phraseIndex 句' : lyricLine,
        tip: _tipForPhrase(notes, buffer.length),
        notes: notes,
      ),
    );
    buffer.clear();
  }

  for (final measure in measures) {
    buffer.add(measure);
    final shouldClose = _shouldClosePhrase(buffer);
    if (shouldClose) flush();
    if (result.length >= 24) break;
  }
  flush();
  return result;
}

bool _shouldClosePhrase(List<_ParsedMeasure> buffer) {
  if (buffer.isEmpty) return false;
  final measureCount = buffer.length;
  final notes = buffer.expand((measure) => measure.notes).toList();
  final last = buffer.last;
  if (measureCount >= 4) return true;
  if (measureCount < 2 && !last.lineBreak) return false;
  final lyricText = notes.map((note) => note.lyric).join('');
  final phrasePunctuation = RegExp(r'[，,。.!！？?；;：:]').hasMatch(lyricText);
  final hasRest = notes.any((note) => note.raw.contains('0'));
  final hasHold = notes.any((note) => note.raw.contains('-'));
  return phrasePunctuation || hasRest || hasHold || last.lineBreak;
}

String _meterKeyFor(MusicDetail detail) {
  final key = _resolvePracticeKey(detail);
  return key.isEmpty ? '' : '1=$key';
}

String _focusForMeasure(List<_PracticeNote> notes) {
  if (notes.any((note) => note.raw.contains('-'))) return '延长音';
  if (notes.any((note) => note.raw.contains('0'))) return '休止';
  if (notes.any((note) => note.raw.contains('_') || note.beats < 1)) {
    return '短音节奏';
  }
  if (notes.any((note) => note.raw.contains("'"))) return '高音';
  return '唱谱';
}

String _tipForMeasure(List<_PracticeNote> notes) {
  if (notes.any((note) => note.raw.contains('-'))) {
    return '横杠表示前一个音继续保持，别重新起音。';
  }
  if (notes.any((note) => note.raw.contains('0'))) {
    return '0 是休止，嘴停住，拍子继续走。';
  }
  if (notes.any((note) => note.raw.contains('_') || note.beats < 1)) {
    return '这一小节有短音，先慢速把半拍位置唱稳。';
  }
  if (notes.any((note) => note.raw.contains("'"))) {
    return '这里出现高音，先听音高再跟唱。';
  }
  return '先听一遍，再唱数字，最后带歌词。';
}

String _tipForPhrase(List<_PracticeNote> notes, int measureCount) {
  final base = _tipForMeasure(notes);
  if (measureCount <= 1) return '$base 这一句较短，可以反复精练。';
  return '$base 当前乐句合并了 $measureCount 个小节，更适合连续唱谱。';
}

double _beatsForToken(String raw) {
  if (raw.contains('-') && !RegExp(r'[0-7]').hasMatch(raw)) return 1;
  final base = raw.contains('=') ? 0.25 : (raw.contains('_') ? 0.5 : 1.0);
  final extended = base + '-'.allMatches(raw).length;
  return raw.contains('.') ? extended * 1.5 : extended;
}

String _solfegeForToken(String raw) {
  final match = RegExp(r'[0-7]').firstMatch(raw);
  if (match == null) return 'hold';
  return switch (match.group(0)) {
    '1' => 'do',
    '2' => 're',
    '3' => 'mi',
    '4' => 'fa',
    '5' => 'sol',
    '6' => 'la',
    '7' => 'si',
    _ => 'rest',
  };
}

const _demoMeasures = [
  _PracticeMeasure(
    focus: '从低 5 进到高 1',
    meter: '1=C  2/4',
    rhythm: '5  1 6  |',
    lyric: '小 兔 子',
    tip: '先唱 sol-do-la，注意 1 上面的点是高音 do。',
    notes: [
      _PracticeNote(raw: '5', lyric: '小', solfege: 'sol', beats: 1),
      _PracticeNote(raw: "1'", lyric: '兔', solfege: 'do', beats: 0.5),
      _PracticeNote(raw: '6', lyric: '子', solfege: 'la', beats: 0.5),
    ],
  ),
  _PracticeMeasure(
    focus: '同音重复',
    meter: '1=C  2/4',
    rhythm: '5  5  |',
    lyric: '乖 乖',
    tip: '两个 5 都要重新唱出来，别拖成一个长音。',
    notes: [
      _PracticeNote(raw: '5', lyric: '乖', solfege: 'sol', beats: 1),
      _PracticeNote(raw: '5', lyric: '乖', solfege: 'sol', beats: 1),
    ],
  ),
  _PracticeMeasure(
    focus: '连线唱法',
    meter: '1=C  2/4',
    rhythm: '⌒ 3 5  6 1 |',
    lyric: '把 门 儿 开 开',
    tip: '3 到 5 有连线，先慢慢连过去，再接 6 和高音 1。',
    notes: [
      _PracticeNote(raw: '3', lyric: '把', solfege: 'mi', beats: 0.5),
      _PracticeNote(raw: '5', lyric: '门', solfege: 'sol', beats: 0.5),
      _PracticeNote(raw: '6', lyric: '儿', solfege: 'la', beats: 0.5),
      _PracticeNote(raw: "1'", lyric: '开', solfege: 'do', beats: 0.5),
      _PracticeNote(raw: '5', lyric: '开', solfege: 'sol', beats: 1),
    ],
  ),
  _PracticeMeasure(
    focus: '下行音阶',
    meter: '1=C  2/4',
    rhythm: '6  5 3  2 2 |',
    lyric: '快 点 儿 开 开',
    tip: '这是 la-sol-mi-re-re，下行时保持每个音清楚。',
    notes: [
      _PracticeNote(raw: '6', lyric: '快', solfege: 'la', beats: 1),
      _PracticeNote(raw: '5', lyric: '点', solfege: 'sol', beats: 0.5),
      _PracticeNote(raw: '3', lyric: '儿', solfege: 'mi', beats: 0.5),
      _PracticeNote(raw: '2', lyric: '开', solfege: 're', beats: 1),
      _PracticeNote(raw: '2', lyric: '开', solfege: 're', beats: 1),
    ],
  ),
  _PracticeMeasure(
    focus: '长音收句',
    meter: '1=C  2/4',
    rhythm: '3 6  5 - |',
    lyric: '我 不 开',
    tip: '最后的横杠要把 5 拉满两拍，唱到节拍结束再停。',
    notes: [
      _PracticeNote(raw: '3', lyric: '我', solfege: 'mi', beats: 0.5),
      _PracticeNote(raw: '6', lyric: '不', solfege: 'la', beats: 0.5),
      _PracticeNote(raw: '5', lyric: '开', solfege: 'sol', beats: 1),
      _PracticeNote(raw: '-', lyric: '延', solfege: 'hold', beats: 1),
    ],
  ),
];
