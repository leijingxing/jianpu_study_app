import '../models/favorite.dart';
import '../models/score.dart';

/// 管理收藏快照，不暴露具体本地存储实现。
abstract interface class FavoritesRepository {
  List<FavoriteItem> getAll();

  bool contains(ScoreKind kind, String id);

  Future<List<FavoriteItem>> toggle(FavoriteItem item);
}
