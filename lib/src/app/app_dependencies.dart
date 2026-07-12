import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/note_playback_service.dart';
import '../core/media/gallery_service.dart';
import '../audio/analyzer/instrument_audio_input.dart';
import '../data/app_settings.dart';
import '../data/favorites_store.dart';
import '../data/jianpu_api.dart';
import '../data/repositories/score_repository_impl.dart';
import '../data/repositories/favorites_repository_impl.dart';
import '../data/repositories/local_score_repository_impl.dart';
import '../data/services/platform/tone_note_playback_service.dart';
import '../data/services/platform/gallery_service_impl.dart';
import '../data/services/local/local_score_service.dart';
import '../domain/repositories/favorites_repository.dart';
import '../domain/repositories/local_score_repository.dart';
import '../domain/repositories/score_repository.dart';

/// Owns application-scoped dependencies and releases their resources together.
final class AppDependencies {
  AppDependencies({
    AppSettings? settings,
    FavoritesStore? favorites,
    JianpuApi? api,
    ScoreRepository? scoreRepository,
    FavoritesRepository? favoritesRepository,
    NotePlaybackService? notePlaybackService,
    GalleryService? galleryService,
    InstrumentAudioInput? instrumentAudioInput,
  }) : settings = settings ?? AppSettings(),
       favorites = favorites ?? FavoritesStore(),
       api = api ?? JianpuApi() {
    this.scoreRepository = scoreRepository ?? ScoreRepositoryImpl(this.api);
    this.favoritesRepository =
        favoritesRepository ?? FavoritesRepositoryImpl(this.favorites);
    this.notePlaybackService = notePlaybackService ?? ToneNotePlaybackService();
    this.galleryService = galleryService ?? const GalleryServiceImpl();
    localScoreRepository = LocalScoreRepositoryImpl(const LocalScoreService());
    this.instrumentAudioInput =
        instrumentAudioInput ?? createInstrumentAudioInput();
  }

  final AppSettings settings;
  final FavoritesStore favorites;
  final JianpuApi api;
  late final ScoreRepository scoreRepository;
  late final FavoritesRepository favoritesRepository;
  late final NotePlaybackService notePlaybackService;
  late final GalleryService galleryService;
  late final LocalScoreRepository localScoreRepository;
  late final InstrumentAudioInput instrumentAudioInput;

  Future<void> initialize() async {
    await Future.wait([settings.load(), favorites.load()]);
  }

  void dispose() {
    settings.dispose();
    favorites.dispose();
    api.dispose();
    unawaited(notePlaybackService.dispose());
    unawaited(instrumentAudioInput.dispose());
  }
}

final appDependenciesProvider = Provider<AppDependencies>((ref) {
  throw UnimplementedError('AppDependencies must be overridden at bootstrap.');
});

final appSettingsProvider = Provider<AppSettings>(
  (ref) => ref.watch(appDependenciesProvider).settings,
);

final favoritesProvider = Provider<FavoritesStore>(
  (ref) => ref.watch(appDependenciesProvider).favorites,
);

final jianpuApiProvider = Provider<JianpuApi>(
  (ref) => ref.watch(appDependenciesProvider).api,
);

final scoreRepositoryProvider = Provider<ScoreRepository>(
  (ref) => ref.watch(appDependenciesProvider).scoreRepository,
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => ref.watch(appDependenciesProvider).favoritesRepository,
);

final notePlaybackServiceProvider = Provider<NotePlaybackService>(
  (ref) => ref.watch(appDependenciesProvider).notePlaybackService,
);

final galleryServiceProvider = Provider<GalleryService>(
  (ref) => ref.watch(appDependenciesProvider).galleryService,
);

final localScoreRepositoryProvider = Provider<LocalScoreRepository>(
  (ref) => ref.watch(appDependenciesProvider).localScoreRepository,
);

final instrumentAudioInputProvider = Provider<InstrumentAudioInput>(
  (ref) => ref.watch(appDependenciesProvider).instrumentAudioInput,
);
