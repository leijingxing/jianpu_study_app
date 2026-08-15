import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/app/app_dependencies.dart';
import 'package:jianpu_study_app/src/core/audio/note_playback_service.dart';
import 'package:jianpu_study_app/src/features/metronome/metronome_screen.dart';
import 'package:jianpu_study_app/src/theme/app_theme.dart';

void main() {
  testWidgets('metronome controls remain usable on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePlaybackServiceProvider.overrideWithValue(_SilentAudio()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const MetronomeScreen(),
        ),
      ),
    );

    expect(find.text('专业节拍器'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('拍号'), findsOneWidget);
    expect(find.text('节拍细分'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('开始练习'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('点击测速'), findsOneWidget);
    expect(find.text('开始练习'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _SilentAudio implements NotePlaybackService {
  @override
  Future<void> play({
    required String raw,
    required String key,
    required int durationMs,
    required int program,
    required double volume,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
