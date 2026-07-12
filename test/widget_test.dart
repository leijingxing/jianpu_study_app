import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/main.dart';
import 'package:jianpu_study_app/src/app/app_dependencies.dart';
import 'package:jianpu_study_app/src/domain/models/models.dart';
import 'package:jianpu_study_app/src/domain/repositories/favorites_repository.dart';
import 'package:jianpu_study_app/src/domain/repositories/score_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the study app shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dependencies = AppDependencies(
      scoreRepository: _EmptyScoreRepository(),
      favoritesRepository: _EmptyFavoritesRepository(),
    );
    await dependencies.initialize();
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDependenciesProvider.overrideWithValue(dependencies)],
        child: const JianpuStudyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('轻谱'), findsOneWidget);
    expect(find.text('动态谱'), findsOneWidget);
    expect(find.text('图片谱'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('工具'), findsOneWidget);
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
}
