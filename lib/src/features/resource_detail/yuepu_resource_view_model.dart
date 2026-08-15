import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/favorites_repository.dart';

final currentYuepuScoreProvider = Provider<MusicSummary>((ref) {
  throw UnimplementedError('Current Yuepu score must be provided by route.');
});

final yuepuResourceViewModelProvider =
    NotifierProvider<YuepuResourceViewModel, bool>(
      YuepuResourceViewModel.new,
      dependencies: [currentYuepuScoreProvider, favoritesRepositoryProvider],
    );

/// 管理悦谱动态资源的收藏命令。
final class YuepuResourceViewModel extends Notifier<bool> {
  late MusicSummary _score;
  late FavoritesRepository _favorites;

  @override
  bool build() {
    _score = ref.watch(currentYuepuScoreProvider);
    _favorites = ref.watch(favoritesRepositoryProvider);
    return _favorites.contains(ScoreKind.dynamic, _score.favoriteId);
  }

  Future<void> toggleFavorite() async {
    final values = await _favorites.toggleDynamicScore(_score);
    state = values.any(
      (value) =>
          value.kind == ScoreKind.dynamic && value.id == _score.favoriteId,
    );
  }
}
