import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/cached_video_player.dart';
import 'image_score_state.dart';
import 'image_score_view_model.dart';

/// V2 图片谱详情页面。
final class ImageScoreScreen extends ConsumerStatefulWidget {
  const ImageScoreScreen({super.key});

  @override
  ConsumerState<ImageScoreScreen> createState() => _ImageScoreScreenState();
}

final class _ImageScoreScreenState extends ConsumerState<ImageScoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(imageScoreViewModelProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageScoreViewModelProvider);
    final viewModel = ref.read(imageScoreViewModelProvider.notifier);
    ref.listen<ImageScoreState>(imageScoreViewModelProvider, (previous, next) {
      if (next.statusMessage != null &&
          previous?.statusMessage != next.statusMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.statusMessage!)));
        viewModel.clearStatus();
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(state.item.title),
        actions: [
          IconButton(
            tooltip: '保存图片',
            onPressed:
                state.isSaving || state.detail?.imageUrls.isEmpty != false
                ? null
                : viewModel.saveImages,
            icon: state.isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
          ),
          IconButton(
            tooltip: state.isFavorite ? '取消收藏' : '收藏',
            onPressed: viewModel.toggleFavorite,
            icon: Icon(
              state.isFavorite ? Icons.bookmark : Icons.bookmark_outline,
            ),
          ),
        ],
      ),
      body: _ImageScoreBody(state: state, onRetry: viewModel.load),
    );
  }
}

final class _ImageScoreBody extends StatelessWidget {
  const _ImageScoreBody({required this.state, required this.onRetry});

  final ImageScoreState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final detail = state.detail;
    if (detail == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 52),
            const SizedBox(height: 12),
            Text(state.errorMessage ?? '图片谱加载失败'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重新加载'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(
          state.item.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(state.item.displaySubtitle),
        const SizedBox(height: 18),
        for (final url in detail.videoUrls) ...[
          CachedVideoPlayer(url: url),
          const SizedBox(height: 14),
        ],
        for (final url in detail.imageUrls) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.network(
                url,
                fit: BoxFit.fitWidth,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 180,
                  child: Center(child: Text('图片加载失败')),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (detail.videoUrls.isEmpty && detail.imageUrls.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('没有可显示的媒体资源')),
          ),
      ],
    );
  }
}
