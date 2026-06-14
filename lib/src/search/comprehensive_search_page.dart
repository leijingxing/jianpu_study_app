import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/favorites_store.dart';
import '../data/jianpu_api.dart';
import '../data/models.dart';
import '../details/dynamic_detail_page.dart';
import '../details/image_detail_page.dart';
import '../details/yuepu_resource_detail_page.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

enum _SearchFilter { all, dynamic, yuepuVideo, sheet, accompaniment }

class ComprehensiveSearchPage extends StatefulWidget {
  const ComprehensiveSearchPage({
    super.key,
    required this.api,
    required this.favorites,
    required this.settings,
    this.initialQuery = '',
  });

  final JianpuApi api;
  final FavoritesStore favorites;
  final AppSettings settings;
  final String initialQuery;

  @override
  State<ComprehensiveSearchPage> createState() =>
      _ComprehensiveSearchPageState();
}

class _ComprehensiveSearchPageState extends State<ComprehensiveSearchPage> {
  late final TextEditingController _controller;
  var _filter = _SearchFilter.all;
  var _loading = false;
  var _searched = false;
  Object? _error;
  _SearchBundle _bundle = const _SearchBundle();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    final initial = widget.initialQuery.trim();
    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(initial));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search([String? value]) async {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) {
      setState(() {
        _searched = false;
        _bundle = const _SearchBundle();
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
    });

    final dynamicFuture = _loadGroup(() => widget.api.searchDynamic(query));
    final forumSheetFuture = _loadGroup(() => widget.api.searchImages(query));
    final yuepuVideoFuture = _loadGroup(
      () => widget.api.fetchYuepuDynamicList(query: query, limit: 50),
    );
    final yuepuSheetFuture = _loadGroup(
      () => widget.api.fetchYuepuSheetList(query: query, limit: 50),
    );
    final accompanimentFuture = _loadGroup(
      () => widget.api.fetchYuepuAccompanimentList(query: query, limit: 50),
    );

    final results = await Future.wait([
      dynamicFuture,
      forumSheetFuture,
      yuepuVideoFuture,
      yuepuSheetFuture,
      accompanimentFuture,
    ]);
    final bundle = _SearchBundle(
      dynamicSongs: results[0].items.cast<MusicSummary>(),
      forumSheets: results[1].items.cast<ImageScoreItem>(),
      yuepuVideos: results[2].items.cast<MusicSummary>(),
      yuepuSheets: results[3].items.cast<ImageScoreItem>(),
      accompaniments: results[4].items.cast<AccompanimentItem>(),
      errors: [
        for (final result in results)
          if (result.error != null) result.error!,
      ],
    );

    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _loading = false;
      _error = bundle.isEmpty && bundle.errors.isNotEmpty
          ? bundle.errors.first
          : null;
    });
  }

  Future<_GroupResult<T>> _loadGroup<T>(
    Future<List<T>> Function() loader,
  ) async {
    try {
      return _GroupResult(items: await loader());
    } catch (error) {
      return _GroupResult(items: const [], error: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(backgroundColor: palette.paper, title: const Text('综合搜索')),
      body: AnimatedBuilder(
        animation: widget.favorites,
        builder: (context, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: widget.initialQuery.isEmpty,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search,
                        decoration: const InputDecoration(
                          hintText: '搜索歌名、视频谱、曲谱、伴奏',
                          prefixIcon: Icon(AppIcons.searchRounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _loading ? null : _search,
                      icon: const Icon(AppIcons.searchRounded),
                      label: const Text('搜索'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterChip(
                      label: '全部 ${_bundle.totalCount}',
                      selected: _filter == _SearchFilter.all,
                      onTap: () => setState(() => _filter = _SearchFilter.all),
                    ),
                    _FilterChip(
                      label: '旧动态谱 ${_bundle.dynamicSongs.length}',
                      selected: _filter == _SearchFilter.dynamic,
                      onTap: () =>
                          setState(() => _filter = _SearchFilter.dynamic),
                    ),
                    _FilterChip(
                      label: '悦谱视频 ${_bundle.yuepuVideos.length}',
                      selected: _filter == _SearchFilter.yuepuVideo,
                      onTap: () =>
                          setState(() => _filter = _SearchFilter.yuepuVideo),
                    ),
                    _FilterChip(
                      label:
                          '曲谱 ${_bundle.forumSheets.length + _bundle.yuepuSheets.length}',
                      selected: _filter == _SearchFilter.sheet,
                      onTap: () =>
                          setState(() => _filter = _SearchFilter.sheet),
                    ),
                    _FilterChip(
                      label: '伴奏 ${_bundle.accompaniments.length}',
                      selected: _filter == _SearchFilter.accompaniment,
                      onTap: () =>
                          setState(() => _filter = _SearchFilter.accompaniment),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildResults()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_searched) {
      return const StateView(
        icon: AppIcons.searchRounded,
        title: '搜所有谱库',
        message: '输入关键词后，会同时搜索旧动态谱、图片谱、悦谱视频、悦谱曲谱和伴奏。',
      );
    }
    if (_error != null) {
      return StateView(
        icon: AppIcons.wifiOffRounded,
        title: '搜索失败',
        message: '$_error',
        action: FilledButton.icon(
          onPressed: _search,
          icon: const Icon(AppIcons.refreshRounded),
          label: const Text('重试'),
        ),
      );
    }
    if (_bundle.isEmpty) {
      return const StateView(
        icon: AppIcons.searchRounded,
        title: '没有找到结果',
        message: '换一个更短的关键词试试。',
      );
    }

    final children = <Widget>[];
    void addSection(String title, String subtitle, List<Widget> items) {
      if (items.isEmpty) return;
      children.add(_SectionHeader(title: title, subtitle: subtitle));
      children.add(const SizedBox(height: 10));
      for (final item in items) {
        children.add(item);
        children.add(const SizedBox(height: 10));
      }
      children.add(const SizedBox(height: 4));
    }

    if (_filter == _SearchFilter.all || _filter == _SearchFilter.dynamic) {
      addSection('旧动态谱', '文本简谱，可进入原阅读器练习', [
        for (final song in _bundle.dynamicSongs)
          _ResultCard(
            title: song.title,
            subtitle: song.subtitle,
            badge: '动态谱',
            metric: song.times > 0 ? '练习 ${song.times}' : '旧接口',
            icon: AppIcons.graphicEqRounded,
            favorite: widget.favorites.contains(
              ScoreKind.dynamic,
              song.favoriteId,
            ),
            onFavorite: () => widget.favorites.toggle(song.toFavoriteItem()),
            onTap: () => _openDynamic(song),
          ),
      ]);
    }
    if (_filter == _SearchFilter.all || _filter == _SearchFilter.yuepuVideo) {
      addSection('悦谱视频谱', '可预览 MP4、多轨音频和正式资源状态', [
        for (final song in _bundle.yuepuVideos)
          _ResultCard(
            title: song.title,
            subtitle: song.subtitle,
            badge: '悦谱视频',
            metric: song.tracks.isEmpty ? '预览 MP4' : '${song.tracks.length} 轨',
            icon: AppIcons.playCircleOutline,
            favorite: widget.favorites.contains(
              ScoreKind.dynamic,
              song.favoriteId,
            ),
            onFavorite: () => widget.favorites.toggle(song.toFavoriteItem()),
            onTap: () => _openYuepuVideo(song),
          ),
      ]);
    }
    if (_filter == _SearchFilter.all || _filter == _SearchFilter.sheet) {
      addSection('曲谱', '图片谱文章和悦谱图片/PDF 曲谱', [
        for (final item in [..._bundle.yuepuSheets, ..._bundle.forumSheets])
          _ResultCard(
            title: item.title,
            subtitle: item.displaySubtitle,
            badge: item.isYuepu ? '悦谱曲谱' : '图片谱',
            metric: item.views > 0 ? '${item.views} 浏览' : item.fileType,
            icon: item.isYuepu
                ? AppIcons.menuBookRounded
                : AppIcons.imageOutlined,
            favorite: widget.favorites.contains(ScoreKind.image, item.id),
            onFavorite: () => widget.favorites.toggle(item.toFavoriteItem()),
            onTap: () => _openSheet(item),
          ),
      ]);
    }
    if (_filter == _SearchFilter.all ||
        _filter == _SearchFilter.accompaniment) {
      addSection('伴奏', '悦谱伴奏音频，支持直接试听', [
        for (final item in _bundle.accompaniments)
          _ResultCard(
            title: item.title,
            subtitle: item.subtitle.isEmpty ? item.category : item.subtitle,
            badge: '伴奏',
            metric: item.playCount > 0 ? '${item.playCount} 播放' : 'MP3',
            icon: AppIcons.playlistPlayRounded,
            favorite: widget.favorites.contains(
              ScoreKind.accompaniment,
              item.favoriteId,
            ),
            onFavorite: () => widget.favorites.toggle(item.toFavoriteItem()),
            onTap: () => _openAccompaniment(item),
          ),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (_bundle.errors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PartialErrorBanner(count: _bundle.errors.length),
          ),
        ...children,
      ],
    );
  }

  void _openDynamic(MusicSummary song) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DynamicDetailPage(
          api: widget.api,
          song: song,
          favorites: widget.favorites,
          settings: widget.settings,
        ),
      ),
    );
  }

  void _openYuepuVideo(MusicSummary song) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YuepuResourceDetailPage.dynamic(
          song: song,
          favorites: widget.favorites,
        ),
      ),
    );
  }

  void _openSheet(ImageScoreItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => item.isYuepu
            ? YuepuResourceDetailPage.sheet(
                sheet: item,
                favorites: widget.favorites,
              )
            : ImageDetailPage(
                api: widget.api,
                item: item,
                favorites: widget.favorites,
                settings: widget.settings,
              ),
      ),
    );
  }

  void _openAccompaniment(AccompanimentItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YuepuResourceDetailPage.accompaniment(
          accompaniment: item,
          favorites: widget.favorites,
        ),
      ),
    );
  }
}

