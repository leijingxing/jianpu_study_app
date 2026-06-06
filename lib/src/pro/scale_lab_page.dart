import 'package:flutter/material.dart';

import '../audio/tone_synth.dart';
import '../data/app_settings.dart';
import '../data/key_transpose.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class ScaleLabPage extends StatefulWidget {
  const ScaleLabPage({super.key, required this.settings});

  static const routeName = '/scale-lab';

  final AppSettings settings;

  @override
  State<ScaleLabPage> createState() => _ScaleLabPageState();
}

class _ScaleLabPageState extends State<ScaleLabPage> {
  final _synth = ToneSynth();
  var _key = 'C';
  var _volume = 0.72;
  var _durationMs = 520;
  String? _activeNote;

  @override
  void dispose() {
    _synth.dispose();
    super.dispose();
  }

  Future<void> _play(_ScaleNote note) async {
    setState(() => _activeNote = note.raw);
    await _synth.playNote(
      raw: note.raw,
      key: _key,
      durationMs: _durationMs,
      volume: _volume,
      program: widget.settings.melodyInstrumentProgram,
    );
    if (!mounted || _activeNote != note.raw) return;
    Future<void>.delayed(Duration(milliseconds: _durationMs), () {
      if (mounted && _activeNote == note.raw) {
        setState(() => _activeNote = null);
      }
    });
  }

