import 'score.dart';

/// 用户收藏的轻量快照。
final class FavoriteItem {
  const FavoriteItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    this.scorePath = '',
    this.imageUrl = '',
  });

  final ScoreKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String scorePath;
  final String imageUrl;

  String get key => '${kind.name}:$id';
}

/// 从收藏快照恢复出的可导航资源。
sealed class FavoriteTarget {
  const FavoriteTarget();
}

final class DynamicFavoriteTarget extends FavoriteTarget {
  const DynamicFavoriteTarget(this.score);

  final MusicSummary score;
}

final class ImageFavoriteTarget extends FavoriteTarget {
  const ImageFavoriteTarget(this.score);

  final ImageScoreItem score;
}

final class AccompanimentFavoriteTarget extends FavoriteTarget {
  const AccompanimentFavoriteTarget(this.accompaniment);

  final AccompanimentItem accompaniment;
}
