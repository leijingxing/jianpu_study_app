import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/score_repository.dart';
import '../../routing/app_routes.dart';
import 'search_state.dart';
import 'search_view_model.dart';

/// V2 综合搜索页面。
final class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchViewModelProvider);
    final viewModel = ref.read(searchViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('综合搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchBar(
              autoFocus: true,
              hintText: '搜索曲名、歌手或编配者',
              leading: const Icon(Icons.search),
              trailing: state.isLoading
                  ? const [
                      SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ]
                  : null,
              onChanged: viewModel.queryChanged,
              onSubmitted: (_) => viewModel.searchNow(),
            ),
          ),
          SegmentedButton<ScoreSource>(
            segments: const [
              ButtonSegment(value: ScoreSource.guji, label: Text('古籍谱库')),
              ButtonSegment(value: ScoreSource.yuepu, label: Text('悦谱资源')),
            ],
            selected: {state.source},
            onSelectionChanged: (value) => viewModel.selectSource(value.single),
          ),
          const SizedBox(height: 8),
          Expanded(child: _SearchResults(state: state)),
        ],
      ),
    );
  }
}

final class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    if (state.query.trim().isEmpty) {
      return const Center(child: Text('输入关键词开始搜索'));
    }
    if (state.isLoading && !state.hasResults) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.hasResults &&
        (state.dynamicError != null || state.imageError != null)) {
      return Center(
        child: Text(state.dynamicError ?? state.imageError ?? '搜索失败'),
      );
    }
    if (!state.hasResults) return const Center(child: Text('没有找到相关乐谱'));

    return ListView(
      children: [
        if (state.dynamicError case final error?) _ErrorBanner(message: error),
        if (state.dynamicScores.isNotEmpty) ...[
          const _SectionTitle(label: '动态谱'),
          for (final score in state.dynamicScores)
            ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(score.title),
              subtitle: Text(score.subtitle),
              onTap: () => context.push(AppRoutes.dynamicScore, extra: score),
            ),
        ],
        if (state.imageError case final error?) _ErrorBanner(message: error),
        if (state.imageScores.isNotEmpty) ...[
          const _SectionTitle(label: '图片谱'),
          for (final score in state.imageScores)
            ListTile(
              leading: const Icon(Icons.library_music),
              title: Text(score.title),
              subtitle: Text(score.displaySubtitle),
              onTap: () => context.push(AppRoutes.imageScore, extra: score),
            ),
        ],
      ],
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}

final class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialBanner(
    content: Text(message),
    actions: const [SizedBox.shrink()],
  );
}
