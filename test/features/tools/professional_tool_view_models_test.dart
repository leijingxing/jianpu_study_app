import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/app/app_dependencies.dart';
import 'package:jianpu_study_app/src/core/audio/note_playback_service.dart';
import 'package:jianpu_study_app/src/features/metronome/metronome_view_model.dart';
import 'package:jianpu_study_app/src/features/scale_lab/scale_lab_view_model.dart';

void main() {
  test('metronome clamps bpm and emits an accented first beat', () {
    final audio = _Audio();
    final container = ProviderContainer(
      overrides: [notePlaybackServiceProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);
    final viewModel = container.read(metronomeViewModelProvider.notifier);

    viewModel.setBpm(999);
    viewModel.start();

    expect(container.read(metronomeViewModelProvider).bpm, 240);
    expect(container.read(metronomeViewModelProvider).beat, 1);
    expect(audio.raw.single, '5');
    viewModel.stop();
  });

  test('metronome supports subdivisions, mute, and stable tap tempo', () {
    final audio = _Audio();
    final container = ProviderContainer(
      overrides: [notePlaybackServiceProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);
    final viewModel = container.read(metronomeViewModelProvider.notifier);

    viewModel.setSubdivision(MetronomeSubdivision.eighth);
    viewModel.toggleMuted();
    viewModel.start();
    viewModel.registerTap(DateTime(2026, 1, 1));
    viewModel.registerTap(DateTime(2026, 1, 1, 0, 0, 0, 500));

    final state = container.read(metronomeViewModelProvider);
    expect(state.subdivision, MetronomeSubdivision.eighth);
    expect(state.isMuted, isTrue);
    expect(state.bpm, 120);
    expect(audio.raw, isEmpty);
    viewModel.stop();
  });

  test('changing bpm while running does not restart the bar', () {
    final audio = _Audio();
    final container = ProviderContainer(
      overrides: [notePlaybackServiceProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);
    final viewModel = container.read(metronomeViewModelProvider.notifier);

    viewModel.start();
    expect(container.read(metronomeViewModelProvider).beat, 1);
    viewModel.setBpm(140);

    expect(container.read(metronomeViewModelProvider).beat, 1);
    expect(audio.raw, ['5']);
    viewModel.stop();
  });

  test(
    'scale lab delegates the selected octave and key to audio service',
    () async {
      final audio = _Audio();
      final container = ProviderContainer(
        overrides: [notePlaybackServiceProvider.overrideWithValue(audio)],
      );
      addTearDown(container.dispose);
      final viewModel = container.read(scaleLabViewModelProvider.notifier);
      viewModel.setKey('D');
      viewModel.setOctave(1);

      await viewModel.play(3);

      expect(audio.raw.single, "3'");
      expect(audio.keys.single, 'D');
    },
  );
}

final class _Audio implements NotePlaybackService {
  final raw = <String>[];
  final keys = <String>[];
  @override
  Future<void> play({
    required String raw,
    required String key,
    required int durationMs,
    required int program,
    required double volume,
  }) async {
    this.raw.add(raw);
    keys.add(key);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
