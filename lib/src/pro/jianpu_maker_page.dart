import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/tone_synth.dart';
import '../data/app_settings.dart';
import '../data/key_transpose.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/jianpu_score_view.dart';
import 'jianpu_local_score_store.dart';
import 'jianpu_maker_model.dart';

enum _MakerMenuAction { backspace, newDraft }

class JianpuMakerPage extends StatefulWidget {
  const JianpuMakerPage({
    super.key,
    required this.settings,
    this.initialDraft,
    this.localScoreId,
  });

  static const routeName = '/jianpu-maker';

  final AppSettings settings;
  final JianpuMakerDraft? initialDraft;
  final String? localScoreId;

  @override
  State<JianpuMakerPage> createState() => _JianpuMakerPageState();
}

class _JianpuMakerPageState extends State<JianpuMakerPage> {
  static const _draftKey = 'jianpu_maker_draft_v1';
  static const _timeSignatures = ['2/4', '3/4', '4/4', '6/8'];
  static const _legacyStarterTokens = [
    '|',
    '1',
    '2',
    '3',
    '5',
    '|',
    '6',
    '5',
    '3',
    '2',
    '|',
  ];

  final _synth = ToneSynth();
  final _titleController = TextEditingController();
  final _singerController = TextEditingController();
  final _composerController = TextEditingController();
  final _lyricistController = TextEditingController();
  final _arrangerController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _previewBoundaryKey = GlobalKey();
  Timer? _saveTimer;

  var _draft = JianpuMakerDraft.starter();
  String? _localScoreId;
  var _tokens = <String>[];
  var _keyName = 'C';
  var _timeSignature = '4/4';
  var _bpm = 88;
  var _selectedDegree = '1';
  var _octave = 0;
  var _duration = JianpuNoteDuration.quarter;
  var _previewZoom = 0.78;
  var _loadingDraft = true;
  var _saved = true;
  var _previewPlaying = false;
  var _previewRunId = 0;

  @override
  void initState() {
    super.initState();
    _localScoreId = widget.localScoreId;
    if (widget.initialDraft != null) {
      _draft = widget.initialDraft!;
    }
    _applyDraft(_draft, notify: false);
    _titleController.addListener(_onTextChanged);
    _singerController.addListener(_onTextChanged);
    _composerController.addListener(_onTextChanged);
    _lyricistController.addListener(_onTextChanged);
    _arrangerController.addListener(_onTextChanged);
    _lyricsController.addListener(_onTextChanged);
    _loadDraft();
  }

  @override
  void dispose() {
    _previewRunId++;
    _saveTimer?.cancel();
    _synth.dispose();
    _titleController.dispose();
    _singerController.dispose();
    _composerController.dispose();
    _lyricistController.dispose();
    _arrangerController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    if (widget.initialDraft != null) {
      if (mounted) setState(() => _loadingDraft = false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final savedDraft = JianpuMakerDraft.fromJson(decoded);
        _applyDraft(
          _isLegacyStarterDraft(savedDraft)
              ? JianpuMakerDraft.starter()
              : savedDraft,
          notify: false,
        );
      }
    }
    if (mounted) setState(() => _loadingDraft = false);
  }

  bool _isLegacyStarterDraft(JianpuMakerDraft draft) {
    if (draft.title != '我的简谱' || draft.lyricsText.isNotEmpty) return false;
    if (draft.tokens.length != _legacyStarterTokens.length) return false;
    for (var i = 0; i < draft.tokens.length; i++) {
      if (draft.tokens[i] != _legacyStarterTokens[i]) return false;
    }
    return true;
  }

