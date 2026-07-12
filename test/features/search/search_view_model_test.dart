import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/app/app_dependencies.dart';
import 'package:jianpu_study_app/src/core/error/failure.dart';
import 'package:jianpu_study_app/src/domain/models/models.dart';
import 'package:jianpu_study_app/src/domain/repositories/score_repository.dart';
import 'package:jianpu_study_app/src/features/search/search_view_model.dart';

void main() {
  test('keeps successful group when another search group fails', () async {
    final repository = _SearchRepository()..failDynamic = true;
    final container = _container(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(searchViewModelProvider.notifier);

    viewModel.queryChanged('春风');
    await viewModel.searchNow();

    final state = container.read(searchViewModelProvider);
    expect(state.dynamicError, '动态搜索失败');
    expect(state.imageScores.single.title, '春风图片谱');
    expect(state.isLoading, isFalse);
  });

  test('an older query cannot replace a newer query result', () async {
    final repository = _SearchRepository()..holdOldQuery = true;
    final container = _container(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(searchViewModelProvider.notifier);

    viewModel.queryChanged('旧');
    final oldSearch = viewModel.searchNow();
    viewModel.queryChanged('新');
    await viewModel.searchNow();
    repository.oldDynamic.complete([_music('旧结果')]);
    repository.oldImage.complete(const []);
    await oldSearch;

    final state = container.read(searchViewModelProvider);
    expect(state.query, '新');
    expect(state.dynamicScores.single.title, '新动态谱');
  });
}

ProviderContainer _container(ScoreRepository repository) => ProviderContainer(
  overrides: [scoreRepositoryProvider.overrideWithValue(repository)],
);

MusicSummary _music(String title) => MusicSummary(
  id: title.hashCode,
  title: title,
  singer: '',
  arranger: '',
  times: 0,
  level: 0,
);

final class _SearchRepository implements ScoreRepository {
  var failDynamic = false;
  var holdOldQuery = false;
  final oldDynamic = Completer<List<MusicSummary>>();
  final oldImage = Completer<List<ImageScoreItem>>();

  @override
  Future<ImageScoreDetail> getImageScoreDetail(ImageScoreItem item) =>
      throw UnimplementedError();

  @override
  Future<DynamicScoreContent> getDynamicScore(int id) =>
      throw UnimplementedError();

  @override
  Future<PageResult<MusicSummary>> getDynamicScores({
    required ScoreSource source,
    required int page,
    int pageSize = 30,
    String query = '',
  }) async {
    if (failDynamic) throw const NetworkFailure('动态搜索失败');
    if (holdOldQuery && query == '旧') {
      return PageResult(
        items: await oldDynamic.future,
        page: 1,
        hasMore: false,
      );
    }
    return PageResult(items: [_music('$query动态谱')], page: 1, hasMore: false);
  }

  @override
  Future<PageResult<ImageScoreItem>> getImageScores({
    required ScoreSource source,
    required int page,
    int pageSize = 30,
    String query = '',
  }) async {
    if (holdOldQuery && query == '旧') {
      return PageResult(items: await oldImage.future, page: 1, hasMore: false);
    }
    return PageResult(
      items: [
        ImageScoreItem(
          id: query,
          title: '$query图片谱',
          summary: '',
          pic: '',
          views: 0,
          hasVideo: false,
          date: '',
        ),
      ],
      page: 1,
      hasMore: false,
    );
  }
}
