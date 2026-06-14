import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';

import '../data/favorites_store.dart';
import '../data/models.dart';
import '../media/cached_video_controller.dart';
import '../media/gallery_image_saver.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

enum _YuepuDetailKind { dynamic, sheet, accompaniment }

class YuepuResourceDetailPage extends StatelessWidget {
  const YuepuResourceDetailPage.dynamic({
    super.key,
    required MusicSummary song,
    required this.favorites,
  }) : _kind = _YuepuDetailKind.dynamic,
       _song = song,
       _sheet = null,
       _accompaniment = null;

  const YuepuResourceDetailPage.sheet({
    super.key,
    required ImageScoreItem sheet,
    required this.favorites,
  }) : _kind = _YuepuDetailKind.sheet,
       _song = null,
       _sheet = sheet,
       _accompaniment = null;

  const YuepuResourceDetailPage.accompaniment({
    super.key,
    required AccompanimentItem accompaniment,
    required this.favorites,
  }) : _kind = _YuepuDetailKind.accompaniment,
       _song = null,
       _sheet = null,
       _accompaniment = accompaniment;

  final _YuepuDetailKind _kind;
  final MusicSummary? _song;
  final ImageScoreItem? _sheet;
  final AccompanimentItem? _accompaniment;
  final FavoritesStore favorites;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: favorites,
      builder: (context, _) {
        final palette = paletteOf(context);
        final title = switch (_kind) {
          _YuepuDetailKind.dynamic => _song!.title,
          _YuepuDetailKind.sheet => _sheet!.title,
          _YuepuDetailKind.accompaniment => _accompaniment!.title,
        };
        final favorite = favorites.contains(_favoriteKind, _favoriteId);
        return Scaffold(
          backgroundColor: palette.paper,
          appBar: AppBar(
            backgroundColor: palette.paper,
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (_kind == _YuepuDetailKind.sheet)
                IconButton(
                  tooltip: '保存图片到相册',
                  onPressed: () => _saveSheetImages(context),
                  icon: const Icon(AppIcons.downloadRounded),
                ),
              IconButton(
                tooltip: favorite ? '取消收藏' : '收藏',
                onPressed: () => favorites.toggle(_favoriteItem),
                icon: Icon(
                  favorite ? AppIcons.bookmarkRounded : AppIcons.bookmarkBorder,
                ),
              ),
            ],
          ),
          body: switch (_kind) {
            _YuepuDetailKind.dynamic => _buildDynamic(context),
            _YuepuDetailKind.sheet => _buildSheet(context),
            _YuepuDetailKind.accompaniment => _buildAccompaniment(context),
          },
        );
      },
    );
  }

  ScoreKind get _favoriteKind {
    return switch (_kind) {
      _YuepuDetailKind.dynamic => ScoreKind.dynamic,
      _YuepuDetailKind.sheet => ScoreKind.image,
      _YuepuDetailKind.accompaniment => ScoreKind.accompaniment,
    };
  }

  String get _favoriteId {
    return switch (_kind) {
      _YuepuDetailKind.dynamic => _song!.favoriteId,
      _YuepuDetailKind.sheet => _sheet!.id,
      _YuepuDetailKind.accompaniment => _accompaniment!.favoriteId,
    };
  }

  FavoriteItem get _favoriteItem {
    return switch (_kind) {
      _YuepuDetailKind.dynamic => _song!.toFavoriteItem(),
      _YuepuDetailKind.sheet => _sheet!.toFavoriteItem(),
      _YuepuDetailKind.accompaniment => _accompaniment!.toFavoriteItem(),
    };
  }

  Widget _buildDynamic(BuildContext context) {
    final song = _song!;
    final palette = paletteOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        _Header(
          title: song.title,
          subtitle: song.subtitle,
          pills: [
            InfoPill(label: '悦谱视频谱', color: palette.brand),
            if (song.previewVideoUrl.isNotEmpty)
              InfoPill(label: '可预览', color: palette.success),
            if (song.encryptedVideoUrl.isNotEmpty)
              InfoPill(label: '正式资源', color: palette.accent),
            if (song.tracks.isNotEmpty)
              InfoPill(
                label: '${song.tracks.length} 轨音频',
                color: palette.amber,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (song.previewVideoUrl.isEmpty)
          const StateView(
            icon: AppIcons.videocamOffOutlined,
            title: '没有预览视频',
            message: '这个资源没有返回可直接播放的 noSpecUrl。',
          )
        else
          _CachedVideoPlayer(url: song.previewVideoUrl),
        if (song.encryptedVideoUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _ProtectedNotice(
            title: '正式版视频',
            message: '正式资源需要原 App 授权播放，当前页面使用可预览视频和多轨音频。',
          ),
        ],
        const SizedBox(height: 16),
        if (song.tracks.isEmpty)
          const StateView(
            icon: AppIcons.playlistPlayRounded,
            title: '没有多轨音频',
            message: '当前动态谱没有返回 trackList。',
          )
        else
          _TrackSelector(tracks: song.tracks),
      ],
    );
  }

  Widget _buildSheet(BuildContext context) {
    final sheet = _sheet!;
    final palette = paletteOf(context);
    final imageUrls = sheet.fileUrls.where(_looksLikeImageUrl).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        _Header(
          title: sheet.title,
          subtitle: sheet.displaySubtitle,
          pills: [
            InfoPill(label: '悦谱曲谱', color: palette.brand),
            if (sheet.fileType.isNotEmpty)
              InfoPill(
                label: sheet.fileType.toUpperCase(),
                color: palette.amber,
              ),
            if (sheet.encryptedUrl.isNotEmpty)
              InfoPill(label: '正式资源', color: palette.accent),
          ],
        ),
        const SizedBox(height: 16),
        if (imageUrls.isNotEmpty)
          for (var i = 0; i < imageUrls.length; i++) ...[
            if (imageUrls.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoPill(label: '第 ${i + 1} 张', color: palette.brand),
              ),
            _ScoreImage(url: imageUrls[i]),
            const SizedBox(height: 14),
          ]
        else
          const StateView(
            icon: AppIcons.imageOutlined,
            title: '暂不支持内嵌预览',
            message: '当前曲谱没有返回可直接预览的图片地址。',
          ),
        if (sheet.encryptedUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _ProtectedNotice(
            title: '正式版曲谱',
            message: '正式资源需要原 App 授权查看，当前页面展示可直接预览版本。',
          ),
        ],
      ],
    );
  }

  Future<void> _saveSheetImages(BuildContext context) async {
    final sheet = _sheet;
    if (sheet == null) return;
    final imageUrls = sheet.fileUrls.where(_looksLikeImageUrl).toList();
    if (imageUrls.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可保存的图片')));
      return;
    }
    try {
      final result = await GalleryImageSaver.saveNetworkImages(
        urls: imageUrls,
        namePrefix: sheet.title,
      );
      if (!context.mounted) return;
      final text = result.failed == 0
          ? '已保存 ${result.saved} 张图片到相册'
          : '已保存 ${result.saved} 张，${result.failed} 张保存失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } on GalException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(GalleryImageSaver.galleryErrorMessage(error.type)),
        ),
      );
    }
  }

  bool _looksLikeImageUrl(String url) {
    return RegExp(
      r'\.(jpg|jpeg|png|gif|webp)(\?|$)',
      caseSensitive: false,
    ).hasMatch(url);
  }

  Widget _buildAccompaniment(BuildContext context) {
    final item = _accompaniment!;
    final palette = paletteOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        _Header(
          title: item.title,
          subtitle: item.subtitle.isEmpty ? item.category : item.subtitle,
          pills: [
            InfoPill(label: '悦谱伴奏', color: palette.brand),
            if (item.category.isNotEmpty)
              InfoPill(label: item.category, color: palette.amber),
            if (item.isEncrypted || item.encryptedUrl.isNotEmpty)
              InfoPill(label: '含正式资源', color: palette.accent),
          ],
        ),
        const SizedBox(height: 16),
        if (item.fileUrl.isEmpty)
          const StateView(
            icon: AppIcons.volumeOffRounded,
            title: '没有可试听音频',
            message: '这个伴奏没有返回可直接播放的 fileUrl。',
          )
        else
          _AudioPlayerCard(
            title: '伴奏试听',
            subtitle: item.category.isEmpty ? 'MP3 音频' : item.category,
            url: item.fileUrl,
          ),
        if (item.encryptedUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _ProtectedNotice(
            title: '正式版伴奏',
            message: '正式资源需要原 App 授权播放，当前页面使用可试听音频。',
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.pills,
  });

  final String title;
  final String subtitle;
  final List<Widget> pills;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.text,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle.isEmpty ? '暂无说明' : subtitle,
          style: TextStyle(color: palette.textMuted, height: 1.35),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: pills),
      ],
    );
  }
}

