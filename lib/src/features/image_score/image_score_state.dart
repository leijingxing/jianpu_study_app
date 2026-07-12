import '../../domain/models/models.dart';

/// 图片谱详情的不可变页面状态。
final class ImageScoreState {
  const ImageScoreState({
    required this.item,
    this.detail,
    this.isLoading = false,
    this.isSaving = false,
    this.isFavorite = false,
    this.errorMessage,
    this.statusMessage,
  });

  final ImageScoreItem item;
  final ImageScoreDetail? detail;
  final bool isLoading;
  final bool isSaving;
  final bool isFavorite;
  final String? errorMessage;
  final String? statusMessage;

  ImageScoreState copyWith({
    ImageScoreDetail? detail,
    bool? isLoading,
    bool? isSaving,
    bool? isFavorite,
    String? errorMessage,
    String? statusMessage,
    bool clearError = false,
    bool clearStatus = false,
  }) => ImageScoreState(
    item: item,
    detail: detail ?? this.detail,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    isFavorite: isFavorite ?? this.isFavorite,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    statusMessage: clearStatus ? null : statusMessage ?? this.statusMessage,
  );
}
