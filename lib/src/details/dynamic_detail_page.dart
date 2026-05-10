import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/tone_synth.dart';
import '../data/app_settings.dart';
import '../data/key_transpose.dart';
import '../data/favorites_store.dart';
import '../data/jianpu_api.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/jianpu_score_view.dart';

class DynamicDetailPage extends StatefulWidget {
  const DynamicDetailPage({
    super.key,
    required this.api,
    required this.song,
    required this.favorites,
    required this.settings,
  });

  final JianpuApi api;
  final MusicSummary song;
  final FavoritesStore favorites;
  final AppSettings settings;

  @override
  State<DynamicDetailPage> createState() => _DynamicDetailPageState();
}

class _DynamicDetailPageState extends State<DynamicDetailPage> {
  final _scrollController = ScrollController();
  final _synth = ToneSynth();
  Timer? _scrollTimer;
  MusicDetail? _detail;
  ScoreDocument? _document;
  List<_TimedNote> _timedNotes = const [];
  Object? _error;
  var _loading = true;
  var _zoom = 0.84;
  var _playing = false;
  var _speed = 0.28;
  var _soundEnabled = true;
  var _rewriteNotation = false;
  var _volume = 0.68;
  var _selectedKey = '';
  var _activeNoteIndex = -1;
  var _lastSoundNoteIndex = -1;
  var _elapsedMs = 0;

  @override
  void initState() {
    super.initState();
    _soundEnabled = widget.settings.defaultSoundEnabled;
    widget.favorites.addListener(_onFavoriteChanged);
    _load();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _synth.dispose();
    _scrollController.dispose();
    widget.favorites.removeListener(_onFavoriteChanged);
    super.dispose();
  }

