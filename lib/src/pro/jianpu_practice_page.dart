import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/tone_synth.dart';
import '../data/app_settings.dart';
import '../data/models.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'jianpu_practice_model.dart';

class JianpuPracticePage extends StatefulWidget {
  const JianpuPracticePage({
    super.key,
    required this.settings,
    this.title,
    this.detail,
    this.document,
  });

  static const routeName = '/jianpu-practice';

  final AppSettings settings;
  final String? title;
  final MusicDetail? detail;
  final ScoreDocument? document;

  @override
  State<JianpuPracticePage> createState() => _JianpuPracticePageState();
}

class _JianpuPracticePageState extends State<JianpuPracticePage> {
  final _synth = ToneSynth();
  Timer? _timer;
  late final PracticeLesson _lesson;
  var _phraseIndex = 0;
  var _activeNoteIndex = -1;
  var _playing = false;
  var _loop = true;
  var _mode = PracticeMode.listen;
  var _bpm = 72;
  var _elapsedMs = 0;
  var _lastNoteIndex = -1;
  var _lastBeatIndex = -1;
  var _showSymbols = false;
  var _selectedTopic = 0;

  PracticePhrase get _phrase => _lesson.phrases[_phraseIndex];

  @override
  void initState() {
    super.initState();
    _lesson = buildPracticeLesson(
      title: widget.title,
      detail: widget.detail,
      document: widget.document,
    );
    final sourceBpm = widget.detail?.bpm ?? 0;
    if (sourceBpm > 0) _bpm = sourceBpm.clamp(48, 168);
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
    } else {
      _start();
    }
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
    final totalMs = (_phrase.totalBeats * beatMs).round();
    final elapsed = _elapsedMs + 32;
    final beatIndex = (elapsed / beatMs).floor();
    if (beatIndex != _lastBeatIndex) {
      _lastBeatIndex = beatIndex;
      _synth.playClick(accented: beatIndex % 4 == 0, volume: 0.32);
    }

    final noteIndex = _noteIndexAt(elapsed, beatMs);
    if (noteIndex != _lastNoteIndex) {
      _lastNoteIndex = noteIndex;
      _playPracticeNote(noteIndex, beatMs);
    }

