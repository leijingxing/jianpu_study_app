import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/cached_video_player.dart';
import '../../core/media/network_audio_player.dart';
import 'yuepu_resource_view_model.dart';

/// 使用统一音视频组件展示悦谱动态资源。
final class YuepuResourceScreen extends ConsumerWidget {
  const YuepuResourceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(currentYuepuScoreProvider);
    final favorite = ref.watch(yuepuResourceViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(score.title),
        actions: [
          IconButton(
            tooltip: favorite ? '取消收藏' : '收藏',
            onPressed: ref
                .read(yuepuResourceViewModelProvider.notifier)
                .toggleFavorite,
            icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(score.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(score.subtitle),
          const SizedBox(height: 18),
          if (score.previewVideoUrl.isNotEmpty) ...[
            CachedVideoPlayer(url: score.previewVideoUrl),
            const SizedBox(height: 16),
          ],
          if (score.encryptedVideoUrl.isNotEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('包含受保护视频'),
                subtitle: Text('加密资源不在客户端直接解密。'),
              ),
            ),
          if (score.tracks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('音轨', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var index = 0; index < score.tracks.length; index++)
              NetworkAudioPlayer(
                url: score.tracks[index].mp3Url,
                title: score.tracks[index].name.isEmpty
                    ? '音轨 ${index + 1}'
                    : score.tracks[index].name,
              ),
          ],
          if (score.previewVideoUrl.isEmpty && score.tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('没有可直接播放的资源')),
            ),
        ],
      ),
    );
  }
}
