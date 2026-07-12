import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../media/cached_video_controller.dart';
import '../../media/cached_video_controller_result.dart';

/// 统一处理缓存初始化、播放、静音、进度和全屏的视频组件。
final class CachedVideoPlayer extends StatefulWidget {
  const CachedVideoPlayer({super.key, required this.url, this.muted = true});

  final String url;
  final bool muted;

  @override
  State<CachedVideoPlayer> createState() => _CachedVideoPlayerState();
}

final class _CachedVideoPlayerState extends State<CachedVideoPlayer> {
  CachedVideoControllerResult? _result;
  Object? _error;
  var _loading = true;
  var _muted = true;

  VideoPlayerController? get _controller => _result?.controller;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final result = await createCachedVideoController(Uri.parse(widget.url));
      await result.controller.initialize();
      await result.controller.setVolume(_muted ? 0 : 1);
      result.controller.addListener(_onChanged);
      if (!mounted) {
        await result.controller.dispose();
        return;
      }
      setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller
        ..removeListener(_onChanged)
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final controller = _controller;
    if (_error != null || controller == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: Text('视频加载失败')),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: Colors.black,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            _VideoControls(
              controller: controller,
              muted: _muted,
              cacheLabel: _result!.loadedFromCache
                  ? '已缓存'
                  : (_result!.cacheAvailable ? '网络' : 'Web 网络'),
              onMute: () async {
                _muted = !_muted;
                await controller.setVolume(_muted ? 0 : 1);
                if (mounted) setState(() {});
              },
              onFullscreen: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (context) =>
                      _FullscreenVideo(controller: controller, muted: _muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.controller,
    required this.muted,
    required this.cacheLabel,
    required this.onMute,
    required this.onFullscreen,
  });

  final VideoPlayerController controller;
  final bool muted;
  final String cacheLabel;
  final VoidCallback onMute;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final duration = controller.value.duration.inMilliseconds;
    final position = controller.value.position.inMilliseconds.clamp(
      0,
      duration,
    );
    return Row(
      children: [
        IconButton(
          color: Colors.white,
          onPressed: () => controller.value.isPlaying
              ? controller.pause()
              : controller.play(),
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
        ),
        Expanded(
          child: Slider(
            value: duration == 0 ? 0 : position.toDouble(),
            max: duration == 0 ? 1 : duration.toDouble(),
            onChanged: (value) =>
                controller.seekTo(Duration(milliseconds: value.round())),
          ),
        ),
        Text(cacheLabel, style: const TextStyle(color: Colors.white70)),
        IconButton(
          color: Colors.white,
          onPressed: onMute,
          icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
        ),
        IconButton(
          color: Colors.white,
          onPressed: onFullscreen,
          icon: const Icon(Icons.fullscreen),
        ),
      ],
    );
  }
}

final class _FullscreenVideo extends StatelessWidget {
  const _FullscreenVideo({required this.controller, required this.muted});

  final VideoPlayerController controller;
  final bool muted;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black),
    body: Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    ),
  );
}