class _SearchBundle {
  const _SearchBundle({
    this.dynamicSongs = const [],
    this.forumSheets = const [],
    this.yuepuVideos = const [],
    this.yuepuSheets = const [],
    this.accompaniments = const [],
    this.errors = const [],
  });

  final List<MusicSummary> dynamicSongs;
  final List<ImageScoreItem> forumSheets;
  final List<MusicSummary> yuepuVideos;
  final List<ImageScoreItem> yuepuSheets;
  final List<AccompanimentItem> accompaniments;
  final List<Object> errors;

  int get totalCount =>
      dynamicSongs.length +
      forumSheets.length +
      yuepuVideos.length +
      yuepuSheets.length +
      accompaniments.length;

  bool get isEmpty => totalCount == 0;
}

class _GroupResult<T> {
  const _GroupResult({required this.items, this.error});

  final List<T> items;
  final Object? error;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

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
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: palette.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.metric,
    required this.icon,
    required this.favorite,
    required this.onFavorite,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String metric;
  final IconData icon;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 54,
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(radiusMedium),
                ),
                child: Icon(icon, color: palette.brand),
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
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle.isEmpty ? '暂无说明' : subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        InfoPill(label: badge, color: palette.brand),
                        InfoPill(label: metric, color: palette.amber),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: favorite ? '取消收藏' : '收藏',
                onPressed: onFavorite,
                icon: Icon(
                  favorite
                      ? AppIcons.bookmarkRounded
                      : AppIcons.bookmarkBorderRounded,
                  color: favorite ? palette.accent : palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartialErrorBanner extends StatelessWidget {
  const _PartialErrorBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(AppIcons.wifiOffRounded, color: palette.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count 个接口暂时不可用，已展示其余结果。',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
