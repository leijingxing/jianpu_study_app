import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/favorites_store.dart';
import '../data/jianpu_api.dart';
import '../data/models.dart';
import '../details/dynamic_detail_page.dart';
import '../details/image_detail_page.dart';
import '../settings/settings_page.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = JianpuApi();
  final _favorites = FavoritesStore();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  var _tab = 0;
  var _query = '';
  var _dynamicPage = 1;
  var _imagePage = 1;
  var _dynamicSongs = <MusicSummary>[];
  var _imageScores = <ImageScoreItem>[];
  var _loading = true;
  var _loadingMore = false;
  var _dynamicHasMore = true;
  var _imageHasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _favorites.load();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _favorites.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 320) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = true}) async {
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      if (reset) {
        _dynamicPage = 1;
        _imagePage = 1;
        _dynamicHasMore = true;
        _imageHasMore = true;
      }
    });

    try {
      if (_tab == 0) {
        final songs = _query.trim().isEmpty
            ? await _api.fetchDynamicList(page: _dynamicPage)
            : await _api.searchDynamic(_query);
        _dynamicSongs = songs;
        _dynamicHasMore = _query.trim().isEmpty && songs.isNotEmpty;
      } else if (_tab == 1) {
        final scores = _query.trim().isEmpty
            ? await _api.fetchImageList(page: _imagePage)
            : await _api.searchImages(_query);
        _imageScores = scores;
        _imageHasMore = _query.trim().isEmpty && scores.isNotEmpty;
      }
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final hasMore = _tab == 0 ? _dynamicHasMore : _imageHasMore;
    if (_tab == 2 || _query.trim().isNotEmpty || _loading || _loadingMore) {
      return;
    }
    if (!hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      if (_tab == 0) {
        final nextPage = _dynamicPage + 1;
        final songs = await _api.fetchDynamicList(page: nextPage);
        _dynamicPage = nextPage;
        _dynamicHasMore = songs.isNotEmpty;
        _dynamicSongs.addAll(songs);
      } else if (_tab == 1) {
        final nextPage = _imagePage + 1;
        final scores = await _api.fetchImageList(page: nextPage);
        _imagePage = nextPage;
        _imageHasMore = scores.isNotEmpty;
        _imageScores.addAll(scores);
      }
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_favorites, widget.settings]),
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _HomeHeader(
                  controller: _searchController,
                  tab: _tab,
                  onTabChanged: (index) {
                    setState(() {
                      _tab = index;
                      _query = '';
                      _searchController.clear();
                    });
                    _load();
                  },
                  onSearch: (value) {
                    _query = value;
                    _load();
                  },
                  onSettings: _openSettings,
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_tab == 2) return _buildFavorites();
    if (_error != null && (_dynamicSongs.isEmpty && _imageScores.isEmpty)) {
      return StateView(
        icon: Icons.wifi_off_rounded,
        title: '接口暂时不可用',
        message: '$_error',
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      );
    }

    if (_loading && (_dynamicSongs.isEmpty && _imageScores.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tab == 0) return _buildDynamicList();
    return _buildImageList();
  }

  Widget _buildDynamicList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          16,
          widget.settings.compactList ? 6 : 10,
          16,
          24,
        ),
        itemCount: _dynamicSongs.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _dynamicSongs.length) {
            return LoadMoreIndicator(
              loading: _loadingMore,
              hasMore: _dynamicHasMore && _query.trim().isEmpty,
            );
          }
          final song = _dynamicSongs[index];
          final favorite = _favorites.contains(ScoreKind.dynamic, '${song.id}');
          return ScoreCard(
            title: song.title,
            subtitle: song.subtitle,
            metric: '练习 ${song.times}',
            badge: song.level > 0 ? '难度 ${song.level}' : '动态谱',
            favorite: favorite,
            leadingIcon: Icons.graphic_eq_rounded,
            compact: widget.settings.compactList,
            reduceMotion: widget.settings.reduceMotion,
            onFavorite: () => _favorites.toggle(
              FavoriteItem(
                kind: ScoreKind.dynamic,
                id: '${song.id}',
                title: song.title,
                subtitle: song.subtitle,
              ),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DynamicDetailPage(
                  api: _api,
                  song: song,
                  favorites: _favorites,
                  settings: widget.settings,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          16,
          widget.settings.compactList ? 6 : 10,
          16,
          24,
        ),
        itemCount: _imageScores.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _imageScores.length) {
            return LoadMoreIndicator(
              loading: _loadingMore,
              hasMore: _imageHasMore && _query.trim().isEmpty,
            );
          }
          final item = _imageScores[index];
          final favorite = _favorites.contains(ScoreKind.image, item.id);
          return ScoreCard(
            title: item.title,
            subtitle: item.displaySubtitle,
            metric: '${item.views} 浏览',
            badge: item.hasVideo ? '视频' : '图片',
            favorite: favorite,
            imageUrl: item.imageUrl,
            leadingIcon: item.hasVideo
                ? Icons.play_circle_outline
                : Icons.image_outlined,
            compact: widget.settings.compactList,
            reduceMotion: widget.settings.reduceMotion,
            onFavorite: () => _favorites.toggle(
              FavoriteItem(
                kind: ScoreKind.image,
                id: item.id,
                title: item.title,
                subtitle: item.summary,
                imageUrl: item.imageUrl,
              ),
            ),
            onTap: () => _openImageDetail(item),
          );
        },
      ),
    );
  }

  Widget _buildFavorites() {
    final items = _favorites.items;
    if (items.isEmpty) {
      return const StateView(
        icon: Icons.bookmark_add_outlined,
        title: '还没有收藏',
        message: '收藏的谱子会放在这里',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        widget.settings.compactList ? 6 : 10,
        16,
        24,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return ScoreCard(
          title: item.title,
          subtitle: item.subtitle.isEmpty
              ? (item.kind == ScoreKind.dynamic ? '动态谱' : '图片谱')
              : item.subtitle,
          metric: item.kind == ScoreKind.dynamic ? '动态谱' : '图片谱',
          badge: '收藏',
          favorite: true,
          imageUrl: item.imageUrl,
          leadingIcon: item.kind == ScoreKind.dynamic
              ? Icons.graphic_eq_rounded
              : Icons.image_outlined,
          compact: widget.settings.compactList,
          reduceMotion: widget.settings.reduceMotion,
          onFavorite: () => _favorites.toggle(item),
          onTap: () {
            if (item.kind == ScoreKind.dynamic) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DynamicDetailPage(
                    api: _api,
                    song: MusicSummary(
                      id: int.tryParse(item.id) ?? 0,
                      title: item.title,
                      singer: '',
                      arranger: '',
                      times: 0,
                      level: 0,
                    ),
                    favorites: _favorites,
                    settings: widget.settings,
                  ),
                ),
              );
            } else {
              _openImageDetail(ImageScoreItem.favorite(item));
            }
          },
        );
      },
    );
  }

  void _openImageDetail(ImageScoreItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageDetailPage(
          api: _api,
          item: item,
          favorites: _favorites,
          settings: widget.settings,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(settings: widget.settings),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.controller,
    required this.tab,
    required this.onTabChanged,
    required this.onSearch,
    required this.onSettings,
  });

  final TextEditingController controller;
  final int tab;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String> onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: const Border(bottom: BorderSide(color: lineColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.soft,
                    border: Border.all(color: lineColor),
                    borderRadius: BorderRadius.circular(radiusMedium),
                  ),
                  child: Icon(Icons.music_note_rounded, color: palette.brand),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '轻谱',
                        style: TextStyle(
                          color: inkColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '听着节拍，读懂简谱',
                        style: TextStyle(
                          color: mutedTextColor,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '设置',
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(42, 42),
                    foregroundColor: palette.brandDark,
                    backgroundColor: palette.soft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radiusMedium),
                      side: const BorderSide(color: lineColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.graphic_eq_rounded),
                    label: Text('动态谱'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.image_outlined),
                    label: Text('图片谱'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.bookmark_border_rounded),
                    label: Text('收藏'),
                  ),
                ],
                selected: {tab},
                onSelectionChanged: (value) => onTabChanged(value.first),
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSearch,
                  decoration: InputDecoration(
                    hintText: tab == 1 ? '搜索图片谱标题' : '搜索歌名、歌手、编配',
                    prefixIcon: const Icon(Icons.search_rounded),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radiusMedium),
                      borderSide: const BorderSide(
                        color: lineColor,
                        width: 1.4,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radiusMedium),
                      borderSide: BorderSide(color: palette.brand, width: 1.6),
                    ),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              controller.clear();
                              onSearch('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreCard extends StatelessWidget {
  const ScoreCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.badge,
    required this.favorite,
    required this.leadingIcon,
    required this.onTap,
    required this.onFavorite,
    this.compact = false,
    this.reduceMotion = false,
    this.imageUrl = '',
  });

  final String title;
  final String subtitle;
  final String metric;
  final String badge;
  final bool favorite;
  final IconData leadingIcon;
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final bool compact;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusMedium),
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 12),
            child: Row(
              children: [
                _CoverThumb(
                  title: title,
                  imageUrl: imageUrl,
                  icon: leadingIcon,
                  compact: compact,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: inkColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: mutedTextColor,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          InfoPill(label: badge, color: palette.brand),
                          InfoPill(
                            label: metric,
                            color: const Color(0xFF7C6C58),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: favorite ? '取消收藏' : '收藏',
                  onPressed: onFavorite,
                  icon: AnimatedSwitcher(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      favorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      key: ValueKey(favorite),
                      color: favorite ? accentColor : const Color(0xFF8B969C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({
    required this.title,
    required this.icon,
    required this.compact,
    this.imageUrl = '',
  });

  final String title;
  final IconData icon;
  final bool compact;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radiusMedium),
      child: Container(
        width: compact ? 54 : 62,
        height: compact ? 62 : 72,
        color: paletteOf(context).soft,
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(context),
              )
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final letter = title.characters.isEmpty ? '谱' : title.characters.first;
    final palette = paletteOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: palette.soft),
        Positioned(
          right: -8,
          bottom: -10,
          child: Icon(
            Icons.graphic_eq_rounded,
            size: 42,
            color: palette.brand.withValues(alpha: 0.12),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: palette.brand),
              const SizedBox(height: 4),
              Text(
                letter,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: palette.brand,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