  void _applyDraft(JianpuMakerDraft draft, {required bool notify}) {
    _draft = draft;
    _tokens = draft.tokens.toList();
    _keyName = draft.keyName;
    _timeSignature = draft.timeSignature;
    _bpm = draft.bpm;
    _setText(_titleController, draft.title);
    _setText(_singerController, draft.singer);
    _setText(_composerController, draft.composer);
    _setText(_lyricistController, draft.lyricist);
    _setText(_arrangerController, draft.arranger);
    _setText(_lyricsController, draft.lyricsText);
    if (notify) {
      setState(() {});
      _saveSoon();
    }
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.text = value;
  }

  void _onTextChanged() {
    if (_loadingDraft) return;
    _refreshDraft();
  }

  void _refreshDraft() {
    _draft = JianpuMakerDraft(
      title: _titleController.text.trim().isEmpty
          ? '未命名简谱'
          : _titleController.text.trim(),
      singer: _singerController.text.trim(),
      composer: _composerController.text.trim(),
      lyricist: _lyricistController.text.trim(),
      arranger: _arrangerController.text.trim(),
      keyName: _keyName,
      timeSignature: _timeSignature,
      bpm: _bpm,
      tokens: _tokens.toList(),
      lyricsText: _lyricsController.text.trim(),
    );
    setState(() => _saved = false);
    _saveSoon();
  }

