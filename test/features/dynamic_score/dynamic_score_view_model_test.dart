import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/app/app_dependencies.dart';
import 'package:jianpu_study_app/src/core/audio/note_playback_service.dart';
import 'package:jianpu_study_app/src/domain/models/models.dart';
import 'package:jianpu_study_app/src/domain/repositories/favorites_repository.dart';
import 'package:jianpu_study_app/src/domain/repositories/score_repository.dart';
import 'package:jianpu_study_app/src/features/dynamic_score/dynamic_score_view_model.dart';
import 'package:jianpu_study_app/src/features/dynamic_score/dynamic_score_screen.dart';
import 'package:jianpu_study_app/src/theme/app_theme.dart';

void main() {
  test('loads content and initializes the playback timeline', () async {
    final dependencies = _Dependencies();
    final container = dependencies.container();
    addTearDown(container.dispose);

    await container.read(dynamicScoreViewModelProvider.notifier).load();

    final state = container.read(dynamicScoreViewModelProvider);
    expect(state.content?.detail.title, '详情');
    expect(state.timeline.notes, hasLength(2));
    expect(state.selectedKey, 'D');
    expect(state.isLoading, isFalse);
  });

  test('playback command delegates sounding notes to audio service', () async {
    final dependencies = _Dependencies();
    final container = dependencies.container();
    addTearDown(container.dispose);
    final viewModel = container.read(dynamicScoreViewModelProvider.notifier);
    await viewModel.load();

    viewModel.togglePlayback();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(dynamicScoreViewModelProvider).isPlaying, isTrue);
    expect(dependencies.audio.playedRaw, ['1']);
    viewModel.stop();
    expect(dependencies.audio.stopCalls, greaterThan(0));
  });

  test(
    'favorite command updates immutable state from repository result',
    () async {
      final dependencies = _Dependencies();
      final container = dependencies.container();
      addTearDown(container.dispose);
      final viewModel = container.read(dynamicScoreViewModelProvider.notifier);
      await viewModel.load();

      await viewModel.toggleFavorite();

      expect(container.read(dynamicScoreViewModelProvider).isFavorite, isTrue);
      expect(dependencies.favorites.items.single.title, '详情');
    },
  );

  testWidgets('score settings reuse the route-scoped view model', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final rootContainer = dependencies.rootContainer();
    addTearDown(rootContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: rootContainer,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: ProviderScope(
            overrides: [
              currentDynamicScoreProvider.overrideWithValue(
                const MusicSummary(
                  id: 1,
                  title: '列表项',
                  singer: '',
                  arranger: '',
                  times: 0,
                  level: 0,
                ),
              ),
            ],
            child: const DynamicScoreScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('谱面设置'));
    await tester.pumpAndSettle();

    expect(find.text('谱面设置'), findsOneWidget);
    expect(find.text('固定调显示'), findsOneWidget);
  });
}

final class _Dependencies {
  final repository = _ScoreRepository();
  final favorites = _FavoritesRepository();
  final audio = _AudioService();

  ProviderContainer rootContainer() => ProviderContainer(
    overrides: [
      scoreRepositoryProvider.overrideWithValue(repository),
      favoritesRepositoryProvider.overrideWithValue(favorites),
      notePlaybackServiceProvider.overrideWithValue(audio),
    ],
  );

  ProviderContainer container() => ProviderContainer(
    overrides: [
      currentDynamicScoreProvider.overrideWithValue(
        const MusicSummary(
          id: 1,
          title: '列表项',
          singer: '',
          arranger: '',
          times: 0,
          level: 0,
        ),
      ),
      scoreRepositoryProvider.overrideWithValue(repository),
      favoritesRepositoryProvider.overrideWithValue(favorites),
      notePlaybackServiceProvider.overrideWithValue(audio),
    ],
  );
}

final class _ScoreRepository implements ScoreRepository {
  @override
  Future<ImageScoreDetail> getImageScoreDetail(ImageScoreItem item) =>
      throw UnimplementedError();

  @override
  Future<DynamicScoreContent> getDynamicScore(int id) async =>
      DynamicScoreContent(
        detail: const MusicDetail(
          id: 1,
          title: '详情',
          originalKey: 'C',
          selectedKey: 'D',
          timeSignature: '4/4',
          bpm: 120,
          singer: '歌手',
          arranger: '',
          composer: '',
          lyricist: '',
          scorePath: '/score.txt',
          coverPath: '',
          times: 0,
        ),
        document: const ScoreDocument(
          title: '详情',
          composer: '',
          lyricist: '',
          notation: ['1 2'],
          lyrics: [],
        ),
      );

  @override
  Future<PageResult<MusicSummary>> getDynamicScores({
    required ScoreSource source,
    required int page,
    int pageSize = 30,
    String query = '',
  }) => throw UnimplementedError();

  @override
  Future<PageResult<ImageScoreItem>> getImageScores({
    required ScoreSource source,
    required int page,
    int pageSize = 30,
    String query = '',
  }) => throw UnimplementedError();
}

final class _FavoritesRepository implements FavoritesRepository {
  final items = <FavoriteItem>[];

  @override
  bool contains(ScoreKind kind, String id) => false;

  @override
  List<FavoriteItem> getAll() => List.unmodifiable(items);

  @override
  Future<List<FavoriteItem>> toggle(FavoriteItem item) async {
    items.add(item);
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
  Future<List<FavoriteItem>> toggleImageScore(ImageScoreItem score) =>
      throw UnimplementedError();

  @override
  FavoriteTarget resolve(FavoriteItem item) => throw UnimplementedError();
}

final class _AudioService implements NotePlaybackService {
  final playedRaw = <String>[];
  var stopCalls = 0;

  @override
  Future<void> play({
    required String raw,
    required String key,
    required int durationMs,
    required int program,
    required double volume,
  }) async {
    playedRaw.add(raw);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {}
}
