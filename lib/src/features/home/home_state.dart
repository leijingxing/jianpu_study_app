import '../../domain/models/score.dart';
import '../../domain/models/favorite.dart';
import '../../domain/repositories/score_repository.dart';

enum HomeSection { dynamicScores, imageScores, favorites, tools }

final class HomeState {
  const HomeState({
    this.section = HomeSection.dynamicScores,
    this.source = ScoreSource.guji,
    this.dynamicScores = const [],
    this.imageScores = const [],
    this.favorites = const [],
    this.page = 1,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final HomeSection section;
  final ScoreSource source;
  final List<MusicSummary> dynamicScores;
  final List<ImageScoreItem> imageScores;
  final List<FavoriteItem> favorites;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  HomeState copyWith({
    HomeSection? section,
    ScoreSource? source,
    List<MusicSummary>? dynamicScores,
    List<ImageScoreItem>? imageScores,
    List<FavoriteItem>? favorites,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeState(
      section: section ?? this.section,
      source: source ?? this.source,
      dynamicScores: dynamicScores ?? this.dynamicScores,
      imageScores: imageScores ?? this.imageScores,
      favorites: favorites ?? this.favorites,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
