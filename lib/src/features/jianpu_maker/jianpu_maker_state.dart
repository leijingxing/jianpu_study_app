import '../../domain/models/local_score.dart';

final class JianpuMakerState {
  const JianpuMakerState({
    required this.draft,
    this.savedScores = const [],
    this.currentId,
    this.isLoading = false,
    this.isSaving = false,
    this.canUndo = false,
    this.canRedo = false,
    this.message,
  });

  final JianpuMakerDraft draft;
  final List<LocalScore> savedScores;
  final String? currentId;
  final bool isLoading;
  final bool isSaving;
  final bool canUndo;
  final bool canRedo;
  final String? message;

  JianpuMakerState copyWith({
    JianpuMakerDraft? draft,
    List<LocalScore>? savedScores,
    String? currentId,
    bool clearCurrentId = false,
    bool? isLoading,
    bool? isSaving,
    bool? canUndo,
    bool? canRedo,
    String? message,
    bool clearMessage = false,
  }) => JianpuMakerState(
    draft: draft ?? this.draft,
    savedScores: savedScores ?? this.savedScores,
    currentId: clearCurrentId ? null : currentId ?? this.currentId,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
    message: clearMessage ? null : message ?? this.message,
  );
}