  void _onFavoriteChanged() => setState(() {});

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.api.fetchDynamicDetail(widget.song.id);
      final text = await widget.api.fetchScoreText(detail.scorePath);
      final document = ScoreDocument.parse(text);
      _detail = detail;
      _document = document;
      _timedNotes = _buildTimedNotes(document, detail);
      _selectedKey = detail.selectedKey.isEmpty
          ? detail.originalKey
          : detail.selectedKey;
      _activeNoteIndex = -1;
      _lastSoundNoteIndex = -1;
      _elapsedMs = 0;
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _togglePlay() {
    if (!_playing &&
        _timedNotes.isNotEmpty &&
        _elapsedMs >= _timedNotes.last.endMs) {
      _elapsedMs = 0;
      _lastSoundNoteIndex = -1;
    }
    setState(() => _playing = !_playing);
    _scrollTimer?.cancel();
    if (!_playing) return;
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 48), (_) {
      if (!mounted) return;
      _elapsedMs += 48;
      final noteIndex = _noteIndexAt(_elapsedMs);
      if (noteIndex != _lastSoundNoteIndex) {
        _lastSoundNoteIndex = noteIndex;
        _playTimedNote(noteIndex);
      }
      setState(() => _activeNoteIndex = noteIndex);
      if (_scrollController.hasClients && _speed > 0) {
        final next = math.min(
          _scrollController.position.maxScrollExtent,
          _scrollController.offset + _speed,
        );
        _scrollController.jumpTo(next);
      }
      if (_timedNotes.isNotEmpty && _elapsedMs >= _timedNotes.last.endMs) {
        _scrollTimer?.cancel();
        setState(() {
          _playing = false;
          _activeNoteIndex = -1;
          _lastSoundNoteIndex = -1;
          _elapsedMs = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final favorite = widget.favorites.contains(
      ScoreKind.dynamic,
      '${widget.song.id}',
    );
    final title = detail?.title.isNotEmpty == true
        ? detail!.title
        : widget.song.title;
    final subtitle = detail?.singer.isNotEmpty == true
        ? detail!.singer
        : '动态简谱';

    return Scaffold(
      backgroundColor: paperColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 62,
            decoration: const BoxDecoration(
              color: paperTintColor,
              border: Border(bottom: BorderSide(color: lineColor)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _ToolbarButton(
                  tooltip: '返回',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: inkColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: mutedTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                _ToolbarButton(
                  tooltip: favorite ? '取消收藏' : '收藏',
                  icon: favorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  onPressed: detail == null
                      ? null
                      : () => widget.favorites.toggle(_favoriteFor(detail)),
                ),
                IconButton(
                  tooltip: '设置',
                  onPressed: detail == null
                      ? null
                      : () => _openSettings(detail, favorite),
                  icon: const Icon(Icons.tune_rounded, size: 25),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(40, 40),
                    foregroundColor: brandDarkColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _ReaderControls(
        playing: _playing,
        soundEnabled: _soundEnabled,
        speed: _speed,
        selectedKey: _selectedKey,
        onPlay: _togglePlay,
        onSoundToggle: () => setState(() => _soundEnabled = !_soundEnabled),
        onSpeedChanged: (value) => setState(() => _speed = value),
        onSettings: detail == null
            ? null
            : () => _openSettings(detail, favorite),
      ),
      body: _buildDetailBody(),
    );
  }

  Widget _buildDetailBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return StateView(
        icon: Icons.error_outline_rounded,
        title: '谱面加载失败',
        message: '$_error',
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 26),
        child: InteractiveViewer(
          minScale: 0.78,
          maxScale: 2,
          boundaryMargin: const EdgeInsets.all(80),
          child: Align(
            alignment: Alignment.topCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: paperTintColor,
                border: Border.all(color: lineColor),
                borderRadius: BorderRadius.circular(radiusMedium),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_activeNoteIndex),
                  tween: Tween(begin: 0.35, end: 1),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  builder: (context, pulse, _) {
                    return JianpuScoreView(
                      document: _document!,
                      detail: _detail!,
                      zoom: _zoom,
                      activeNoteIndex: _activeNoteIndex,
                      activePulse: pulse,
                      selectedKey: _selectedKey,
                      rewriteNotation: _rewriteNotation,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _noteIndexAt(int elapsedMs) {
    for (final timed in _timedNotes) {
      if (elapsedMs >= timed.startMs && elapsedMs < timed.endMs) {
        return timed.noteIndex;
      }
    }
    return -1;
  }

  void _playTimedNote(int noteIndex) {
    if (!_soundEnabled || noteIndex < 0 || noteIndex >= _timedNotes.length) {
      return;
    }
    final timed = _timedNotes[noteIndex];
    final detail = _detail;
    if (detail == null) return;
    final raw = _rewriteNotation
        ? transposeJianpuToken(
            raw: timed.raw,
            fromKey: detail.selectedKey,
            toKey: _selectedKey,
          )
        : timed.raw;
    _synth.playNote(
      raw: raw,
      key: _selectedKey,
      durationMs: timed.endMs - timed.startMs,
      volume: _volume,
    );
  }

  List<_TimedNote> _buildTimedNotes(
    ScoreDocument document,
    MusicDetail detail,
  ) {
    final beatMs = detail.bpm <= 0 ? 1000.0 : 60000 / detail.bpm;
    var cursor = 0.0;
    var noteIndex = 0;
    final result = <_TimedNote>[];

    for (final line in document.notation) {
      final matches = RegExp(r'\||[^\s|]+').allMatches(line);
      for (final match in matches) {
        final raw = match.group(0)!.trim();
        if (raw.isEmpty || raw == '|' || RegExp(r'^\d+/\d+$').hasMatch(raw)) {
          continue;
        }
        final beats = _beatsFor(raw);
        final durationMs = math.max(80.0, beats * beatMs);
        result.add(
          _TimedNote(
            noteIndex: noteIndex,
            raw: raw,
            startMs: cursor.round(),
            endMs: (cursor + durationMs).round(),
          ),
        );
        noteIndex++;
        cursor += durationMs;
      }
    }
    return result;
  }

  double _beatsFor(String raw) {
    final base = raw.contains('=') ? 0.25 : (raw.contains('_') ? 0.5 : 1.0);
    final extended = base + '-'.allMatches(raw).length;
    return raw.contains('.') ? extended * 1.5 : extended;
  }

  void _openSettings(MusicDetail detail, bool favorite) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    18 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '谱面设置',
                            style: TextStyle(
                              color: inkColor,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SettingsSection(
                      title: '谱面',
                      icon: Icons.visibility_outlined,
                      children: [
                        _SettingSlider(
                          label: '谱面大小',
                          value: _zoom,
                          min: 0.72,
                          max: 1.28,
                          divisions: 14,
                          onChanged: (value) {
                            setState(() => _zoom = value);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      title: '播放',
                      icon: Icons.play_circle_outline_rounded,
                      children: [
                        _SettingSlider(
                          label: '滚动速度',
                          value: _speed,
                          min: 0,
                          max: 3,
                          divisions: 12,
                          onChanged: (value) {
                            setState(() => _speed = value);
                            setSheetState(() {});
                          },
                        ),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _soundEnabled,
                          title: const Text('按节拍发声'),
                          subtitle: Text(
                            _soundEnabled ? '播放时合成当前音阶' : '只高亮当前音符',
                          ),
                          onChanged: (value) {
                            setState(() => _soundEnabled = value);
                            setSheetState(() {});
                          },
                        ),
                        _SettingSlider(
                          label: '音量',
                          value: _volume,
                          min: 0,
                          max: 1,
                          divisions: 10,
                          onChanged: (value) {
                            setState(() => _volume = value);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      title: '调式',
                      icon: Icons.piano_outlined,
                      children: [
                        _KeySelector(
                          selectedKey: _selectedKey,
                          onSelected: (key) {
                            setState(() => _selectedKey = key);
                            setSheetState(() {});
                          },
                        ),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _rewriteNotation,
                          title: const Text('固定调显示'),
                          subtitle: const Text('打开后数字会随调门重新换算'),
                          onChanged: (value) {
                            setState(() => _rewriteNotation = value);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          widget.favorites.toggle(_favoriteFor(detail));
                          Navigator.of(context).pop();
                        },
                        icon: Icon(
                          favorite
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                        ),
                        label: Text(favorite ? '取消收藏' : '收藏谱子'),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  FavoriteItem _favoriteFor(MusicDetail detail) {
    return FavoriteItem(
      kind: ScoreKind.dynamic,
      id: '${detail.id}',
      title: detail.title,
      subtitle: [
        if (detail.singer.isNotEmpty) detail.singer,
        if (detail.arranger.isNotEmpty) '编: ${detail.arranger}',
      ].join(' · '),
      scorePath: detail.scorePath,
    );
  }
}

class _TimedNote {
  const _TimedNote({
    required this.noteIndex,
    required this.raw,
    required this.startMs,
    required this.endMs,
  });

  final int noteIndex;
  final String raw;
  final int startMs;
  final int endMs;
}

class _ReaderControls extends StatelessWidget {
  const _ReaderControls({
    required this.playing,
    required this.soundEnabled,
    required this.speed,
    required this.selectedKey,
    required this.onPlay,
    required this.onSoundToggle,
    required this.onSpeedChanged,
    required this.onSettings,
  });

  final bool playing;
  final bool soundEnabled;
  final double speed;
  final String selectedKey;
  final VoidCallback onPlay;
  final VoidCallback onSoundToggle;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 66,
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
        decoration: const BoxDecoration(
          color: paperTintColor,
          border: Border(top: BorderSide(color: lineColor)),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: playing ? accentColor : brandColor,
                borderRadius: BorderRadius.circular(radiusMedium),
              ),
              child: IconButton(
                tooltip: playing ? '暂停' : '播放',
                onPressed: onPlay,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey(playing),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: soundEnabled ? '关闭声音' : '打开声音',
              onPressed: onSoundToggle,
              icon: Icon(
                soundEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: soundEnabled ? brandColor : mutedTextColor,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: softGreenColor,
                borderRadius: BorderRadius.circular(radiusMedium),
              ),
              alignment: Alignment.center,
              child: Text(
                selectedKey.isEmpty ? '1=-' : '1=$selectedKey',
                style: const TextStyle(
                  color: brandDarkColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.speed_rounded, size: 18, color: mutedTextColor),
            Expanded(
              child: Slider(
                min: 0,
                max: 3,
                divisions: 12,
                value: speed,
                label: speed.toStringAsFixed(1),
                onChanged: onSpeedChanged,
              ),
            ),
            IconButton(
              tooltip: '设置',
              onPressed: onSettings,
              icon: const Icon(Icons.tune_rounded, color: brandDarkColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: brandDarkColor, size: 27),
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        foregroundColor: brandDarkColor,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
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
              Icon(icon, color: brandColor, size: 20),
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
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _KeySelector extends StatelessWidget {
  const _KeySelector({required this.selectedKey, required this.onSelected});

  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选调',
            style: TextStyle(
              color: mutedTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in jianpuKeys)
                ChoiceChip(
                  label: Text('1=$key'),
                  selected: key == selectedKey,
                  onSelected: (_) => onSelected(key),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              color: mutedTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
