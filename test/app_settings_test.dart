import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/audio/tone_synth.dart';
import 'package:jianpu_study_app/src/data/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads legacy setting keys and preserves their values', () async {
    SharedPreferences.setMockInitialValues({
      'settings_ui_style_v1': 'focus',
      'settings_theme_mode_v1': 'dark',
      'settings_compact_list_v1': true,
      'settings_reduce_motion_v1': true,
      'settings_default_sound_v1': false,
      'settings_video_muted_v1': false,
      'settings_melody_instrument_v1': 40,
    });
    final settings = AppSettings();

    await settings.load();

    expect(settings.uiStyle, AppUiStyle.focus);
    expect(settings.themeMode, AppThemeMode.dark);
    expect(settings.compactList, isTrue);
    expect(settings.reduceMotion, isTrue);
    expect(settings.defaultSoundEnabled, isFalse);
    expect(settings.videoMutedByDefault, isFalse);
    final validPrograms = melodyInstruments.map((item) => item.program);
    expect(validPrograms, contains(settings.melodyInstrumentProgram));
  });

  test('invalid persisted enum and instrument values use defaults', () async {
    SharedPreferences.setMockInitialValues({
      'settings_ui_style_v1': 'removed-style',
      'settings_theme_mode_v1': 'removed-mode',
      'settings_melody_instrument_v1': 9999,
    });
    final settings = AppSettings();

    await settings.load();

    expect(settings.uiStyle, AppUiStyle.warm);
    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.melodyInstrumentProgram, MelodyInstrument.defaultProgram);
  });
}
