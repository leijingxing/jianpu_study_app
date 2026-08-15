import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failure.dart';
import '../../app/app_dependencies.dart';
import '../../domain/repositories/score_repository.dart';
import '../../domain/models/favorite.dart';
import '../../domain/models/score.dart';
import '../../domain/repositories/favorites_repository.dart';
import 'home_state.dart';

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
  dependencies: [scoreRepositoryProvider, favoritesRepositoryProvider],
);

final class HomeViewModel extends Notifier<HomeState> {
  late ScoreRepository _repository;
  late FavoritesRepository _favoritesRepository;
  var _requestVersion = 0;

  @override
  HomeState build() {
    _repository = ref.watch(scoreRepositoryProvider);
    _favoritesRepository = ref.watch(favoritesRepositoryProvider);
    return HomeState(favorites: _favoritesRepository.getAll());
  }

  Future<void> load({bool refresh = false}) async {
    final request = ++_requestVersion;
    final page = refresh ? 1 : state.page;
    state = state.copyWith(
      page: page,
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );
    try {
      switch (state.section) {
        case HomeSection.dynamicScores:
          final result = await _repository.getDynamicScores(
            source: state.source,
            page: page,
          );
          if (request != _requestVersion) return;
          state = state.copyWith(
            dynamicScores: result.items,
            page: result.page,
            hasMore: result.hasMore,
          );
        case HomeSection.imageScores:
          final result = await _repository.getImageScores(
            source: state.source,
            page: page,
          );
          if (request != _requestVersion) return;
          state = state.copyWith(
            imageScores: result.items,
            page: result.page,
            hasMore: result.hasMore,
          );
        case HomeSection.favorites:
          state = state.copyWith(favorites: _favoritesRepository.getAll());
          break;
        case HomeSection.tools:
          break;
      }
    } catch (error) {
      if (request != _requestVersion) return;
      state = state.copyWith(errorMessage: _messageOf(error));
    } finally {
      if (request == _requestVersion) {
        state = state.copyWith(isLoading: false, isLoadingMore: false);
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    if (state.section.index > HomeSection.imageScores.index) return;
    final request = ++_requestVersion;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      if (state.section == HomeSection.dynamicScores) {
        final result = await _repository.getDynamicScores(
          source: state.source,
          page: nextPage,
        );
        if (request != _requestVersion) return;
        state = state.copyWith(
          dynamicScores: [...state.dynamicScores, ...result.items],
          page: result.page,
          hasMore: result.hasMore,
        );
      } else {
        final result = await _repository.getImageScores(
          source: state.source,
          page: nextPage,
        );
        if (request != _requestVersion) return;
        state = state.copyWith(
          imageScores: [...state.imageScores, ...result.items],
          page: result.page,
          hasMore: result.hasMore,
        );
      }
    } catch (error) {
      if (request == _requestVersion) {
        state = state.copyWith(errorMessage: _messageOf(error));
      }
    } finally {
      if (request == _requestVersion) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  Future<void> selectSection(HomeSection section) async {
    if (section == state.section) return;
    _requestVersion++;
    state = state.copyWith(
      section: section,
      page: 1,
      hasMore: true,
      clearError: true,
    );
    await load(refresh: true);
  }

  Future<void> selectSource(ScoreSource source) async {
    if (source == state.source) return;
    _requestVersion++;
    state = state.copyWith(source: source, page: 1, hasMore: true);
    await load(refresh: true);
  }

  Future<void> toggleFavorite(FavoriteItem item) async {
    try {
      final favorites = await _favoritesRepository.toggle(item);
      state = state.copyWith(favorites: favorites, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: _messageOf(error));
    }
  }

  Future<void> toggleDynamicScore(MusicSummary score) async {
    try {
      final favorites = await _favoritesRepository.toggleDynamicScore(score);
      state = state.copyWith(favorites: favorites, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: _messageOf(error));
    }
  }

  Future<void> toggleImageScore(ImageScoreItem score) async {
    try {
      final favorites = await _favoritesRepository.toggleImageScore(score);
      state = state.copyWith(favorites: favorites, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: _messageOf(error));
    }
  }

  FavoriteTarget resolveFavorite(FavoriteItem item) =>
      _favoritesRepository.resolve(item);

  void refreshFavorites() {
    state = state.copyWith(favorites: _favoritesRepository.getAll());
  }

  String _messageOf(Object error) => switch (error) {
    Failure failure => failure.message,
    _ => '加载失败，请稍后重试。',
  };
}
