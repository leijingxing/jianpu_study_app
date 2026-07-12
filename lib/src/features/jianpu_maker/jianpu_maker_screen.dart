import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/local_score.dart';
import '../../domain/music/key_transpose.dart';
import '../../widgets/jianpu_score_view.dart';
import 'jianpu_maker_view_model.dart';

final class JianpuMakerScreen extends ConsumerStatefulWidget {
  const JianpuMakerScreen({super.key});

  @override
  ConsumerState<JianpuMakerScreen> createState() => _JianpuMakerScreenState();
}

final class _JianpuMakerScreenState extends ConsumerState<JianpuMakerScreen> {
  JianpuNoteDuration _duration = JianpuNoteDuration.quarter;
  var _octave = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(jianpuMakerViewModelProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jianpuMakerViewModelProvider);
    final viewModel = ref.read(jianpuMakerViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('简谱制作器'),
        actions: [
          IconButton(
            tooltip: '新建',
            onPressed: viewModel.newDraft,
            icon: const Icon(Icons.note_add_outlined),
          ),
          IconButton(
            tooltip: '本地乐谱',
            onPressed: () => _showSavedScores(context),
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: '保存',
            onPressed: state.isSaving ? null : viewModel.save,
            icon: state.isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.message != null)
            Card(child: ListTile(title: Text(state.message!))),
          TextFormField(
            key: ValueKey('title-${state.currentId}-${state.draft.title}'),
            initialValue: state.draft.title,
            decoration: const InputDecoration(labelText: '曲名'),
            onChanged: (value) =>
                viewModel.updateDraft(state.draft.copyWith(title: value)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: state.draft.keyName,
                  decoration: const InputDecoration(labelText: '调号'),
                  items: [
                    for (final key in jianpuKeys)
                      DropdownMenuItem(value: key, child: Text('1=$key')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      viewModel.updateDraft(
                        state.draft.copyWith(keyName: value),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: '${state.draft.bpm}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'BPM'),
                  onChanged: (value) {
                    final bpm = int.tryParse(value);
                    if (bpm != null) {
                      viewModel.updateDraft(
                        state.draft.copyWith(bpm: bpm.clamp(40, 220)),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: [
              DropdownButton<JianpuNoteDuration>(
                value: _duration,
                items: [
                  for (final value in JianpuNoteDuration.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) => setState(() => _duration = value!),
              ),
              ChoiceChip(
                label: const Text('低八度'),
                selected: _octave == -1,
                onSelected: (_) => setState(() => _octave = -1),
              ),
              ChoiceChip(
                label: const Text('标准'),
                selected: _octave == 0,
                onSelected: (_) => setState(() => _octave = 0),
              ),
              ChoiceChip(
                label: const Text('高八度'),
                selected: _octave == 1,
                onSelected: (_) => setState(() => _octave = 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final degree in ['0', '1', '2', '3', '4', '5', '6', '7'])
                FilledButton.tonal(
                  onPressed: () {
                    final token = buildJianpuToken(
                      degree: degree,
                      octave: _octave,
                      duration: _duration,
                    );
                    viewModel.addToken(token);
                    viewModel.preview(token);
                  },
                  child: Text(degree),
                ),
              OutlinedButton(
                onPressed: () => viewModel.addToken('|'),
                child: const Text('小节线'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: '撤销',
                onPressed: state.canUndo ? viewModel.undo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: '重做',
                onPressed: state.canRedo ? viewModel.redo : null,
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                tooltip: '删除最后音符',
                onPressed: state.draft.tokens.isEmpty
                    ? null
                    : viewModel.removeLastToken,
                icon: const Icon(Icons.backspace_outlined),
              ),
              Expanded(
                child: Text(
                  state.draft.tokens.join(' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          if (state.draft.tokens.isNotEmpty)
            JianpuScoreView(
              document: state.draft.toDocument(),
              detail: state.draft.toDetail(),
              zoom: 0.82,
              activeNoteIndex: -1,
              activePulse: 1,
              selectedKey: state.draft.keyName,
              rewriteNotation: false,
            )
          else
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('点击数字开始编写简谱')),
            ),
        ],
      ),
    );
  }

  Future<void> _showSavedScores(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(jianpuMakerViewModelProvider);
            final viewModel = ref.read(jianpuMakerViewModelProvider.notifier);
            return ListView(
              children: [
                const ListTile(title: Text('本地乐谱')),
                if (state.savedScores.isEmpty)
                  const ListTile(title: Text('暂无本地乐谱')),
                for (final score in state.savedScores)
                  ListTile(
                    title: Text(score.draft.title),
                    subtitle: Text(
                      '1=${score.draft.keyName} · ${score.draft.bpm} BPM',
                    ),
                    onTap: () {
                      viewModel.open(score);
                      Navigator.of(context).pop();
                    },
                    trailing: IconButton(
                      tooltip: '删除',
                      onPressed: () => viewModel.delete(score.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
              ],
            );
          },
        ),
      );
}
