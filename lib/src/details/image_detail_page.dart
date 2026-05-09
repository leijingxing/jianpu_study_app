import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/favorites_store.dart';
import '../data/jianpu_api.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ImageDetailPage extends StatefulWidget {
  const ImageDetailPage({
    super.key,
    required this.api,
    required this.item,
    required this.favorites,
  });

  final JianpuApi api;
  final ImageScoreItem item;
  final FavoritesStore favorites;

  @override
  State<ImageDetailPage> createState() => _ImageDetailPageState();
}

class _ImageDetailPageState extends State<ImageDetailPage> {
  ImageScoreDetail? _detail;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    widget.favorites.addListener(_onFavoriteChanged);
    _load();
  }

  @override
  void dispose() {
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
      _detail = await widget.api.fetchImageDetail(widget.item);
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorite = widget.favorites.contains(ScoreKind.image, widget.item.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: favorite ? '取消收藏' : '收藏',
            onPressed: () => widget.favorites.toggle(
              FavoriteItem(
                kind: ScoreKind.image,
                id: widget.item.id,
                title: widget.item.title,
                subtitle: widget.item.summary,
                imageUrl: widget.item.imageUrl,
              ),
            ),
            icon: Icon(
              favorite ? Icons.bookmark_rounded : Icons.bookmark_border,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return StateView(
        icon: Icons.error_outline_rounded,
        title: '图片谱加载失败',
        message: '$_error',
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      );
    }

    final detail = _detail!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          widget.item.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: inkColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.item.summary.isEmpty ? '图片谱' : widget.item.summary,
          style: const TextStyle(color: mutedTextColor, height: 1.35),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.item.views > 0)
              InfoPill(label: '${widget.item.views} 浏览', color: brandColor),
            InfoPill(label: widget.item.date, color: const Color(0xFF7C6E5E)),
            if (detail.videoUrls.isNotEmpty)
              InfoPill(
                label: '${detail.videoUrls.length} 个视频',
                color: accentColor,
              ),
            if (detail.imageUrls.isNotEmpty)
              InfoPill(
                label: '${detail.imageUrls.length} 张图片',
                color: inkColor,
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (detail.imageUrls.isEmpty && detail.videoUrls.isEmpty)
          const StateView(
            icon: Icons.image_not_supported_outlined,
            title: '没有找到媒体',
            message: '文章里没有可识别的图片或视频。',
          )
        else ...[
          for (final url in detail.videoUrls) ...[
            _ScoreVideo(url: url),
            const SizedBox(height: 14),
          ],
          for (final url in detail.imageUrls) ...[
            _ScoreImage(url: url),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}

class _ScoreVideo extends StatefulWidget {
  const _ScoreVideo({required this.url});

  final String url;

  @override
  State<_ScoreVideo> createState() => _ScoreVideoState();
}

class _ScoreVideoState extends State<_ScoreVideo> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize = _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: lineColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FutureBuilder<void>(
          future: _initialize,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const SizedBox(
                height: 220,
                child: StateView(
                  icon: Icons.videocam_off_outlined,
                  title: '视频加载失败',
                  message: '当前视频地址不可访问。',
                ),
              );
            }
            if (snapshot.connectionState != ConnectionState.done ||
                !_controller.value.isInitialized) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _togglePlay,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                      if (!_controller.value.isPlaying)
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                    ],
                  ),
                ),
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(
                    playedColor: accentColor,
                    bufferedColor: Color(0x88FFFFFF),
                    backgroundColor: Color(0x33FFFFFF),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreImage extends StatelessWidget {
  const _ScoreImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: lineColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (_, _, _) => const SizedBox(
              height: 220,
              child: StateView(
                icon: Icons.broken_image_outlined,
                title: '图片加载失败',
                message: '当前图片地址不可访问。',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
