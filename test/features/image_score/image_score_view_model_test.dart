import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/app/app_dependencies.dart';
import 'package:jianpu_study_app/src/core/media/gallery_service.dart';
import 'package:jianpu_study_app/src/domain/models/models.dart';
import 'package:jianpu_study_app/src/domain/repositories/favorites_repository.dart';
import 'package:jianpu_study_app/src/domain/repositories/score_repository.dart';
import 'package:jianpu_study_app/src/features/image_score/image_score_view_model.dart';

void main() {
  test('loads media through repository', () async {
    final dependencies = _Dependencies();
    final container = dependencies.container();
    addTearDown(container.dispose);

    await container.read(imageScoreViewModelProvider.notifier).load();

    final state = container.read(imageScoreViewModelProvider);
    expect(state.detail?.imageUrls, ['https://example.com/score.png']);
    expect(state.detail?.videoUrls, ['https://example.com/demo.mp4']);
    expect(state.isLoading, isFalse);
  });

  test('saving images publishes a user-facing result', () async {
    final dependencies = _Dependencies();
    final container = dependencies.container();
    addTearDown(container.dispose);
    final viewModel = container.read(imageScoreViewModelProvider.notifier);
    await viewModel.load();

    await viewModel.saveImages();

    expect(dependencies.gallery.savedUrls, hasLength(1));
    expect(
      container.read(imageScoreViewModelProvider).statusMessage,
      '已保存 1 张图片',
    );
  });
}

const _item = ImageScoreItem(
  id: '1',
  title: '图片谱',
  summary: '',
  pic: '',
  views: 0,
  hasVideo: true,
  date: '',
);

final class _Dependencies {
  final repository = _ScoreRepository();
  final favorites = _FavoritesRepository();
  final gallery = _GalleryService();

  ProviderContainer container() => ProviderContainer(
    overrides: [
      currentImageScoreProvider.overrideWithValue(_item),
      scoreRepositoryProvider.overrideWithValue(repository),
      favoritesRepositoryProvider.overrideWithValue(favorites),
      galleryServiceProvider.overrideWithValue(gallery),
    ],
  );
}

final class _ScoreRepository implements ScoreRepository {
  @override
  Future<ImageScoreDetail> getImageScoreDetail(ImageScoreItem item) async =>
      const ImageScoreDetail(
        item: _item,
        imageUrls: ['https://example.com/score.png'],
        videoUrls: ['https://example.com/demo.mp4'],
      );

  @override
  Future<DynamicScoreContent> getDynamicScore(int id) =>
      throw UnimplementedError();

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
  @override
  bool contains(ScoreKind kind, String id) => false;

  @override
  List<FavoriteItem> getAll() => const [];

  @override
  Future<List<FavoriteItem>> toggle(FavoriteItem item) async => [item];
}

final class _GalleryService implements GalleryService {
  var savedUrls = <String>[];

  @override
  Future<GallerySaveResult> saveNetworkImages({
    required List<String> urls,
    required String namePrefix,
  }) async {
    savedUrls = urls;
    return GallerySaveResult(saved: urls.length, failed: 0);
  }
}
