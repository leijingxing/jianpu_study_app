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