class _ProtectedNotice extends StatelessWidget {
  const _ProtectedNotice({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(AppIcons.visibilityOutlined, color: palette.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackSelector extends StatefulWidget {
  const _TrackSelector({required this.tracks});

  final List<AudioTrackItem> tracks;

  @override
  State<_TrackSelector> createState() => _TrackSelectorState();
}

class _TrackSelectorState extends State<_TrackSelector> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final track = widget.tracks[_selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '选择音轨',
            prefixIcon: Icon(AppIcons.playlistPlayRounded),
          ),
          items: [
            for (var i = 0; i < widget.tracks.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(_trackName(widget.tracks[i], i)),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _selected = value);
          },
        ),
        const SizedBox(height: 12),
        _AudioPlayerCard(
          key: ValueKey(track.mp3Url),
          title: _trackName(track, _selected),
          subtitle: '多轨音频',
          url: track.mp3Url,
        ),
      ],
    );
  }

  String _trackName(AudioTrackItem track, int index) {
    return track.name.isEmpty ? '音轨 ${index + 1}' : track.name;
  }
}

class _AudioPlayerCard extends StatefulWidget {
  const _AudioPlayerCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final String title;
  final String subtitle;
  final String url;

  @override
  State<_AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<_AudioPlayerCard> {
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  var _playing = false;

  @override
  void initState() {
    super.initState();
    _positionSub = _player.onPositionChanged.listen((value) {
      if (mounted) setState(() => _position = value);
    });
    _durationSub = _player.onDurationChanged.listen((value) {
      if (mounted) setState(() => _duration = value);
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  Future<void> _seek(double value) async {
    if (_duration == Duration.zero) return;
    await _player.seek(
      Duration(milliseconds: (_duration.inMilliseconds * value).round()),
    );
  }

  Future<void> _seekBy(Duration delta) async {
    if (_duration == Duration.zero) return;
    final next = _position + delta;
    final clamped = next.inMilliseconds.clamp(0, _duration.inMilliseconds);
    await _player.seek(Duration(milliseconds: clamped));
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.soft,
                    borderRadius: BorderRadius.circular(radiusMedium),
                  ),
                  child: Icon(AppIcons.musicNoteRounded, color: palette.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Slider(
              value: progress,
              onChanged: _duration == Duration.zero ? null : _seek,
            ),
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _formatDuration(_duration),
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '后退 10 秒',
                  onPressed: () => _seekBy(const Duration(seconds: -10)),
                  icon: const Icon(AppIcons.replay10Rounded),
                ),
                FilledButton.tonalIcon(
                  onPressed: widget.url.isEmpty ? null : _togglePlay,
                  icon: Icon(
                    _playing
                        ? AppIcons.pauseRounded
                        : AppIcons.playArrowRounded,
                  ),
                  label: Text(_playing ? '暂停' : '播放'),
                ),
                IconButton(
                  tooltip: '前进 10 秒',
                  onPressed: () => _seekBy(const Duration(seconds: 10)),
                  icon: const Icon(AppIcons.forward10Rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CachedVideoPlayer extends StatefulWidget {
  const _CachedVideoPlayer({required this.url});

  final String url;

  @override
  State<_CachedVideoPlayer> createState() => _CachedVideoPlayerState();
}

class _CachedVideoPlayerState extends State<_CachedVideoPlayer> {
  VideoPlayerController? _controller;
  late final Future<void> _initialize;
  var _muted = false;
  var _cacheAvailable = false;
  var _loadedFromCache = false;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    _initialize = _initializeController();
  }

  Future<void> _initializeController() async {
    final result = await createCachedVideoController(Uri.parse(widget.url));
    if (_disposed) {
      await result.controller.dispose();
      return;
    }
    _controller = result.controller;
    _cacheAvailable = result.cacheAvailable;
    _loadedFromCache = result.loadedFromCache;
    _controller!.addListener(_onControllerChanged);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _disposed = true;
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    controller.value.isPlaying
        ? await controller.pause()
        : await controller.play();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _muted = !_muted);
    await controller.setVolume(_muted ? 0 : 1);
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    final next = controller.value.position + offset;
    final clamped = next.inMilliseconds.clamp(0, duration.inMilliseconds);
    await controller.seekTo(Duration(milliseconds: clamped));
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final wasPlaying = controller.value.isPlaying;
    final position = controller.value.position;
    await controller.pause();
    if (!mounted) return;
    final resumedPosition = await Navigator.of(context).push<Duration>(
      MaterialPageRoute<Duration>(
        builder: (_) => _FullscreenVideoPage(
          url: widget.url,
          initialPosition: position,
          muted: _muted,
          autoplay: wasPlaying,
        ),
      ),
    );
    if (!mounted) return;
    await controller.seekTo(resumedPosition ?? position);
    if (wasPlaying) await controller.play();
  }

  String get _cacheLabel {
    if (!_cacheAvailable) return '在线播放';
    return _loadedFromCache ? '已缓存' : '已缓存到本地';
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radiusMedium),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: palette.line),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        child: FutureBuilder<void>(
          future: _initialize,
          builder: (context, snapshot) {
            final controller = _controller;
            if (snapshot.hasError) {
              return const SizedBox(
                height: 220,
                child: StateView(
                  icon: AppIcons.videocamOffOutlined,
                  title: '视频加载失败',
                  message: '当前预览 MP4 不可访问。',
                ),
              );
            }
            if (snapshot.connectionState != ConnectionState.done ||
                controller == null ||
                !controller.value.isInitialized) {
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
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _CacheBadge(label: _cacheLabel),
                      ),
                      AnimatedOpacity(
                        opacity: controller.value.isPlaying ? 0 : 1,
                        duration: const Duration(milliseconds: 160),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.54),
                            borderRadius: BorderRadius.circular(radiusMedium),
                          ),
                          child: const Icon(
                            AppIcons.playArrowRounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                  colors: VideoProgressColors(
                    playedColor: palette.accent,
                    bufferedColor: const Color(0x88FFFFFF),
                    backgroundColor: const Color(0x33FFFFFF),
                  ),
                ),
                _VideoControls(
                  playing: controller.value.isPlaying,
                  muted: _muted,
                  position: controller.value.position,
                  duration: controller.value.duration,
                  onPlay: _togglePlay,
                  onMute: _toggleMute,
                  onRewind: () => _seekBy(const Duration(seconds: -10)),
                  onForward: () => _seekBy(const Duration(seconds: 10)),
                  onFullscreen: _openFullscreen,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CacheBadge extends StatelessWidget {
  const _CacheBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AppIcons.offlinePinRounded,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
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
    required this.onFullscreen,
    this.fullscreenExit = false,
  });

  final bool playing;
  final bool muted;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlay;
  final VoidCallback onMute;
  final VoidCallback onRewind;
  final VoidCallback onForward;
  final VoidCallback onFullscreen;
  final bool fullscreenExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: playing ? '暂停' : '播放',
            onPressed: onPlay,
            icon: Icon(
              playing ? AppIcons.pauseRounded : AppIcons.playArrowRounded,
              color: Colors.white,
            ),
          ),
          IconButton(
            tooltip: '后退 10 秒',
            onPressed: onRewind,
            icon: const Icon(AppIcons.replay10Rounded, color: Colors.white70),
          ),
          IconButton(
            tooltip: '前进 10 秒',
            onPressed: onForward,
            icon: const Icon(AppIcons.forward10Rounded, color: Colors.white70),
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
              muted ? AppIcons.volumeOffRounded : AppIcons.volumeUpRounded,
              color: Colors.white,
            ),
          ),
          IconButton(
            tooltip: fullscreenExit ? '退出全屏' : '全屏播放',
            onPressed: onFullscreen,
            icon: Icon(
              fullscreenExit
                  ? AppIcons.fullscreenExitRounded
                  : AppIcons.fullscreenRounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({
    required this.url,
    required this.initialPosition,
    required this.muted,
    required this.autoplay,
  });

  final String url;
  final Duration initialPosition;
  final bool muted;
  final bool autoplay;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  VideoPlayerController? _controller;
  late final Future<void> _initialize;
  late var _muted = widget.muted;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initialize = _initializeController();
  }

  Future<void> _initializeController() async {
    final result = await createCachedVideoController(Uri.parse(widget.url));
    if (_disposed) {
      await result.controller.dispose();
      return;
    }
    _controller = result.controller;
    _controller!.addListener(_onControllerChanged);
    await _controller!.initialize();
    await _controller!.setVolume(_muted ? 0 : 1);
    if (widget.initialPosition > Duration.zero) {
      await _controller!.seekTo(widget.initialPosition);
    }
    if (widget.autoplay) await _controller!.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _disposed = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    controller.value.isPlaying
        ? await controller.pause()
        : await controller.play();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _muted = !_muted);
    await controller.setVolume(_muted ? 0 : 1);
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    final next = controller.value.position + offset;
    final clamped = next.inMilliseconds.clamp(0, duration.inMilliseconds);
    await controller.seekTo(Duration(milliseconds: clamped));
  }

  void _close() {
    Navigator.of(context).pop(_controller?.value.position ?? Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: FutureBuilder<void>(
            future: _initialize,
            builder: (context, snapshot) {
              final controller = _controller;
              if (snapshot.hasError) {
                return const StateView(
                  icon: AppIcons.videocamOffOutlined,
                  title: '视频加载失败',
                  message: '当前预览 MP4 不可访问。',
                );
              }
              if (snapshot.connectionState != ConnectionState.done ||
                  controller == null ||
                  !controller.value.isInitialized) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _togglePlay,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: AspectRatio(
                              aspectRatio: controller.value.aspectRatio,
                              child: VideoPlayer(controller),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: IconButton(
                              tooltip: '退出全屏',
                              onPressed: _close,
                              icon: const Icon(
                                AppIcons.fullscreenExitRounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: controller.value.isPlaying ? 0 : 1,
                            duration: const Duration(milliseconds: 160),
                            child: Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.54),
                                borderRadius: BorderRadius.circular(
                                  radiusMedium,
                                ),
                              ),
                              child: const Icon(
                                AppIcons.playArrowRounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    padding: EdgeInsets.zero,
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Color(0x88FFFFFF),
                      backgroundColor: Color(0x33FFFFFF),
                    ),
                  ),
                  _VideoControls(
                    playing: controller.value.isPlaying,
                    muted: _muted,
                    position: controller.value.position,
                    duration: controller.value.duration,
                    onPlay: _togglePlay,
                    onMute: _toggleMute,
                    onRewind: () => _seekBy(const Duration(seconds: -10)),
                    onForward: () => _seekBy(const Duration(seconds: 10)),
                    onFullscreen: _close,
                    fullscreenExit: true,
                  ),
                ],
              );
            },
          ),
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
    final palette = paletteOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radiusMedium),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.paperTint,
          border: Border.all(color: palette.line),
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
                icon: AppIcons.brokenImageOutlined,
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

String _formatDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (value.inHours > 0) return '${value.inHours}:$minutes:$seconds';
  return '$minutes:$seconds';
}
