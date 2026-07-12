import '../../domain/models/score.dart';
import '../../domain/repositories/score_repository.dart';

/// 综合搜索的不可变页面状态。
final class SearchState {
  const SearchState({
    this.query = '',
    this.source = ScoreSource.guji,
    this.dynamicScores = const [],
    this.imageScores = const [],
    this.isLoading = false,
    this.dynamicError,
    this.imageError,
  });

  final String query;
  final ScoreSource source;
  final List<MusicSummary> dynamicScores;
  final List<ImageScoreItem> imageScores;
  final bool isLoading;
  final String? dynamicError;
  final String? imageError;

  bool get hasResults => dynamicScores.isNotEmpty || imageScores.isNotEmpty;

  SearchState copyWith({
    String? query,
    ScoreSource? source,
    List<MusicSummary>? dynamicScores,
    List<ImageScoreItem>? imageScores,
    bool? isLoading,
    String? dynamicError,
    String? imageError,
    bool clearErrors = false,
  }) => SearchState(
    query: query ?? this.query,
    source: source ?? this.source,
    dynamicScores: dynamicScores ?? this.dynamicScores,
    imageScores: imageScores ?? this.imageScores,
    isLoading: isLoading ?? this.isLoading,
    dynamicError: clearErrors ? null : dynamicError ?? this.dynamicError,
    imageError: clearErrors ? null : imageError ?? this.imageError,
  );
}