    if (elapsed >= totalMs) {
      if (_loop) {
        setState(() {
          _elapsedMs = 0;
          _activeNoteIndex = -1;
          _lastNoteIndex = -1;
          _lastBeatIndex = -1;
        });
      } else if (_phraseIndex < _lesson.phraseCount - 1) {
        _selectPhrase(_phraseIndex + 1, keepMode: true, autoStart: true);
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

  void _playPracticeNote(int noteIndex, double beatMs) {
    if (noteIndex < 0 || noteIndex >= _phrase.notes.length) return;
    final note = _phrase.notes[noteIndex];
    if (note.isHold || note.isRest) return;
    _synth.playNote(
      raw: note.raw,
      key: _lesson.key,
      durationMs: (note.beats * beatMs).round(),
      volume: _mode == PracticeMode.rhythm ? 0 : 0.58,
      program: widget.settings.melodyInstrumentProgram,
    );
  }

  int _noteIndexAt(int elapsedMs, double beatMs) {
    var cursor = 0.0;
    for (var i = 0; i < _phrase.notes.length; i++) {
      final duration = _phrase.notes[i].beats * beatMs;
      if (elapsedMs >= cursor && elapsedMs < cursor + duration) return i;
      cursor += duration;
    }
    return -1;
  }

  void _selectPhrase(
    int value, {
    bool keepMode = false,
    bool autoStart = false,
  }) {
    _timer?.cancel();
    setState(() {
      _phraseIndex = value.clamp(0, _lesson.phraseCount - 1);
      _playing = false;
      _activeNoteIndex = -1;
      _elapsedMs = 0;
      _lastNoteIndex = -1;
      _lastBeatIndex = -1;
      if (!keepMode) _mode = PracticeMode.listen;
    });
    if (autoStart) _start();
  }

  void _advanceMode() {
    final values = PracticeMode.values;
    final nextModeIndex = values.indexOf(_mode) + 1;
    if (nextModeIndex < values.length) {
      setState(() => _mode = values[nextModeIndex]);
      return;
    }
    if (_phraseIndex < _lesson.phraseCount - 1) {
      _selectPhrase(_phraseIndex + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final progress = (_phraseIndex + 1) / _lesson.phraseCount;
    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: Text(_lesson.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _PracticeHeader(
            lesson: _lesson,
            phrase: _phrase,
            phraseIndex: _phraseIndex,
            progress: progress,
          ),
          const SizedBox(height: 12),
          _ModeBar(
            mode: _mode,
            onChanged: (value) => setState(() => _mode = value),
          ),
          const SizedBox(height: 12),
          _PhraseStage(
            phrase: _phrase,
            mode: _mode,
            activeNoteIndex: _activeNoteIndex,
          ),
          const SizedBox(height: 12),
          _TransportPanel(
            playing: _playing,
            loop: _loop,
            bpm: _bpm,
            phraseIndex: _phraseIndex,
            phraseCount: _lesson.phraseCount,
            onPlay: _togglePlay,
            onPrevious: () => _selectPhrase(_phraseIndex - 1),
            onNext: () => _selectPhrase(_phraseIndex + 1),
            onLoopChanged: (value) => setState(() => _loop = value),
            onBpmChanged: (value) => setState(() => _bpm = value),
          ),
          const SizedBox(height: 12),
          _PhraseNavigator(
            phrases: _lesson.phrases,
            selectedIndex: _phraseIndex,
            onSelected: _selectPhrase,
          ),
          const SizedBox(height: 12),
          _NextActionPanel(mode: _mode, phrase: _phrase, onNext: _advanceMode),
          const SizedBox(height: 12),
          _SymbolPanel(
            expanded: _showSymbols,
            selectedIndex: _selectedTopic,
            onExpandedChanged: (value) => setState(() => _showSymbols = value),
            onSelected: (value) => setState(() => _selectedTopic = value),
          ),
        ],
      ),
    );
  }
}

class _PracticeHeader extends StatelessWidget {
  const _PracticeHeader({
    required this.lesson,
    required this.phrase,
    required this.phraseIndex,
    required this.progress,
  });

  final PracticeLesson lesson;
  final PracticePhrase phrase;
  final int phraseIndex;
  final double progress;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(radiusMedium),
                ),
                child: Icon(
                  AppIcons.recordVoiceOverRounded,
                  color: palette.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.sourceLabel,
                      style: const TextStyle(
                        color: mutedTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '第 ${phraseIndex + 1} 句 · ${phrase.focus}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: inkColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _MeterBadge(text: phrase.meter),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: lineColor,
              valueColor: AlwaysStoppedAnimation<Color>(palette.brand),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${lesson.phraseCount} 个乐句 · ${lesson.totalBeats.toStringAsFixed(1)} 拍 · 1=${lesson.key}',
            style: const TextStyle(
              color: mutedTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterBadge extends StatelessWidget {
  const _MeterBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: softGreenColor,
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: brandDarkColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          height: 1.12,
        ),
      ),
    );
  }
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.mode, required this.onChanged});

  final PracticeMode mode;
  final ValueChanged<PracticeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PracticeMode>(
      segments: [
        for (final item in PracticeMode.values)
          ButtonSegment(
            value: item,
            label: Text(item.label),
            icon: Icon(_iconForMode(item), size: 18),
          ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

class _PhraseStage extends StatelessWidget {
  const _PhraseStage({
    required this.phrase,
    required this.mode,
    required this.activeNoteIndex,
  });

  final PracticePhrase phrase;
  final PracticeMode mode;
  final int activeNoteIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: paperTintColor,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForMode(mode), color: brandColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mode.description,
                  style: const TextStyle(
                    color: inkColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            phrase.rhythm,
            style: const TextStyle(
              color: mutedTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < phrase.notes.length; i++)
                _PracticeNoteTile(
                  note: phrase.notes[i],
                  active: i == activeNoteIndex,
                  mode: mode,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _LineLabel(label: '当前目标', text: _primaryTextFor(mode, phrase)),
          const SizedBox(height: 7),
          _LineLabel(
            label: '对照',
            text: _secondaryTextFor(mode, phrase),
            muted: true,
          ),
        ],
      ),
    );
  }
}

class _PracticeNoteTile extends StatelessWidget {
  const _PracticeNoteTile({
    required this.note,
    required this.active,
    required this.mode,
  });

  final PracticeNote note;
  final bool active;
  final PracticeMode mode;

  @override
  Widget build(BuildContext context) {
    final main = switch (mode) {
      PracticeMode.listen => note.display,
      PracticeMode.rhythm => note.beatText,
      PracticeMode.solfege => note.display,
      PracticeMode.lyric => note.lyric,
    };
    final sub = switch (mode) {
      PracticeMode.listen => note.solfege,
      PracticeMode.rhythm => note.display,
      PracticeMode.solfege => note.solfege,
      PracticeMode.lyric => note.display,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 52,
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      decoration: BoxDecoration(
        color: active ? accentColor : softGreenColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radiusMedium),
        border: Border.all(color: active ? accentColor : lineColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            main,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? Colors.white : inkColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
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

class _LineLabel extends StatelessWidget {
  const _LineLabel({
    required this.label,
    required this.text,
    this.muted = false,
  });

  final String label;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(
              color: mutedTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: muted ? mutedTextColor : brandDarkColor,
              fontSize: muted ? 13 : 16,
              height: 1.28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransportPanel extends StatelessWidget {
  const _TransportPanel({
    required this.playing,
    required this.loop,
    required this.bpm,
    required this.phraseIndex,
    required this.phraseCount,
    required this.onPlay,
    required this.onPrevious,
    required this.onNext,
    required this.onLoopChanged,
    required this.onBpmChanged,
  });

  final bool playing;
  final bool loop;
  final int bpm;
  final int phraseIndex;
  final int phraseCount;
  final VoidCallback onPlay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<bool> onLoopChanged;
  final ValueChanged<int> onBpmChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: paperTintColor,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: '上一句',
                onPressed: phraseIndex == 0 ? null : onPrevious,
                icon: const Icon(AppIcons.skipPreviousRounded),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onPlay,
                icon: Icon(
                  playing ? AppIcons.pauseRounded : AppIcons.playArrowRounded,
                ),
                label: Text(playing ? '暂停' : '播放'),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '下一句',
                onPressed: phraseIndex >= phraseCount - 1 ? null : onNext,
                icon: const Icon(AppIcons.skipNextRounded),
              ),
              const Spacer(),
              FilterChip(
                label: const Text('循环'),
                selected: loop,
                onSelected: onLoopChanged,
                avatar: const Icon(AppIcons.loopRounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$bpm BPM',
                style: const TextStyle(
                  color: brandDarkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: Slider(
                  min: 48,
                  max: 132,
                  divisions: 84,
                  value: bpm.toDouble(),
                  label: '$bpm BPM',
                  onChanged: (value) => onBpmChanged(value.round()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhraseNavigator extends StatelessWidget {
  const _PhraseNavigator({
    required this.phrases,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PracticePhrase> phrases;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: paperTintColor,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '乐句列表',
            style: TextStyle(
              color: inkColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: phrases.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final phrase = phrases[index];
                final selected = index == selectedIndex;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => onSelected(index),
                  label: SizedBox(
                    width: 82,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '第 ${index + 1} 句',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          phrase.focus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActionPanel extends StatelessWidget {
  const _NextActionPanel({
    required this.mode,
    required this.phrase,
    required this.onNext,
  });

  final PracticeMode mode;
  final PracticePhrase phrase;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      PracticeMode.listen => '下一步：读拍',
      PracticeMode.rhythm => '下一步：唱谱',
      PracticeMode.solfege => '下一步：带词',
      PracticeMode.lyric => '下一乐句',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softGreenColor.withValues(alpha: 0.62),
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              phrase.tip,
              style: const TextStyle(
                color: inkColor,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onNext,
            icon: const Icon(AppIcons.arrowForwardRounded),
            label: Text(label),
          ),
        ],
      ),
    );
  }
}

class _SymbolPanel extends StatelessWidget {
  const _SymbolPanel({
    required this.expanded,
    required this.selectedIndex,
    required this.onExpandedChanged,
    required this.onSelected,
  });

  final bool expanded;
  final int selectedIndex;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final topic = practiceSymbolTopics[selectedIndex];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: paperTintColor,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: expanded,
            title: const Text('简谱符号说明'),
            subtitle: const Text('练习时可收起，减少干扰'),
            secondary: const Icon(AppIcons.schoolOutlined),
            onChanged: onExpandedChanged,
          ),
          if (expanded) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < practiceSymbolTopics.length; i++)
                  ChoiceChip(
                    label: Text(practiceSymbolTopics[i].symbol),
                    selected: i == selectedIndex,
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
                  Text(
                    '${topic.symbol}  ${topic.title}',
                    style: const TextStyle(
                      color: brandDarkColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic.explanation,
                    style: const TextStyle(
                      color: inkColor,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
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

IconData _iconForMode(PracticeMode mode) {
  return switch (mode) {
    PracticeMode.listen => AppIcons.hearingRounded,
    PracticeMode.rhythm => AppIcons.speedRounded,
    PracticeMode.solfege => AppIcons.recordVoiceOverRounded,
    PracticeMode.lyric => AppIcons.lyricsRounded,
  };
}

String _primaryTextFor(PracticeMode mode, PracticePhrase phrase) {
  return switch (mode) {
    PracticeMode.listen => '听旋律走向，不急着开口',
    PracticeMode.rhythm => phrase.beatLine,
    PracticeMode.solfege => phrase.solfegeLine,
    PracticeMode.lyric => phrase.lyric,
  };
}

String _secondaryTextFor(PracticeMode mode, PracticePhrase phrase) {
  return switch (mode) {
    PracticeMode.listen => phrase.solfegeLine,
    PracticeMode.rhythm => phrase.lyric,
    PracticeMode.solfege => phrase.lyric,
    PracticeMode.lyric => phrase.solfegeLine,
  };
}
