import '../../core/error/failure.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/score_repository.dart';
import '../jianpu_api.dart';

/// Coordinates score services and converts infrastructure errors at the boundary.
final class ScoreRepositoryImpl implements ScoreRepository {
  const ScoreRepositoryImpl(this._api);

  final JianpuApi _api;

  @override
  Future<PageResult<MusicSummary>> getDynamicScores({
    required ScoreSource source,
    required int page,
    int pageSize = 30,
    String query = '',
  }) async {
    try {
      final items = switch (source) {
        ScoreSource.guji when query.trim().isNotEmpty =>
          await _api.searchDynamic(query),
        ScoreSource.guji => await _api.fetchDynamicList(
          page: page,
          limit: pageSize,
        ),
        ScoreSource.yuepu => await _api.fetchYuepuDynamicList(
          page: page,
          limit: pageSize,
          query: query,
        ),
      };
      return PageResult(items: items, page: page, hasMore: items.isNotEmpty);
    } on Failure {
      rethrow;
    } catch (error) {
      throw UnexpectedFailure('动态谱加载失败。', cause: error);
    }
  }

  @override
  Future<PageResult<ImageScoreItem>> getImageScores({
    required ScoreSource source,
    required int page,
    int pageSize = 30,
    String query = '',
  }) async {
    try {
      final items = switch (source) {
        ScoreSource.guji when query.trim().isNotEmpty =>
          await _api.searchImages(query),
        ScoreSource.guji => await _api.fetchImageList(page: page),
        ScoreSource.yuepu => await _api.fetchYuepuSheetList(
          page: page,
          limit: pageSize,
          query: query,
        ),
      };
      return PageResult(items: items, page: page, hasMore: items.isNotEmpty);
    } on Failure {
      rethrow;
    } catch (error) {
      throw UnexpectedFailure('图片谱加载失败。', cause: error);
    }
  }

  @override
  Future<DynamicScoreContent> getDynamicScore(int id) async {
    try {
      final detail = await _api.fetchDynamicDetail(id);
      final raw = await _api.fetchScoreText(detail.scorePath);
      return DynamicScoreContent(
        detail: detail,
        document: ScoreDocument.parse(raw),
      );
    } on Failure {
      rethrow;
    } catch (error) {
      throw UnexpectedFailure('动态谱详情加载失败。', cause: error);
    }
  }

  @override
  Future<ImageScoreDetail> getImageScoreDetail(ImageScoreItem item) async {
    try {
      return await _api.fetchImageDetail(item);
    } on Failure {
      rethrow;
    } catch (error) {
      throw UnexpectedFailure('图片谱详情加载失败。', cause: error);
    }
  }
}
