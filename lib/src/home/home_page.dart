import 'package:flutter/material.dart';

import '../audio/tone_synth.dart';
import '../theme/app_icons.dart';

import '../data/app_settings.dart';
import '../data/favorites_store.dart';
import '../data/jianpu_api.dart';
import '../data/models.dart';
import '../details/dynamic_detail_page.dart';
import '../details/image_detail_page.dart';
import '../pro/jianpu_local_score_store.dart';
import '../pro/jianpu_maker_page.dart';
import '../pro/jianpu_practice_page.dart';
import '../pro/metronome_page.dart';
import '../pro/scale_lab_page.dart';
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
  final _localScores = JianpuLocalScoreStore();
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
    _localScores.load();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
    if (_tab > 1 || _query.trim().isNotEmpty || _loading || _loadingMore) {
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
      animation: Listenable.merge([_favorites, _localScores, widget.settings]),
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _HomeTopBar(
                  controller: _searchController,
                  tab: _tab,
                  onSearch: (value) {
                    if (_tab > 1) return;
                    _query = value;
                    _load();
                  },
                  onSettings: _openSettings,
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
          bottomNavigationBar: _HomeNavigation(
            selectedIndex: _tab,
            onChanged: (index) {
              setState(() {
                _tab = index;
                _query = '';
                _searchController.clear();
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
    );
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
            leadingIcon: AppIcons.graphicEqRounded,
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
                ? AppIcons.playCircleOutline
                : AppIcons.imageOutlined,
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
    final localItems = _localScores.items;
    if (items.isEmpty && localItems.isEmpty) {
      return const StateView(
        icon: AppIcons.bookmarkAddOutlined,
        title: '还没有收藏',
        message: '收藏和本地制作的谱子会放在这里',
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        widget.settings.compactList ? 6 : 10,
        16,
        24,
      ),
      children: [
        if (localItems.isNotEmpty) ...[
          const _SectionHeader(title: '本地制作', subtitle: '点击加载到制作页'),
          const SizedBox(height: 10),
          for (final item in localItems) ...[
            _LocalScoreTile(
              item: item,
              compact: widget.settings.compactList,
              onTap: () => _openLocalScore(item),
              onDelete: () => _deleteLocalScore(item),
            ),
            const SizedBox(height: 10),
          ],
          if (items.isNotEmpty) const SizedBox(height: 6),
        ],
        if (items.isNotEmpty) ...[
          const _SectionHeader(title: '我的收藏', subtitle: '动态谱和图片谱'),
          const SizedBox(height: 10),
          for (final item in items) ...[
            ScoreCard(
              title: item.title,
              subtitle: item.subtitle.isEmpty
                  ? (item.kind == ScoreKind.dynamic ? '动态谱' : '图片谱')
                  : item.subtitle,
              metric: item.kind == ScoreKind.dynamic ? '动态谱' : '图片谱',
              badge: '收藏',
              favorite: true,
              imageUrl: item.imageUrl,
              leadingIcon: item.kind == ScoreKind.dynamic
                  ? AppIcons.graphicEqRounded
                  : AppIcons.imageOutlined,
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

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.controller,
    required this.tab,
    required this.onSearch,
    required this.onSettings,
  });

  final TextEditingController controller;
  final int tab;
  final ValueChanged<String> onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final searchEnabled = tab < 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: palette.paper,
        border: Border(bottom: BorderSide(color: palette.line)),
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
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return SizedBox(
                height: 44,
                child: TextField(
                  controller: controller,
                  enabled: searchEnabled,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSearch,
                  decoration: InputDecoration(
                    hintText: switch (tab) {
                      0 => '搜索歌名、歌手、编配',
                      1 => '搜索图片谱标题',
                      2 => '收藏页不需要搜索',
                      _ => '工具页不需要搜索',
                    },
                    prefixIcon: const Icon(AppIcons.searchRounded, size: 21),
                    suffixIcon: !searchEnabled || value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              controller.clear();
                              onSearch('');
                            },
                            icon: const Icon(AppIcons.closeRounded, size: 20),
                          ),
                  ),
                ),
              );
            },
          ),
        ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: NavigationBar(
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
  });

  final AppSettings settings;
  final VoidCallback onMaker;
  final VoidCallback onPractice;
  final VoidCallback onScaleLab;
  final VoidCallback onMetronome;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          decoration: BoxDecoration(
            color: palette.paperTint,
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(radiusMedium),
                ),
                child: Icon(AppIcons.tuneRounded, color: palette.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '练习工具',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '音色、节奏、唱谱训练集中管理',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
