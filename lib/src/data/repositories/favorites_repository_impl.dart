import '../../core/error/failure.dart';
import '../../domain/models/favorite.dart';
import '../../domain/models/score.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../favorites_store.dart';
import '../mappers/favorite_mapper.dart';

/// 使用本地收藏服务实现应用层收藏契约。
final class FavoritesRepositoryImpl implements FavoritesRepository {
  const FavoritesRepositoryImpl(this._store);

  final FavoritesStore _store;

  @override
  bool contains(ScoreKind kind, String id) => _store.contains(kind, id);

  @override
  List<FavoriteItem> getAll() => List.unmodifiable(_store.items);

  @override
  Future<List<FavoriteItem>> toggle(FavoriteItem item) async {
    try {
      await _store.toggle(item);
      return getAll();
    } on Object catch (error) {
      throw StorageFailure('收藏保存失败。', cause: error);
    }
  }

  @override
  Future<List<FavoriteItem>> toggleDynamicScore(MusicSummary score) =>
      toggle(score.toFavoriteItem());

  @override
  Future<List<FavoriteItem>> toggleImageScore(ImageScoreItem score) =>
      toggle(score.toFavoriteItem());

  @override
  FavoriteTarget resolve(FavoriteItem item) => switch (item.kind) {
    ScoreKind.dynamic => DynamicFavoriteTarget(
      FavoriteMapper.toMusicSummary(item),
    ),
    ScoreKind.image => ImageFavoriteTarget(FavoriteMapper.toImageScore(item)),
    ScoreKind.accompaniment => AccompanimentFavoriteTarget(
      FavoriteMapper.toAccompaniment(item),
    ),
  };
}
