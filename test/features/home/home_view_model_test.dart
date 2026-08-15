import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/app/app_dependencies.dart';
import 'package:jianpu_study_app/src/domain/models/models.dart';
import 'package:jianpu_study_app/src/domain/repositories/favorites_repository.dart';
import 'package:jianpu_study_app/src/domain/repositories/score_repository.dart';
import 'package:jianpu_study_app/src/features/home/home_view_model.dart';

void main() {
  test('load publishes repository results', () async {
    final repository = _FakeScoreRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await container.read(homeViewModelProvider.notifier).load();

    final state = container.read(homeViewModelProvider);
    expect(state.dynamicScores.single.title, '测试曲谱');
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('loadMore ignores duplicate requests while one is active', () async {
    final repository = _FakeScoreRepository()..holdPageTwo = true;
    final container = _container(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(homeViewModelProvider.notifier);
    await viewModel.load();

    final first = viewModel.loadMore();
    final second = viewModel.loadMore();
    repository.pageTwo.complete([_music(2)]);
    await Future.wait([first, second]);

    expect(repository.pageTwoCalls, 1);
    expect(container.read(homeViewModelProvider).dynamicScores, hasLength(2));
  });

  test('older request cannot overwrite a newer source selection', () async {
    final repository = _FakeScoreRepository()..holdGuji = true;
    final container = _container(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(homeViewModelProvider.notifier);

    final oldRequest = viewModel.load();
    await viewModel.selectSource(ScoreSource.yuepu);
    repository.guji.complete([_music(9, title: '过期结果')]);
    await oldRequest;

    expect(
      container.read(homeViewModelProvider).dynamicScores.single.title,
      '悦谱结果',
    );
  });
}

ProviderContainer _container(ScoreRepository repository) => ProviderContainer(
  overrides: [
    scoreRepositoryProvider.overrideWithValue(repository),
    favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
  ],
);

MusicSummary _music(int id, {String title = '测试曲谱'}) => MusicSummary(
  id: id,
  title: title,
  singer: '',
  arranger: '',
  times: 0,
  level: 0,
);

final class _FakeScoreRepository implements ScoreRepository {
  var holdPageTwo = false;
  var holdGuji = false;
  var pageTwoCalls = 0;
  final pageTwo = Completer<List<MusicSummary>>();
  final guji = Completer<List<MusicSummary>>();

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
    if (source == ScoreSource.yuepu) {
      return PageResult(
        items: [_music(7, title: '悦谱结果')],
        page: page,
        hasMore: false,
      );
    }
    if (holdGuji && page == 1) {
      return PageResult(items: await guji.future, page: page, hasMore: false);
    }
    if (holdPageTwo && page == 2) {
      pageTwoCalls++;
      return PageResult(
        items: await pageTwo.future,
        page: page,
        hasMore: false,
      );
    }
    return PageResult(items: [_music(page)], page: page, hasMore: true);
  }

  @override
  Future<PageResult<ImageScoreItem>> getImageScores({
    required ScoreSource source,
    required int page,
    int pageSize = 30,
    String query = '',
  }) async => PageResult(items: const [], page: page, hasMore: false);
}

final class _FakeFavoritesRepository implements FavoritesRepository {
  final _items = <FavoriteItem>[];

  @override
  bool contains(ScoreKind kind, String id) =>
      _items.any((item) => item.kind == kind && item.id == id);

  @override
  List<FavoriteItem> getAll() => List.unmodifiable(_items);

  @override
  Future<List<FavoriteItem>> toggle(FavoriteItem item) async {
    final index = _items.indexWhere((value) => value.key == item.key);
    index < 0 ? _items.add(item) : _items.removeAt(index);
    return getAll();
  }

  @override
  Future<List<FavoriteItem>> toggleDynamicScore(MusicSummary score) => toggle(
    FavoriteItem(
      kind: ScoreKind.dynamic,
      id: score.favoriteId,
      title: score.title,
      subtitle: score.subtitle,
    ),
  );

  @override
  Future<List<FavoriteItem>> toggleImageScore(ImageScoreItem score) => toggle(
    FavoriteItem(
      kind: ScoreKind.image,
      id: score.id,
      title: score.title,
      subtitle: score.displaySubtitle,
      imageUrl: score.imageUrl,
    ),
  );

  @override
  FavoriteTarget resolve(FavoriteItem item) => switch (item.kind) {
    ScoreKind.dynamic => DynamicFavoriteTarget(_music(int.parse(item.id))),
    _ => throw UnimplementedError(),
  };
}
