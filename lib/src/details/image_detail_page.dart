import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/app_settings.dart';
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
    required this.settings,
  });

  final JianpuApi api;
  final ImageScoreItem item;
  final FavoritesStore favorites;
  final AppSettings settings;

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
      backgroundColor: paperColor,
      appBar: AppBar(
        backgroundColor: paperTintColor,
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Text(
          widget.item.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: inkColor,
            height: 1.08,
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
            _ScoreVideo(
              url: url,
              mutedByDefault: widget.settings.videoMutedByDefault,
            ),
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
  const _ScoreVideo({required this.url, required this.mutedByDefault});

  final String url;
  final bool mutedByDefault;

  @override
  State<_ScoreVideo> createState() => _ScoreVideoState();
}

class _ScoreVideoState extends State<_ScoreVideo> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;
  late var _muted = widget.mutedByDefault;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize = _controller.initialize().then((_) {
      _controller.setVolume(_muted ? 0 : 1);
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

  void _toggleMute() {
    if (!_controller.value.isInitialized) return;
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
  }

  Future<void> _seekBy(Duration offset) async {
    if (!_controller.value.isInitialized) return;
    final duration = _controller.value.duration;
    final next = _controller.value.position + offset;
    final clamped = Duration(
      milliseconds: next.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    await _controller.seekTo(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radiusMedium),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: lineColor),
          borderRadius: BorderRadius.circular(radiusMedium),
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
                      AnimatedOpacity(
                        opacity: _controller.value.isPlaying ? 0 : 1,
                        duration: const Duration(milliseconds: 160),
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(radiusMedium),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
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
                _VideoControls(
                  playing: _controller.value.isPlaying,
                  muted: _muted,
                  position: _controller.value.position,
                  duration: _controller.value.duration,
                  onPlay: _togglePlay,
                  onMute: _toggleMute,
                  onRewind: () => _seekBy(const Duration(seconds: -10)),
                  onForward: () => _seekBy(const Duration(seconds: 10)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.playing,
    required this.muted,
    required this.position,
    required this.duration,
    required this.onPlay,
    required this.onMute,
    required this.onRewind,
    required this.onForward,
  });

  final bool playing;
  final bool muted;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlay;
  final VoidCallback onMute;
  final VoidCallback onRewind;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: playing ? '暂停' : '播放',
            onPressed: onPlay,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
          ),
          IconButton(
            tooltip: '后退 10 秒',
            onPressed: onRewind,
            icon: const Icon(Icons.replay_10_rounded, color: Colors.white70),
          ),
          IconButton(
            tooltip: '前进 10 秒',
            onPressed: onForward,
            icon: const Icon(Icons.forward_10_rounded, color: Colors.white70),
          ),
          Expanded(
            child: Text(
              '${_formatDuration(position)} / ${_formatDuration(duration)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: muted ? '打开声音' : '静音',
            onPressed: onMute,
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (value.inHours > 0) {
    return '${value.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

class _ScoreImage extends StatelessWidget {
  const _ScoreImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radiusMedium),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: paperTintColor,
          border: Border.all(color: lineColor),
          borderRadius: BorderRadius.circular(radiusMedium),
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
