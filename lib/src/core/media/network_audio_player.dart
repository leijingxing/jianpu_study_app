import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// 统一管理网络音频初始化、播放状态、进度和释放。
final class NetworkAudioPlayer extends StatefulWidget {
  const NetworkAudioPlayer({super.key, required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<NetworkAudioPlayer> createState() => _NetworkAudioPlayerState();
}

final class _NetworkAudioPlayerState extends State<NetworkAudioPlayer> {
  final _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _state = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((value) {
      if (mounted) setState(() => _position = value);
    });
    _player.onDurationChanged.listen((value) {
      if (mounted) setState(() => _duration = value);
    });
    _player.onPlayerStateChanged.listen((value) {
      if (mounted) setState(() => _state = value);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = _duration.inMilliseconds.toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: () async {
                if (_state == PlayerState.playing) {
                  await _player.pause();
                } else {
                  await _player.play(UrlSource(widget.url));
                }
              },
              icon: Icon(
                _state == PlayerState.playing ? Icons.pause : Icons.play_arrow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Slider(
                    value: max == 0
                        ? 0
                        : _position.inMilliseconds.clamp(0, max).toDouble(),
                    max: max == 0 ? 1 : max,
                    onChanged: max == 0
                        ? null
                        : (value) => _player.seek(
                            Duration(milliseconds: value.round()),
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
