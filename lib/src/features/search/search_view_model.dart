import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import '../../core/error/failure.dart';
import '../../domain/models/score.dart';
import '../../domain/repositories/score_repository.dart';
import 'search_state.dart';

final searchViewModelProvider = NotifierProvider<SearchViewModel, SearchState>(
  SearchViewModel.new,
  dependencies: [scoreRepositoryProvider],
);

/// 处理搜索防抖、并发结果与过期请求。
final class SearchViewModel extends Notifier<SearchState> {
  late ScoreRepository _repository;
  Timer? _debounce;
  var _requestVersion = 0;

  @override
  SearchState build() {
    _repository = ref.watch(scoreRepositoryProvider);
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void queryChanged(String value) {
    _debounce?.cancel();
    state = state.copyWith(query: value, clearErrors: true);
    final normalized = value.trim();
    if (normalized.isEmpty) {
      _requestVersion++;
      state = state.copyWith(
        dynamicScores: const [],
        imageScores: const [],
        isLoading: false,
      );
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), searchNow);
  }

  Future<void> selectSource(ScoreSource source) async {
    if (source == state.source) return;
    state = state.copyWith(source: source, clearErrors: true);
    if (state.query.trim().isNotEmpty) await searchNow();
  }

  Future<void> searchNow() async {
    _debounce?.cancel();
    final query = state.query.trim();
    if (query.isEmpty) return;
    final request = ++_requestVersion;
    state = state.copyWith(isLoading: true, clearErrors: true);

    final dynamicFuture = _loadDynamic(query);
    final imageFuture = _loadImages(query);
    final results = await Future.wait([dynamicFuture, imageFuture]);
    if (request != _requestVersion) return;
    final dynamicResult = results[0] as _SearchResult<MusicSummary>;
    final imageResult = results[1] as _SearchResult<ImageScoreItem>;
    state = state.copyWith(
      dynamicScores: dynamicResult.items,
      imageScores: imageResult.items,
      dynamicError: dynamicResult.error,
      imageError: imageResult.error,
      isLoading: false,
    );
  }

  Future<_SearchResult<MusicSummary>> _loadDynamic(String query) async {
    try {
      final result = await _repository.getDynamicScores(
        source: state.source,
        page: 1,
        query: query,
      );
      return _SearchResult(result.items);
    } catch (error) {
      return _SearchResult(const [], _messageOf(error));
    }
  }

  Future<_SearchResult<ImageScoreItem>> _loadImages(String query) async {
    try {
      final result = await _repository.getImageScores(
        source: state.source,
        page: 1,
        query: query,
      );
      return _SearchResult(result.items);
    } catch (error) {
      return _SearchResult(const [], _messageOf(error));
    }
  }

  String _messageOf(Object error) => switch (error) {
    Failure failure => failure.message,
    _ => '搜索失败，请稍后重试。',
  };
}

final class _SearchResult<T> {
  const _SearchResult(this.items, [this.error]);

  final List<T> items;
  final String? error;
}
