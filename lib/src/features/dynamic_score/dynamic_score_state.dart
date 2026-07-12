import '../../domain/models/models.dart';
import 'dynamic_score_timeline.dart';

/// 动态简谱阅读器的不可变状态。
final class DynamicScoreState {
  const DynamicScoreState({
    required this.summary,
    this.content,
    this.timeline = const DynamicScoreTimeline([]),
    this.isLoading = false,
    this.errorMessage,
    this.isFavorite = false,
    this.isPlaying = false,
    this.elapsedMs = 0,
    this.activeNoteIndex = -1,
    this.zoom = 0.84,
    this.scrollSpeed = 0.16,
    this.soundEnabled = true,
    this.rewriteNotation = false,
    this.volume = 0.68,
    this.instrumentProgram = 73,
    this.selectedKey = '',
  });

  final MusicSummary summary;
  final DynamicScoreContent? content;
  final DynamicScoreTimeline timeline;
  final bool isLoading;
  final String? errorMessage;
  final bool isFavorite;
  final bool isPlaying;
  final int elapsedMs;
  final int activeNoteIndex;
  final double zoom;
  final double scrollSpeed;
  final bool soundEnabled;
  final bool rewriteNotation;
  final double volume;
  final int instrumentProgram;
  final String selectedKey;

  DynamicScoreState copyWith({
    DynamicScoreContent? content,
    DynamicScoreTimeline? timeline,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? isFavorite,
    bool? isPlaying,
    int? elapsedMs,
    int? activeNoteIndex,
    double? zoom,
    double? scrollSpeed,
    bool? soundEnabled,
    bool? rewriteNotation,
    double? volume,
    int? instrumentProgram,
    String? selectedKey,
  }) => DynamicScoreState(
    summary: summary,
    content: content ?? this.content,
    timeline: timeline ?? this.timeline,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    isFavorite: isFavorite ?? this.isFavorite,
    isPlaying: isPlaying ?? this.isPlaying,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    activeNoteIndex: activeNoteIndex ?? this.activeNoteIndex,
    zoom: zoom ?? this.zoom,
    scrollSpeed: scrollSpeed ?? this.scrollSpeed,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    rewriteNotation: rewriteNotation ?? this.rewriteNotation,
    volume: volume ?? this.volume,
    instrumentProgram: instrumentProgram ?? this.instrumentProgram,
    selectedKey: selectedKey ?? this.selectedKey,
  );
}