  void _playSection(_ScaleSection section) {
    var delay = Duration.zero;
    for (final note in section.notes) {
      Future<void>.delayed(delay, () {
        if (mounted) _play(note);
      });
      delay += Duration(milliseconds: (_durationMs * 0.68).round());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) {
        final instrument = melodyInstruments.firstWhere(
          (item) => item.program == widget.settings.melodyInstrumentProgram,
          orElse: () => melodyInstruments.first,
        );
        return Scaffold(
          backgroundColor: palette.paper,
          appBar: AppBar(title: const Text('音阶实验室')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _ScaleHero(instrument: instrument, keyName: _key),
              const SizedBox(height: 12),
              _ControlPanel(
                selectedProgram: widget.settings.melodyInstrumentProgram,
                keyName: _key,
                volume: _volume,
                durationMs: _durationMs,
                onInstrumentChanged: widget.settings.setMelodyInstrumentProgram,
                onKeyChanged: (value) => setState(() => _key = value),
                onVolumeChanged: (value) => setState(() => _volume = value),
                onDurationChanged: (value) =>
                    setState(() => _durationMs = value),
              ),
              const SizedBox(height: 12),
              for (final section in _scaleSections) ...[
                _ScaleSectionPanel(
                  section: section,
                  activeNote: _activeNote,
                  onPlay: _play,
                  onPlaySection: () => _playSection(section),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ScaleHero extends StatelessWidget {
  const _ScaleHero({required this.instrument, required this.keyName});

  final MelodyInstrument instrument;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(radiusMedium),
              border: Border.all(color: palette.line),
            ),
            child: Icon(AppIcons.pianoOutlined, color: palette.brand, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '完整音域试音',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '1=$keyName · ${instrument.name} · ${instrument.group}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.selectedProgram,
    required this.keyName,
    required this.volume,
    required this.durationMs,
    required this.onInstrumentChanged,
    required this.onKeyChanged,
    required this.onVolumeChanged,
    required this.onDurationChanged,
  });

  final int selectedProgram;
  final String keyName;
  final double volume;
  final int durationMs;
  final ValueChanged<int> onInstrumentChanged;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<int> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(icon: AppIcons.tuneRounded, title: '演奏设置'),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: selectedProgram,
            decoration: const InputDecoration(
              labelText: '音色',
              prefixIcon: Icon(AppIcons.libraryMusicOutlined),
            ),
            items: [
              for (final instrument in melodyInstruments)
                DropdownMenuItem(
                  value: instrument.program,
                  child: Text('${instrument.name} · ${instrument.group}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) onInstrumentChanged(value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: keyName,
            decoration: const InputDecoration(
              labelText: '调号',
              prefixIcon: Icon(AppIcons.musicNoteRounded),
            ),
            items: [
              for (final key in jianpuKeys)
                DropdownMenuItem(value: key, child: Text('1=$key')),
            ],
            onChanged: (value) {
              if (value != null) onKeyChanged(value);
            },
          ),
          const SizedBox(height: 12),
          _SliderRow(
            icon: AppIcons.volumeUpRounded,
            label: '音量',
            valueLabel: '${(volume * 100).round()}%',
            value: volume,
            min: 0.1,
            max: 1,
            divisions: 9,
            onChanged: onVolumeChanged,
          ),
          _SliderRow(
            icon: AppIcons.timerRounded,
            label: '时值',
            valueLabel: '${durationMs}ms',
            value: durationMs.toDouble(),
            min: 180,
            max: 900,
            divisions: 12,
            onChanged: (value) => onDurationChanged(value.round()),
          ),
        ],
      ),
    );
  }
}

class _ScaleSectionPanel extends StatelessWidget {
  const _ScaleSectionPanel({
    required this.section,
    required this.activeNote,
    required this.onPlay,
    required this.onPlaySection,
  });

  final _ScaleSection section;
  final String? activeNote;
  final ValueChanged<_ScaleNote> onPlay;
  final VoidCallback onPlaySection;

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
              Expanded(
                child: _PanelTitle(icon: section.icon, title: section.title),
              ),
              IconButton(
                tooltip: '顺序播放',
                onPressed: onPlaySection,
                icon: const Icon(AppIcons.playArrowRounded),
                style: IconButton.styleFrom(
                  fixedSize: const Size(38, 38),
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  backgroundColor: palette.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radiusMedium),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            section.subtitle,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: section.notes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final note = section.notes[index];
                return _ScaleKey(
                  note: note,
                  active: activeNote == note.raw,
                  accent: section.accent,
                  onTap: () => onPlay(note),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleKey extends StatelessWidget {
  const _ScaleKey({
    required this.note,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final _ScaleNote note;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final fill = active ? accent : palette.paperTint;
    final foreground = active
        ? Theme.of(context).colorScheme.onPrimary
        : palette.text;
    return SizedBox(
      width: 62,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radiusMedium),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(
                color: active ? accent : palette.line,
                width: active ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(radiusMedium),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.24),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(
                            context,
                          ).colorScheme.onPrimary.withValues(alpha: 0.75)
                        : palette.soft,
                    borderRadius: BorderRadius.circular(radiusSmall),
                  ),
                ),
                const Spacer(),
                Text(
                  note.degree,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  note.octaveLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? Theme.of(
                            context,
                          ).colorScheme.onPrimary.withValues(alpha: 0.84)
                        : palette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: palette.brand, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Row(
      children: [
        Icon(icon, color: palette.brand, size: 20),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: TextStyle(
              color: palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 58,
          child: Text(
            valueLabel,
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

class _ScaleSection {
  const _ScaleSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.notes,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<_ScaleNote> notes;
}

class _ScaleNote {
  const _ScaleNote({
    required this.degree,
    required this.raw,
    required this.octaveLabel,
  });

  final String degree;
  final String raw;
  final String octaveLabel;
}

const _scaleSections = [
  _ScaleSection(
    title: '低音区',
    subtitle: '逗号标记，适合听辨低音支撑',
    icon: AppIcons.keyboardDoubleArrowDownRounded,
    accent: Color(0xFF4E6570),
    notes: [
      _ScaleNote(degree: '1', raw: '1,,', octaveLabel: '倍低音'),
      _ScaleNote(degree: '2', raw: '2,,', octaveLabel: '倍低音'),
      _ScaleNote(degree: '3', raw: '3,,', octaveLabel: '倍低音'),
      _ScaleNote(degree: '4', raw: '4,,', octaveLabel: '倍低音'),
      _ScaleNote(degree: '5', raw: '5,,', octaveLabel: '倍低音'),
      _ScaleNote(degree: '6', raw: '6,,', octaveLabel: '倍低音'),
      _ScaleNote(degree: '7', raw: '7,,', octaveLabel: '倍低音'),
      _ScaleNote(degree: '1', raw: '1,', octaveLabel: '低音'),
      _ScaleNote(degree: '2', raw: '2,', octaveLabel: '低音'),
      _ScaleNote(degree: '3', raw: '3,', octaveLabel: '低音'),
      _ScaleNote(degree: '4', raw: '4,', octaveLabel: '低音'),
      _ScaleNote(degree: '5', raw: '5,', octaveLabel: '低音'),
      _ScaleNote(degree: '6', raw: '6,', octaveLabel: '低音'),
      _ScaleNote(degree: '7', raw: '7,', octaveLabel: '低音'),
    ],
  ),
  _ScaleSection(
    title: '中音区',
    subtitle: '常用唱谱音区，点击反馈最直接',
    icon: AppIcons.hearingRounded,
    accent: brandColor,
    notes: [
      _ScaleNote(degree: '1', raw: '1', octaveLabel: '中音'),
      _ScaleNote(degree: '2', raw: '2', octaveLabel: '中音'),
      _ScaleNote(degree: '3', raw: '3', octaveLabel: '中音'),
      _ScaleNote(degree: '4', raw: '4', octaveLabel: '中音'),
      _ScaleNote(degree: '5', raw: '5', octaveLabel: '中音'),
      _ScaleNote(degree: '6', raw: '6', octaveLabel: '中音'),
      _ScaleNote(degree: '7', raw: '7', octaveLabel: '中音'),
    ],
  ),
  _ScaleSection(
    title: '高音区',
    subtitle: '撇号标记，用来熟悉旋律上行和高音落点',
    icon: AppIcons.keyboardDoubleArrowUpRounded,
    accent: accentColor,
    notes: [
      _ScaleNote(degree: '1', raw: "1'", octaveLabel: '高音'),
      _ScaleNote(degree: '2', raw: "2'", octaveLabel: '高音'),
      _ScaleNote(degree: '3', raw: "3'", octaveLabel: '高音'),
      _ScaleNote(degree: '4', raw: "4'", octaveLabel: '高音'),
      _ScaleNote(degree: '5', raw: "5'", octaveLabel: '高音'),
      _ScaleNote(degree: '6', raw: "6'", octaveLabel: '高音'),
      _ScaleNote(degree: '7', raw: "7'", octaveLabel: '高音'),
      _ScaleNote(degree: '1', raw: "1''", octaveLabel: '倍高音'),
      _ScaleNote(degree: '2', raw: "2''", octaveLabel: '倍高音'),
      _ScaleNote(degree: '3', raw: "3''", octaveLabel: '倍高音'),
      _ScaleNote(degree: '4', raw: "4''", octaveLabel: '倍高音'),
      _ScaleNote(degree: '5', raw: "5''", octaveLabel: '倍高音'),
      _ScaleNote(degree: '6', raw: "6''", octaveLabel: '倍高音'),
      _ScaleNote(degree: '7', raw: "7''", octaveLabel: '倍高音'),
    ],
  ),
];
