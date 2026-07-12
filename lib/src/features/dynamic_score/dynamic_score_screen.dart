import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/music/key_transpose.dart';
import '../../widgets/jianpu_score_view.dart';
import 'dynamic_score_state.dart';
import 'dynamic_score_view_model.dart';

/// V2 动态简谱阅读页面。
final class DynamicScoreScreen extends ConsumerStatefulWidget {
  const DynamicScoreScreen({super.key});

  @override
  ConsumerState<DynamicScoreScreen> createState() => _DynamicScoreScreenState();
}

final class _DynamicScoreScreenState extends ConsumerState<DynamicScoreScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(dynamicScoreViewModelProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dynamicScoreViewModelProvider);
    final viewModel = ref.read(dynamicScoreViewModelProvider.notifier);
    ref.listen<DynamicScoreState>(dynamicScoreViewModelProvider, (
      previous,
      next,
    ) {
      if (!next.isPlaying ||
          next.scrollSpeed <= 0 ||
          previous?.activeNoteIndex == next.activeNoteIndex ||
          !_scrollController.hasClients ||
          next.timeline.durationMs <= 0) {
        return;
      }
      final progress = next.elapsedMs / next.timeline.durationMs;
      final target = (_scrollController.position.maxScrollExtent * progress)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        target,
        duration: Duration(
          milliseconds: (220 / next.scrollSpeed.clamp(0.2, 1.5)).round(),
        ),
        curve: Curves.easeOut,
      );
    });

    final detail = state.content?.detail;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail?.title.isNotEmpty == true
                  ? detail!.title
                  : state.summary.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (detail?.singer.isNotEmpty == true)
              Text(
                detail!.singer,
                style: Theme.of(context).textTheme.labelMedium,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: state.isFavorite ? '取消收藏' : '收藏',
            onPressed: detail == null ? null : viewModel.toggleFavorite,
            icon: Icon(
              state.isFavorite ? Icons.bookmark : Icons.bookmark_outline,
            ),
          ),
          IconButton(
            tooltip: '谱面设置',
            onPressed: detail == null ? null : () => _showSettings(context),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: _DynamicScoreBody(
        state: state,
        scrollController: _scrollController,
        onRetry: viewModel.load,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton.filled(
                  tooltip: state.isPlaying ? '暂停' : '播放',
                  onPressed: state.timeline.notes.isEmpty
                      ? null
                      : viewModel.togglePlayback,
                  icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  tooltip: '停止',
                  onPressed: state.elapsedMs == 0 ? null : viewModel.stop,
                  icon: const Icon(Icons.stop),
                ),
                IconButton(
                  tooltip: state.soundEnabled ? '关闭声音' : '打开声音',
                  onPressed: () =>
                      viewModel.setSoundEnabled(!state.soundEnabled),
                  icon: Icon(
                    state.soundEnabled ? Icons.volume_up : Icons.volume_off,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: state.timeline.durationMs == 0
                        ? 0
                        : state.elapsedMs / state.timeline.durationMs,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  state.selectedKey.isEmpty ? '--' : '1=${state.selectedKey}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSettings(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(dynamicScoreViewModelProvider);
            final viewModel = ref.read(dynamicScoreViewModelProvider.notifier);
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text('谱面设置', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _SettingSlider(
                    label: '谱面大小',
                    value: state.zoom,
                    min: 0.72,
                    max: 1.28,
                    onChanged: viewModel.setZoom,
                  ),
                  _SettingSlider(
                    label: '自动滚动速度',
                    value: state.scrollSpeed,
                    min: 0,
                    max: 1.5,
                    onChanged: viewModel.setScrollSpeed,
                  ),
                  _SettingSlider(
                    label: '播放音量',
                    value: state.volume,
                    min: 0,
                    max: 1,
                    onChanged: viewModel.setVolume,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.soundEnabled,
                    title: const Text('按节拍发声'),
                    onChanged: viewModel.setSoundEnabled,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.rewriteNotation,
                    title: const Text('固定调显示'),
                    subtitle: const Text('数字随所选调门重新换算'),
                    onChanged: viewModel.setRewriteNotation,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: state.selectedKey.isEmpty
                        ? null
                        : state.selectedKey,
                    decoration: const InputDecoration(labelText: '显示调'),
                    items: [
                      for (final key in jianpuKeys)
                        DropdownMenuItem(value: key, child: Text('1=$key')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        viewModel.setSelectedKey(value);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
}

final class _DynamicScoreBody extends StatelessWidget {
  const _DynamicScoreBody({
    required this.state,
    required this.scrollController,
    required this.onRetry,
  });

  final DynamicScoreState state;
  final ScrollController scrollController;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.content == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 52),
              const SizedBox(height: 12),
              Text(state.errorMessage ?? '谱面加载失败'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }
    return Scrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 28),
        child: InteractiveViewer(
          minScale: 0.78,
          maxScale: 2,
          boundaryMargin: const EdgeInsets.all(80),
          child: JianpuScoreView(
            document: state.content!.document,
            detail: state.content!.detail,
            zoom: state.zoom,
            activeNoteIndex: state.activeNoteIndex,
            activePulse: 1,
            selectedKey: state.selectedKey,
            rewriteNotation: state.rewriteNotation,
          ),
        ),
      ),
    );
  }
}

final class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label  ${value.toStringAsFixed(2)}'),
      Slider(value: value, min: min, max: max, onChanged: onChanged),
    ],
  );
}
