import '../models/favorite.dart';
import '../models/score.dart';

/// 管理收藏快照，不暴露具体本地存储实现。
abstract interface class FavoritesRepository {
  List<FavoriteItem> getAll();

  bool contains(ScoreKind kind, String id);

  Future<List<FavoriteItem>> toggle(FavoriteItem item);

  /// 收藏或取消收藏动态谱，并保存重新打开详情所需的快照。
  Future<List<FavoriteItem>> toggleDynamicScore(MusicSummary score);

  /// 收藏或取消收藏图片谱，并保存重新打开详情所需的快照。
  Future<List<FavoriteItem>> toggleImageScore(ImageScoreItem score);

  /// 将持久化的收藏快照恢复为可导航的领域资源。
  FavoriteTarget resolve(FavoriteItem item);
}
