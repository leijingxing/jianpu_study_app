import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import '../../core/error/failure.dart';
import '../../core/media/gallery_service.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/repositories/score_repository.dart';
import 'image_score_state.dart';

final currentImageScoreProvider = Provider<ImageScoreItem>((ref) {
  throw UnimplementedError('Current image score must be provided by route.');
});

final imageScoreViewModelProvider =
    NotifierProvider<ImageScoreViewModel, ImageScoreState>(
      ImageScoreViewModel.new,
      dependencies: [
        currentImageScoreProvider,
        scoreRepositoryProvider,
        favoritesRepositoryProvider,
        galleryServiceProvider,
      ],
    );

/// 协调图片谱加载、收藏和相册保存。
final class ImageScoreViewModel extends Notifier<ImageScoreState> {
  late ScoreRepository _scores;
  late FavoritesRepository _favorites;
  late GalleryService _gallery;
  var _requestVersion = 0;

  @override
  ImageScoreState build() {
    final item = ref.watch(currentImageScoreProvider);
    _scores = ref.watch(scoreRepositoryProvider);
    _favorites = ref.watch(favoritesRepositoryProvider);
    _gallery = ref.watch(galleryServiceProvider);
    return ImageScoreState(
      item: item,
      isFavorite: _favorites.contains(ScoreKind.image, item.id),
    );
  }

  Future<void> load() async {
    final request = ++_requestVersion;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final detail = await _scores.getImageScoreDetail(state.item);
      if (request == _requestVersion) state = state.copyWith(detail: detail);
    } catch (error) {
      if (request == _requestVersion) {
        state = state.copyWith(errorMessage: _messageOf(error));
      }
    } finally {
      if (request == _requestVersion) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> toggleFavorite() async {
    try {
      final items = await _favorites.toggleImageScore(state.item);
      state = state.copyWith(
        isFavorite: items.any(
          (item) => item.kind == ScoreKind.image && item.id == state.item.id,
        ),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _messageOf(error));
    }
  }

  Future<void> saveImages() async {
    final urls = state.detail?.imageUrls ?? const [];
    if (urls.isEmpty || state.isSaving) return;
    state = state.copyWith(isSaving: true, clearStatus: true);
    try {
      final result = await _gallery.saveNetworkImages(
        urls: urls,
        namePrefix: state.item.title,
      );
      state = state.copyWith(
        statusMessage: result.failed == 0
            ? '已保存 ${result.saved} 张图片'
            : '已保存 ${result.saved} 张，${result.failed} 张失败',
      );
    } catch (error) {
      state = state.copyWith(statusMessage: _messageOf(error));
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  void clearStatus() => state = state.copyWith(clearStatus: true);

  String _messageOf(Object error) => switch (error) {
    Failure failure => failure.message,
    _ => '操作失败，请稍后重试。',
  };
}
