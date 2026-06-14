import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../audio/tone_synth.dart';
import '../theme/app_icons.dart';

import '../data/app_settings.dart';
import '../data/favorites_store.dart';
import '../data/jianpu_api.dart';
import '../data/models.dart';
import '../details/dynamic_detail_page.dart';
import '../details/image_detail_page.dart';
import '../details/yuepu_resource_detail_page.dart';
import '../pro/instrument_analyzer_page.dart';
import '../pro/jianpu_local_score_store.dart';
import '../pro/jianpu_maker_page.dart';
import '../pro/jianpu_practice_page.dart';
import '../pro/metronome_page.dart';
import '../pro/scale_lab_page.dart';
import '../search/comprehensive_search_page.dart';
import '../settings/settings_page.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

enum _HomeSource { legacy, yuepu }

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = JianpuApi();
  final _favorites = FavoritesStore();
  final _localScores = JianpuLocalScoreStore();
  final _scrollController = ScrollController();
  var _tab = 0;
  var _query = '';
  var _source = _HomeSource.legacy;
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
    _localScores.load();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _favorites.dispose();
    _localScores.dispose();
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
        final songs = await _fetchDynamicPage(_dynamicPage);
        _dynamicSongs = songs;
        _dynamicHasMore = songs.isNotEmpty;
      } else if (_tab == 1) {
        final scores = await _fetchImagePage(_imagePage);
        _imageScores = scores;
        _imageHasMore = scores.isNotEmpty;
      }
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final hasMore = _tab == 0 ? _dynamicHasMore : _imageHasMore;
    if (_tab > 1 || _loading || _loadingMore) {
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
        final songs = await _fetchDynamicPage(nextPage);
        _dynamicPage = nextPage;
        _dynamicHasMore = songs.isNotEmpty;
        _dynamicSongs.addAll(songs);
      } else if (_tab == 1) {
        final nextPage = _imagePage + 1;
        final scores = await _fetchImagePage(nextPage);
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

  Future<List<MusicSummary>> _fetchDynamicPage(int page) {
    return switch (_source) {
      _HomeSource.legacy => _api.fetchDynamicList(page: page),
      _HomeSource.yuepu => _api.fetchYuepuDynamicList(page: page),
    };
  }

  Future<List<ImageScoreItem>> _fetchImagePage(int page) {
    return switch (_source) {
      _HomeSource.legacy => _api.fetchImageList(page: page),
      _HomeSource.yuepu => _api.fetchYuepuSheetList(page: page),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_favorites, _localScores, widget.settings]),
      builder: (context, _) {
        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              Positioned.fill(child: _buildBody()),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _HomeTopBar(
                  tab: _tab,
                  source: _source,
                  onOpenSearch: _openSearch,
                  onSourceChanged: _changeSource,
                  onSettings: _openSettings,
                ),
              ),
            ],
          ),
          bottomNavigationBar: _HomeNavigation(
            selectedIndex: _tab,
            onChanged: (index) {
              setState(() {
                _tab = index;
                _query = '';
                _error = null;
              });
              if (index < 2) _load();
            },
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_tab == 2) return _buildFavorites();
    if (_tab == 3) return _buildTools();
    if (_error != null && (_dynamicSongs.isEmpty && _imageScores.isEmpty)) {
      return StateView(
        icon: AppIcons.wifiOffRounded,
        title: '接口暂时不可用',
        message: '$_error',
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(AppIcons.refreshRounded),
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

  Widget _buildTools() {
    return _ToolHub(
      settings: widget.settings,
      onMaker: () async {
        await Navigator.of(context).pushNamed(JianpuMakerPage.routeName);
        await _localScores.load();
      },
      onPractice: () =>
          Navigator.of(context).pushNamed(JianpuPracticePage.routeName),
      onScaleLab: () => Navigator.of(context).pushNamed(ScaleLabPage.routeName),
      onMetronome: () =>
          Navigator.of(context).pushNamed(MetronomePage.routeName),
      onInstrumentAnalyzer: () =>
          Navigator.of(context).pushNamed(InstrumentAnalyzerPage.routeName),
    );
  }

  Widget _buildDynamicList() {
    final topPadding = _contentTopPadding(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          16,
          (widget.settings.compactList ? 6 : 10) + topPadding,
          16,
          96,
        ),
        itemCount: _dynamicSongs.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _dynamicSongs.length) {
            return LoadMoreIndicator(
              loading: _loadingMore,
              hasMore: _dynamicHasMore,
            );
          }
          final song = _dynamicSongs[index];
          final favorite = _favorites.contains(
            ScoreKind.dynamic,
            song.favoriteId,
          );
          return ScoreCard(
            title: song.title,
            subtitle: song.subtitle,
            metric: song.isYuepu
                ? (song.tracks.isEmpty ? '预览视频' : '${song.tracks.length} 轨')
                : '练习 ${song.times}',
            badge: song.isYuepu
                ? '悦谱资源'
                : (song.level > 0 ? '难度 ${song.level}' : '动态谱'),
            favorite: favorite,
            leadingIcon: song.isYuepu
                ? AppIcons.playCircleOutline
                : AppIcons.graphicEqRounded,
            compact: widget.settings.compactList,
            reduceMotion: widget.settings.reduceMotion,
            onFavorite: () => _favorites.toggle(song.toFavoriteItem()),
            onTap: () => _openDynamicDetail(song),
          );
        },
      ),
    );
  }

  Widget _buildImageList() {
    final topPadding = _contentTopPadding(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          16,
          (widget.settings.compactList ? 6 : 10) + topPadding,
          16,
          96,
        ),
        itemCount: _imageScores.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _imageScores.length) {
            return LoadMoreIndicator(
              loading: _loadingMore,
              hasMore: _imageHasMore,
            );
          }
          final item = _imageScores[index];
          final favorite = _favorites.contains(ScoreKind.image, item.id);
          return ScoreCard(
            title: item.title,
            subtitle: item.displaySubtitle,
            metric: '${item.views} 浏览',
            badge: item.isYuepu ? '悦谱曲谱' : (item.hasVideo ? '视频' : '图片'),
            favorite: favorite,
            imageUrl: item.imageUrl,
            leadingIcon: item.isYuepu
                ? AppIcons.menuBookRounded
                : item.hasVideo
                ? AppIcons.playCircleOutline
                : AppIcons.imageOutlined,
            compact: widget.settings.compactList,
            reduceMotion: widget.settings.reduceMotion,
            onFavorite: () => _favorites.toggle(item.toFavoriteItem()),
            onTap: () => _openImageDetail(item),
          );
        },
      ),
    );
  }

  Widget _buildFavorites() {
    final items = _favorites.items;
    final localItems = _localScores.items;
    final topPadding = _contentTopPadding(context);
    if (items.isEmpty && localItems.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: 96),
        child: const StateView(
          icon: AppIcons.bookmarkAddOutlined,
          title: '还没有收藏',
          message: '收藏和本地制作的谱子会放在这里',
        ),
      );
    }

    final queryLower = _query.trim().toLowerCase();
    final filteredLocalItems = queryLower.isEmpty
        ? localItems
        : localItems.where((item) {
            final title = item.title.toLowerCase();
            final singer = item.draft.singer.toLowerCase();
            final composer = item.draft.composer.toLowerCase();
            return title.contains(queryLower) ||
                singer.contains(queryLower) ||
                composer.contains(queryLower);
          }).toList();

    final filteredItems = queryLower.isEmpty
        ? items
        : items.where((item) {
            final title = item.title.toLowerCase();
            final subtitle = item.subtitle.toLowerCase();
            return title.contains(queryLower) || subtitle.contains(queryLower);
          }).toList();

    if (queryLower.isNotEmpty &&
        filteredLocalItems.isEmpty &&
        filteredItems.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding + 40, bottom: 96),
        child: const StateView(
          icon: AppIcons.searchRounded,
          title: '未找到匹配的收藏',
          message: '尝试用其他关键字搜索吧',
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        (widget.settings.compactList ? 6 : 10) + topPadding,
        16,
        96,
      ),
      children: [
        if (filteredLocalItems.isNotEmpty) ...[
          const _SectionHeader(title: '本地制作', subtitle: '点击加载到制作页'),
          const SizedBox(height: 10),
          for (final item in filteredLocalItems) ...[
            _LocalScoreTile(
              item: item,
              compact: widget.settings.compactList,
              onTap: () => _openLocalScore(item),
              onDelete: () => _deleteLocalScore(item),
            ),
            const SizedBox(height: 10),
          ],
          if (filteredItems.isNotEmpty) const SizedBox(height: 6),
        ],
        if (filteredItems.isNotEmpty) ...[
          const _SectionHeader(title: '我的收藏', subtitle: '动态谱和图片谱'),
          const SizedBox(height: 10),
          for (final item in filteredItems) ...[
            ScoreCard(
              title: item.title,
              subtitle: item.subtitle.isEmpty
                  ? _favoriteFallbackSubtitle(item.kind)
                  : item.subtitle,
              metric: _favoriteKindLabel(item.kind),
              badge: '收藏',
              favorite: true,
              imageUrl: item.imageUrl,
              leadingIcon: _favoriteIcon(item.kind),
              compact: widget.settings.compactList,
              reduceMotion: widget.settings.reduceMotion,
              onFavorite: () => _favorites.toggle(item),
              onTap: () => _openFavorite(item),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Future<void> _openLocalScore(LocalJianpuScore item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JianpuMakerPage(
          settings: widget.settings,
          initialDraft: item.draft,
          localScoreId: item.id,
        ),
      ),
    );
    await _localScores.load();
  }

  Future<void> _deleteLocalScore(LocalJianpuScore item) async {
    await _localScores.delete(item.id);
  }

  void _openFavorite(FavoriteItem item) {
    if (item.kind == ScoreKind.dynamic) {
      _openDynamicDetail(MusicSummary.fromFavorite(item));
    } else if (item.kind == ScoreKind.image) {
      _openImageDetail(ImageScoreItem.favorite(item));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => YuepuResourceDetailPage.accompaniment(
            accompaniment: AccompanimentItem.fromFavorite(item),
            favorites: _favorites,
          ),
        ),
      );
    }
  }

  void _openDynamicDetail(MusicSummary song) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => song.isYuepu
            ? YuepuResourceDetailPage.dynamic(song: song, favorites: _favorites)
            : DynamicDetailPage(
                api: _api,
                song: song,
                favorites: _favorites,
                settings: widget.settings,
              ),
      ),
    );
  }

  void _openImageDetail(ImageScoreItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => item.isYuepu
            ? YuepuResourceDetailPage.sheet(sheet: item, favorites: _favorites)
            : ImageDetailPage(
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

  void _openSearch([String initialQuery = '']) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComprehensiveSearchPage(
          api: _api,
          favorites: _favorites,
          settings: widget.settings,
          initialQuery: initialQuery,
        ),
      ),
    );
  }

  void _changeSource(_HomeSource source) {
    if (_source == source) return;
    setState(() {
      _source = source;
      _error = null;
      _dynamicSongs = [];
      _imageScores = [];
    });
    if (_tab < 2) _load();
  }

  double _contentTopPadding(BuildContext context) {
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    return safeTop + (_tab < 2 ? 116 : 70);
  }

  String _favoriteKindLabel(ScoreKind kind) {
    return switch (kind) {
      ScoreKind.dynamic => '动态谱',
      ScoreKind.image => '图片谱',
      ScoreKind.accompaniment => '伴奏',
    };
  }

  String _favoriteFallbackSubtitle(ScoreKind kind) {
    return switch (kind) {
      ScoreKind.dynamic => '动态谱',
      ScoreKind.image => '图片谱',
      ScoreKind.accompaniment => '伴奏音频',
    };
  }

  IconData _favoriteIcon(ScoreKind kind) {
    return switch (kind) {
      ScoreKind.dynamic => AppIcons.graphicEqRounded,
      ScoreKind.image => AppIcons.imageOutlined,
      ScoreKind.accompaniment => AppIcons.playlistPlayRounded,
    };
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.tab,
    required this.source,
    required this.onOpenSearch,
    required this.onSourceChanged,
    required this.onSettings,
  });

  final int tab;
  final _HomeSource source;
  final ValueChanged<String> onOpenSearch;
  final ValueChanged<_HomeSource> onSourceChanged;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final showSourceTabs = tab < 2;
    final topPadding = MediaQuery.viewPaddingOf(context).top;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10 + topPadding, 16, 12),
          decoration: BoxDecoration(
            color: palette.paper.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(color: palette.line.withValues(alpha: 0.4)),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.brand,
                      borderRadius: BorderRadius.circular(radiusMedium),
                    ),
                    child: Icon(
                      AppIcons.musicNoteRounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '轻谱',
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '专业简谱学习与练习工具',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '综合搜索',
                    onPressed: () => onOpenSearch(''),
                    icon: const Icon(AppIcons.searchRounded),
                    style: IconButton.styleFrom(
                      fixedSize: const Size(40, 40),
                      foregroundColor: palette.text,
                      backgroundColor: palette.paperTint,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radiusMedium),
                        side: BorderSide(color: palette.line),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '设置',
                    onPressed: onSettings,
                    icon: const Icon(AppIcons.settingsOutlined),
                    style: IconButton.styleFrom(
                      fixedSize: const Size(40, 40),
                      foregroundColor: palette.text,
                      backgroundColor: palette.paperTint,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radiusMedium),
                        side: BorderSide(color: palette.line),
                      ),
                    ),
                  ),
                ],
              ),
              if (showSourceTabs) ...[
                const SizedBox(height: 12),
                _SourceTabs(source: source, onChanged: onSourceChanged),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({required this.source, required this.onChanged});

  final _HomeSource source;
  final ValueChanged<_HomeSource> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(radiusMedium),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SourceTabButton(
              label: '旧接口',
              selected: source == _HomeSource.legacy,
              onTap: () => onChanged(_HomeSource.legacy),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SourceTabButton(
              label: '悦谱接口',
              selected: source == _HomeSource.yuepu,
              onTap: () => onChanged(_HomeSource.yuepu),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTabButton extends StatelessWidget {
  const _SourceTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(radiusSmall),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.paperTint : Colors.transparent,
          borderRadius: BorderRadius.circular(radiusSmall),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.brandDark : palette.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HomeNavigation extends StatelessWidget {
  const _HomeNavigation({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: palette.paperTint.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(color: palette.line.withValues(alpha: 0.4)),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: selectedIndex,
            onDestinationSelected: onChanged,
            destinations: const [
              NavigationDestination(
                icon: Icon(AppIcons.graphicEqRounded),
                label: '动态谱',
              ),
              NavigationDestination(
                icon: Icon(AppIcons.imageOutlined),
                label: '图片谱',
              ),
              NavigationDestination(
                icon: Icon(AppIcons.bookmarkBorderRounded),
                label: '收藏',
              ),
              NavigationDestination(
                icon: Icon(AppIcons.grid4x4Rounded),
                label: '工具',
              ),
            ],
          ),
        ),
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocalScoreTile extends StatelessWidget {
  const _LocalScoreTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
    this.compact = false,
  });

  final LocalJianpuScore item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 12),
          child: Row(
            children: [
              Container(
                width: compact ? 54 : 62,
                height: compact ? 62 : 72,
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
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        InfoPill(label: '本地', color: palette.success),
                        InfoPill(
                          label: _formatLocalDate(item.updatedAt),
                          color: palette.brand,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除本地谱',
                onPressed: onDelete,
                icon: Icon(AppIcons.trashRounded, color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLocalDate(DateTime value) {
    return '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class _ToolHub extends StatelessWidget {
  const _ToolHub({
    required this.settings,
    required this.onMaker,
    required this.onPractice,
    required this.onScaleLab,
    required this.onMetronome,
    required this.onInstrumentAnalyzer,
  });

  final AppSettings settings;
  final VoidCallback onMaker;
  final VoidCallback onPractice;
  final VoidCallback onScaleLab;
  final VoidCallback onMetronome;
  final VoidCallback onInstrumentAnalyzer;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.viewPaddingOf(context).top + 60;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 14 + topPadding, 16, 96),
      children: [
        _ToolTile(
          icon: AppIcons.addRounded,
          title: '制作简谱',
          subtitle: '触摸输入、歌词对齐和动态谱实时预览',
          onTap: onMaker,
        ),
        const SizedBox(height: 10),
        _ToolTile(
          icon: AppIcons.menuBookRounded,
          title: '简谱练习',
          subtitle: '符号教学、唱谱、节奏拆解和乐句循环',
          onTap: onPractice,
        ),
        const SizedBox(height: 10),
        _ToolTile(
          icon: AppIcons.pianoOutlined,
          title: '音阶实验室',
          subtitle: '当前音色：${_instrumentName(settings.melodyInstrumentProgram)}',
          onTap: onScaleLab,
        ),
        const SizedBox(height: 10),
        _ToolTile(
          icon: AppIcons.recordVoiceOverRounded,
          title: '乐器分析',
          subtitle: '实时频率、音准、频谱和音色稳定度',
          onTap: onInstrumentAnalyzer,
        ),
        const SizedBox(height: 10),
        _ToolTile(
          icon: AppIcons.avTimerRounded,
          title: '专业节拍器',
          subtitle: 'BPM、Tap Tempo、重音、细分和训练模式',
          onTap: onMetronome,
        ),
      ],
    );
  }

  String _instrumentName(int program) {
    return melodyInstruments
        .firstWhere(
          (item) => item.program == program,
          orElse: () => melodyInstruments.first,
        )
        .name;
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
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
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRightRounded, color: palette.textMuted),
            ],
          ),
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
      child: Container(
        decoration: BoxDecoration(
          color: palette.paperTint,
          borderRadius: BorderRadius.circular(radiusMedium),
          border: Border.all(
            color: palette.line.withValues(alpha: 0.6),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radiusMedium),
          child: InkWell(
            onTap: onTap,
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
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 13,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
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
                            ? AppIcons.bookmarkRounded
                            : AppIcons.bookmarkBorderRounded,
                        key: ValueKey(favorite),
                        color: favorite ? palette.accent : palette.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
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
            AppIcons.graphicEqRounded,
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
