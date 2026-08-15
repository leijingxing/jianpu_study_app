import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/main.dart';
import 'package:jianpu_study_app/src/app/app_dependencies.dart';
import 'package:jianpu_study_app/src/domain/models/models.dart';
import 'package:jianpu_study_app/src/domain/repositories/favorites_repository.dart';
import 'package:jianpu_study_app/src/domain/repositories/score_repository.dart';
import 'package:jianpu_study_app/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('unknown route renders a recoverable error screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final dependencies = AppDependencies(
      scoreRepository: _EmptyScoreRepository(),
      favoritesRepository: _EmptyFavoritesRepository(),
    );
    await dependencies.initialize();
    addTearDown(dependencies.dispose);
    final container = ProviderContainer(
      overrides: [appDependenciesProvider.overrideWithValue(dependencies)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JianpuStudyApp(),
      ),
    );
    container.read(appRouterProvider).go('/missing');
    await tester.pumpAndSettle();

    expect(find.text('页面不存在'), findsOneWidget);
    expect(find.text('返回首页'), findsOneWidget);
  });
}

final class _EmptyScoreRepository implements ScoreRepository {
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
  }) async => PageResult(items: const [], page: page, hasMore: false);

  @override
  Future<PageResult<ImageScoreItem>> getImageScores({
    required ScoreSource source,
    required int page,
    int pageSize = 30,
    String query = '',
  }) async => PageResult(items: const [], page: page, hasMore: false);
}

final class _EmptyFavoritesRepository implements FavoritesRepository {
  @override
  bool contains(ScoreKind kind, String id) => false;

  @override
  List<FavoriteItem> getAll() => const [];

  @override
  Future<List<FavoriteItem>> toggle(FavoriteItem item) async => const [];

  @override
  Future<List<FavoriteItem>> toggleDynamicScore(MusicSummary score) async =>
      const [];

  @override
  Future<List<FavoriteItem>> toggleImageScore(ImageScoreItem score) async =>
      const [];

  @override
  FavoriteTarget resolve(FavoriteItem item) => throw UnimplementedError();
}
