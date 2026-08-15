import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/score_repository.dart';
import '../../routing/app_routes.dart';
import 'home_state.dart';
import 'home_view_model.dart';

/// V2 首页，只负责展示状态和转发用户命令。
final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(homeViewModelProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);
    final viewModel = ref.read(homeViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('轻谱'),
        actions: [
          IconButton(
            tooltip: '综合搜索',
            onPressed: () => context.push(AppRoutes.search),
            icon: const Icon(Icons.search),
          ),
          if (state.section.index <= HomeSection.imageScores.index)
            PopupMenuButton<ScoreSource>(
              tooltip: '选择数据源',
              initialValue: state.source,
              onSelected: viewModel.selectSource,
              itemBuilder: (context) => const [
                PopupMenuItem(value: ScoreSource.guji, child: Text('古籍谱库')),
                PopupMenuItem(value: ScoreSource.yuepu, child: Text('悦谱资源')),
              ],
              icon: const Icon(Icons.cloud_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => viewModel.load(refresh: true),
          child: _HomeBody(state: state),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.section.index,
        onDestinationSelected: (index) {
          viewModel.selectSection(HomeSection.values[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note),
            label: '动态谱',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: '图片谱',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: '收藏',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '工具',
          ),
        ],
      ),
    );
  }
}

final class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (state.errorMessage case final message?) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.cloud_off_outlined, size: 56),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () =>
                ref.read(homeViewModelProvider.notifier).load(refresh: true),
            child: const Text('重新加载'),
          ),
        ],
      );
    }
    return switch (state.section) {
      HomeSection.dynamicScores => _DynamicScoreList(state: state),
      HomeSection.imageScores => _ImageScoreList(state: state),
      HomeSection.favorites => _FavoriteList(items: state.favorites),
      HomeSection.tools => const _ToolGrid(),
    };
  }
}

final class _DynamicScoreList extends ConsumerWidget {
  const _DynamicScoreList({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.dynamicScores.isEmpty) return const _EmptyList(label: '暂无动态谱');
    return _PagedList(
      itemCount: state.dynamicScores.length,
      isLoadingMore: state.isLoadingMore,
      onLoadMore: ref.read(homeViewModelProvider.notifier).loadMore,
      itemBuilder: (context, index) {
        final score = state.dynamicScores[index];
        final favorite = state.favorites.any(
          (item) =>
              item.kind == ScoreKind.dynamic && item.id == score.favoriteId,
        );
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.music_note)),
          title: Text(
            score.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            score.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: favorite ? '取消收藏' : '收藏',
            onPressed: () => ref
                .read(homeViewModelProvider.notifier)
                .toggleDynamicScore(score),
            icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_outline),
          ),
          onTap: () async {
            await context.push(AppRoutes.dynamicScore, extra: score);
            if (context.mounted) {
              ref.read(homeViewModelProvider.notifier).refreshFavorites();
            }
          },
        );
      },
    );
  }
}

final class _ImageScoreList extends ConsumerWidget {
  const _ImageScoreList({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.imageScores.isEmpty) return const _EmptyList(label: '暂无图片谱');
    return _PagedList(
      itemCount: state.imageScores.length,
      isLoadingMore: state.isLoadingMore,
      onLoadMore: ref.read(homeViewModelProvider.notifier).loadMore,
      itemBuilder: (context, index) {
        final score = state.imageScores[index];
        final favorite = state.favorites.any(
          (item) => item.kind == ScoreKind.image && item.id == score.id,
        );
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.library_music)),
          title: Text(
            score.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            score.displaySubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: favorite ? '取消收藏' : '收藏',
            onPressed: () => ref
                .read(homeViewModelProvider.notifier)
                .toggleImageScore(score),
            icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_outline),
          ),
          onTap: () async {
            await context.push(AppRoutes.imageScore, extra: score);
            if (context.mounted) {
              ref.read(homeViewModelProvider.notifier).refreshFavorites();
            }
          },
        );
      },
    );
  }
}

final class _PagedList extends StatefulWidget {
  const _PagedList({
    required this.itemCount,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.isLoadingMore,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Future<void> Function() onLoadMore;
  final bool isLoadingMore;

  @override
  State<_PagedList> createState() => _PagedListState();
}

final class _PagedListState extends State<_PagedList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (_controller.position.extentAfter < 360) widget.onLoadMore();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.separated(
    controller: _controller,
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: widget.itemCount + (widget.isLoadingMore ? 1 : 0),
    separatorBuilder: (context, index) => const Divider(height: 1),
    itemBuilder: (context, index) => index == widget.itemCount
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        : widget.itemBuilder(context, index),
  );
}

final class _FavoriteList extends ConsumerWidget {
  const _FavoriteList({required this.items});

  final List<FavoriteItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const _EmptyList(label: '还没有收藏');
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: Icon(switch (item.kind) {
            ScoreKind.dynamic => Icons.music_note,
            ScoreKind.image => Icons.library_music,
            ScoreKind.accompaniment => Icons.headphones,
          }),
          title: Text(item.title),
          subtitle: Text(item.subtitle),
          trailing: IconButton(
            tooltip: '取消收藏',
            onPressed: () =>
                ref.read(homeViewModelProvider.notifier).toggleFavorite(item),
            icon: const Icon(Icons.bookmark_remove_outlined),
          ),
          onTap: item.kind == ScoreKind.accompaniment
              ? null
              : () async {
                  final viewModel = ref.read(homeViewModelProvider.notifier);
                  final target = viewModel.resolveFavorite(item);
                  switch (target) {
                    case DynamicFavoriteTarget(:final score):
                      await context.push(AppRoutes.dynamicScore, extra: score);
                    case ImageFavoriteTarget(:final score):
                      await context.push(AppRoutes.imageScore, extra: score);
                    case AccompanimentFavoriteTarget():
                      return;
                  }
                  if (context.mounted) viewModel.refreshFavorites();
                },
        );
      },
    );
  }
}

final class _ToolGrid extends StatelessWidget {
  const _ToolGrid();

  static const tools = <({String label, IconData icon, String route})>[
    (label: '简谱制作', icon: Icons.edit_note, route: AppRoutes.maker),
    (label: '节拍器', icon: Icons.timer_outlined, route: AppRoutes.metronome),
    (label: '音阶实验室', icon: Icons.piano, route: AppRoutes.scaleLab),
    (label: '简谱游戏', icon: Icons.sports_esports, route: AppRoutes.game),
    (label: '乐器分析', icon: Icons.graphic_eq, route: AppRoutes.analyzer),
  ];

  @override
  Widget build(BuildContext context) => GridView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 240,
      mainAxisExtent: 132,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ),
    itemCount: tools.length,
    itemBuilder: (context, index) {
      final tool = tools[index];
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(tool.route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.icon, size: 36),
                const SizedBox(height: 12),
                Text(
                  tool.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

final class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 180),
      const Icon(Icons.inbox_outlined, size: 52),
      const SizedBox(height: 12),
      Text(label, textAlign: TextAlign.center),
    ],
  );
}