  void _saveSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 360), _saveNow);
  }

  Future<void> _saveNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, _draft.encode());
    if (mounted) setState(() => _saved = true);
  }

  void _insertCurrentNote() {
    _insertToken(
      buildJianpuToken(
        degree: _selectedDegree,
        octave: _octave,
        duration: _duration,
      ),
    );
  }

  void _insertToken(String token) {
    _previewRunId++;
    setState(() {
      _previewPlaying = false;
      _tokens = [..._tokens, token];
    });
    _refreshDraft();
    if (token != '|') _playToken(token);
  }

  void _deleteLastToken() {
    if (_tokens.isEmpty) return;
    _previewRunId++;
    setState(() {
      _previewPlaying = false;
      _tokens = _tokens.sublist(0, _tokens.length - 1);
    });
    _refreshDraft();
  }

  void _removeTokenAt(int index) {
    if (index < 0 || index >= _tokens.length) return;
    final next = _tokens.toList()..removeAt(index);
    _previewRunId++;
    setState(() {
      _previewPlaying = false;
      _tokens = next;
    });
    _refreshDraft();
  }

  void _clearTokens() {
    if (_tokens.isEmpty) return;
    _previewRunId++;
    setState(() {
      _previewPlaying = false;
      _tokens = [];
    });
    _refreshDraft();
  }

  void _newDraft() {
    _previewRunId++;
    _previewPlaying = false;
    _localScoreId = null;
    _applyDraft(JianpuMakerDraft.starter(), notify: true);
  }

  Future<void> _saveToLocalLibrary() async {
    _refreshDraft();
    final store = JianpuLocalScoreStore();
    await store.load();
    final savedItem = await store.saveDraft(
      draft: _draft,
      existingId: _localScoreId,
    );
    _localScoreId = savedItem.id;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已保存到本地：${savedItem.title}')));
  }

  Future<void> _exportImage() async {
    if (_tokens.isEmpty) return;
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _previewBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final fileName = _safeFileName(_draft.title);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    try {
      await Gal.putImageBytes(
        bytes.buffer.asUint8List(),
        name: '${fileName}_$stamp',
      );
    } on GalException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_galleryErrorMessage(error.type))));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存到系统相册')));
  }

  String _galleryErrorMessage(GalExceptionType type) {
    return switch (type) {
      GalExceptionType.accessDenied => '没有相册写入权限',
      GalExceptionType.notEnoughSpace => '设备空间不足，无法保存图片',
      GalExceptionType.notSupportedFormat => '图片格式不支持',
      GalExceptionType.unexpected => '保存到相册失败',
    };
  }

  String _safeFileName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.isEmpty ? 'jianpu' : cleaned;
  }

  Future<void> _playToken(String raw, {int durationMs = 420}) async {
    await _synth.playNote(
      raw: raw,
      key: _keyName,
      durationMs: durationMs,
      volume: 0.72,
      program: widget.settings.melodyInstrumentProgram,
    );
  }

  Future<void> _playPreview() async {
    if (_previewPlaying) {
      _previewRunId++;
      setState(() => _previewPlaying = false);
      return;
    }
    final runId = ++_previewRunId;
    setState(() => _previewPlaying = true);
    for (final token in _tokens) {
      if (!mounted || runId != _previewRunId) return;
      if (token == '|') {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      final durationMs = _durationMsFor(token);
      await _playToken(token, durationMs: durationMs);
      await Future<void>.delayed(Duration(milliseconds: durationMs + 35));
    }
    if (mounted && runId == _previewRunId) {
      setState(() => _previewPlaying = false);
    }
  }

  int _durationMsFor(String raw) {
    final beatMs = _bpm <= 0 ? 1000.0 : 60000 / _bpm;
    final base = raw.contains('=') ? 0.25 : (raw.contains('_') ? 0.5 : 1.0);
    final extended = base + '-'.allMatches(raw).length;
    final beats = raw.contains('.') ? extended * 1.5 : extended;
    return (beats * beatMs).clamp(120, 1600).round();
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: const Text('制作简谱'),
        actions: [
          IconButton(
            tooltip: '保存到本地',
            onPressed: _saveToLocalLibrary,
            icon: const Icon(AppIcons.offlinePinRounded),
          ),
          IconButton(
            tooltip: '导出图片',
            onPressed: _tokens.isEmpty ? null : _exportImage,
            icon: const Icon(AppIcons.imageOutlined),
          ),
          IconButton(
            tooltip: '试听',
            onPressed: _tokens.isEmpty ? null : _playPreview,
            icon: Icon(
              _previewPlaying
                  ? AppIcons.pauseRounded
                  : AppIcons.playArrowRounded,
            ),
          ),
          PopupMenuButton<_MakerMenuAction>(
            tooltip: '更多',
            onSelected: (action) {
              switch (action) {
                case _MakerMenuAction.backspace:
                  _deleteLastToken();
                case _MakerMenuAction.newDraft:
                  _newDraft();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MakerMenuAction.backspace,
                enabled: _tokens.isNotEmpty,
                child: const Text('退格'),
              ),
              const PopupMenuItem(
                value: _MakerMenuAction.newDraft,
                child: Text('新建空谱'),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingDraft
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 820;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 390,
                          child: _EditorScroll(
                            child: _buildEditor(
                              context,
                              compact: false,
                              previewBelow: false,
                            ),
                          ),
                        ),
                        VerticalDivider(width: 1, color: palette.line),
                        Expanded(child: _buildPreview(context, wide: true)),
                      ],
                    );
                  }
                  return _EditorScroll(
                    child: _buildEditor(
                      context,
                      compact: true,
                      previewBelow: true,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPreview(
    BuildContext context, {
    required bool wide,
    bool embedded = false,
  }) {
    final palette = paletteOf(context);
    return Container(
      height: wide ? null : 430,
      margin: embedded
          ? EdgeInsets.zero
          : EdgeInsets.fromLTRB(wide ? 16 : 16, 12, 16, wide ? 16 : 0),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(AppIcons.visibilityOutlined, color: palette.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _draft.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    _saved ? '已保存' : '保存中',
                    key: ValueKey(_saved),
                    style: TextStyle(
                      color: _saved ? palette.success : palette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.line),
          if (_tokens.isEmpty)
            Expanded(
              child: Center(
                child: Icon(
                  AppIcons.musicNoteRounded,
                  size: 42,
                  color: palette.textMuted,
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                child: InteractiveViewer(
                  minScale: 0.75,
                  maxScale: 1.8,
                  boundaryMargin: const EdgeInsets.all(80),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: RepaintBoundary(
                      key: _previewBoundaryKey,
                      child: ColoredBox(
                        color: palette.paperTint,
                        child: JianpuScoreView(
                          document: _draft.toDocument(),
                          detail: _draft.toDetail(),
                          zoom: _previewZoom,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Icon(AppIcons.speedRounded, color: palette.textMuted, size: 18),
                Expanded(
                  child: Slider(
                    value: _previewZoom,
                    min: 0.72,
                    max: 1.18,
                    divisions: 10,
                    onChanged: (value) => setState(() => _previewZoom = value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(
    BuildContext context, {
    required bool compact,
    required bool previewBelow,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionPanel(
          icon: AppIcons.tuneRounded,
          title: '谱面',
          child: _ScoreFields(
            titleController: _titleController,
            singerController: _singerController,
            composerController: _composerController,
            lyricistController: _lyricistController,
            arrangerController: _arrangerController,
            keyName: _keyName,
            timeSignature: _timeSignature,
            bpm: _bpm,
            timeSignatures: _timeSignatures,
            onKeyChanged: (value) {
              setState(() => _keyName = value);
              _refreshDraft();
            },
            onTimeSignatureChanged: (value) {
              setState(() => _timeSignature = value);
              _refreshDraft();
            },
            onBpmChanged: (value) {
              setState(() => _bpm = value);
              _refreshDraft();
            },
          ),
        ),
        const SizedBox(height: 12),
        _SectionPanel(
          icon: AppIcons.touchAppRounded,
          title: '输入',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DegreePad(
                selectedDegree: _selectedDegree,
                onSelected: (degree) => setState(() {
                  _selectedDegree = degree;
                  if (degree == '0') _octave = 0;
                }),
              ),
              const SizedBox(height: 12),
              _OptionChips<int>(
                label: '音区',
                value: _octave,
                values: const [-2, -1, 0, 1, 2],
                labelFor: (value) => switch (value) {
                  -2 => '倍低',
                  -1 => '低',
                  0 => '中',
                  1 => '高',
                  _ => '倍高',
                },
                onChanged: _selectedDegree == '0'
                    ? null
                    : (value) => setState(() => _octave = value),
              ),
              const SizedBox(height: 10),
              _OptionChips<JianpuNoteDuration>(
                label: '时值',
                value: _duration,
                values: JianpuNoteDuration.values,
                labelFor: (value) => value.label,
                onChanged: (value) => setState(() => _duration = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _insertCurrentNote,
                      icon: const Icon(AppIcons.addRounded),
                      label: Text(
                        buildJianpuToken(
                          degree: _selectedDegree,
                          octave: _octave,
                          duration: _duration,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: '小节线',
                    onPressed: () => _insertToken('|'),
                    icon: const Text('|'),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: '退格',
                    onPressed: _tokens.isEmpty ? null : _deleteLastToken,
                    icon: const Icon(AppIcons.backspaceRounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TokenEditor(
                tokens: _tokens,
                onPlay: _playToken,
                onDelete: _removeTokenAt,
                onBackspace: _deleteLastToken,
                onClear: _clearTokens,
              ),
            ],
          ),
        ),
        if (previewBelow) ...[
          const SizedBox(height: 12),
          _buildPreview(context, wide: false, embedded: true),
        ],
        const SizedBox(height: 12),
        _SectionPanel(
          icon: AppIcons.lyricsRounded,
          title: '歌词',
          child: TextField(
            controller: _lyricsController,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(hintText: '每个字或占位用空格分开'),
          ),
        ),
        SizedBox(height: compact ? 20 : 28),
      ],
    );
  }
}

class _EditorScroll extends StatelessWidget {
  const _EditorScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [child],
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
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

class _TokenEditor extends StatelessWidget {
  const _TokenEditor({
    required this.tokens,
    required this.onPlay,
    required this.onDelete,
    required this.onBackspace,
    required this.onClear,
  });

  final List<String> tokens;
  final Future<void> Function(String raw) onPlay;
  final ValueChanged<int> onDelete;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '已输入',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '退格',
                onPressed: tokens.isEmpty ? null : onBackspace,
                icon: const Icon(AppIcons.backspaceRounded, size: 19),
                style: IconButton.styleFrom(
                  fixedSize: const Size(34, 34),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: '清空',
                onPressed: tokens.isEmpty ? null : onClear,
                icon: const Icon(AppIcons.trashRounded, size: 19),
                style: IconButton.styleFrom(
                  fixedSize: const Size(34, 34),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (tokens.isEmpty)
            Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.paperTint,
                borderRadius: BorderRadius.circular(radiusMedium),
                border: Border.all(color: palette.line),
              ),
              child: Text(
                '空',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < tokens.length; index++)
                  InputChip(
                    label: Text(tokens[index]),
                    onPressed: tokens[index] == '|'
                        ? null
                        : () => onPlay(tokens[index]),
                    onDeleted: () => onDelete(index),
                    deleteIcon: const Icon(AppIcons.closeRounded, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ScoreFields extends StatelessWidget {
  const _ScoreFields({
    required this.titleController,
    required this.singerController,
    required this.composerController,
    required this.lyricistController,
    required this.arrangerController,
    required this.keyName,
    required this.timeSignature,
    required this.bpm,
    required this.timeSignatures,
    required this.onKeyChanged,
    required this.onTimeSignatureChanged,
    required this.onBpmChanged,
  });

  final TextEditingController titleController;
  final TextEditingController singerController;
  final TextEditingController composerController;
  final TextEditingController lyricistController;
  final TextEditingController arrangerController;
  final String keyName;
  final String timeSignature;
  final int bpm;
  final List<String> timeSignatures;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<String> onTimeSignatureChanged;
  final ValueChanged<int> onBpmChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: titleController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: '标题'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: singerController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '演唱'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: composerController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '曲作者'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: lyricistController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '词作者'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: arrangerController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '编配'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: keyName,
                decoration: const InputDecoration(labelText: '调号'),
                items: [
                  for (final key in jianpuKeys)
                    DropdownMenuItem(value: key, child: Text('1=$key')),
                ],
                onChanged: (value) {
                  if (value != null) onKeyChanged(value);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: timeSignature,
                decoration: const InputDecoration(labelText: '拍号'),
                items: [
                  for (final item in timeSignatures)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  if (value != null) onTimeSignatureChanged(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _BpmStepper(value: bpm, onChanged: onBpmChanged),
      ],
    );
  }
}

class _BpmStepper extends StatelessWidget {
  const _BpmStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Row(
      children: [
        Icon(AppIcons.speedRounded, color: palette.brand, size: 20),
        const SizedBox(width: 8),
        Text(
          '$value BPM',
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w900),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 40,
            max: 180,
            divisions: 28,
            onChanged: (next) => onChanged(next.round()),
          ),
        ),
      ],
    );
  }
}

class _DegreePad extends StatelessWidget {
  const _DegreePad({required this.selectedDegree, required this.onSelected});

  final String selectedDegree;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    const degrees = ['1', '2', '3', '4', '5', '6', '7', '0'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: degrees.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final degree = degrees[index];
        final selected = degree == selectedDegree;
        return Material(
          color: selected ? palette.brand : palette.surfaceAlt,
          borderRadius: BorderRadius.circular(radiusMedium),
          child: InkWell(
            borderRadius: BorderRadius.circular(radiusMedium),
            onTap: () => onSelected(degree),
            child: Center(
              child: Text(
                degree,
                style: TextStyle(
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : palette.text,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OptionChips<T> extends StatelessWidget {
  const _OptionChips({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Text(
              label,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in values)
                ChoiceChip(
                  label: Text(labelFor(item)),
                  selected: item == value,
                  onSelected: onChanged == null
                      ? null
                      : (_) {
                          onChanged!(item);
                        },
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
