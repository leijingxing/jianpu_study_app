import '../models/models.dart';

enum ScoreSource { guji, yuepu }

/// Provides application-facing score queries independent of transport details.
abstract interface class ScoreRepository {
  Future<PageResult<MusicSummary>> getDynamicScores({
    required ScoreSource source,
    required int page,
    int pageSize = 30,
    String query = '',
  });

  Future<PageResult<ImageScoreItem>> getImageScores({
    required ScoreSource source,
    required int page,
    int pageSize = 30,
    String query = '',
  });

  Future<DynamicScoreContent> getDynamicScore(int id);

  Future<ImageScoreDetail> getImageScoreDetail(ImageScoreItem item);
}
