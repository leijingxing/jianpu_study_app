import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/tone_synth.dart';

enum AppUiStyle {
  warm('练习室'),
  fresh('清晨'),
  focus('谱架');

  const AppUiStyle(this.label);

  final String label;
}

enum AppThemeMode {
  system('跟随系统'),
  light('亮色'),
  dark('暗色');

  const AppThemeMode(this.label);

  final String label;
}

class AppSettings extends ChangeNotifier {
  static const _uiStyleKey = 'settings_ui_style_v1';
  static const _themeModeKey = 'settings_theme_mode_v1';
  static const _compactListKey = 'settings_compact_list_v1';
  static const _reduceMotionKey = 'settings_reduce_motion_v1';
  static const _defaultSoundKey = 'settings_default_sound_v1';
  static const _videoMutedKey = 'settings_video_muted_v1';
  static const _melodyInstrumentKey = 'settings_melody_instrument_v1';

  var _uiStyle = AppUiStyle.warm;
  var _themeMode = AppThemeMode.system;
  var _compactList = false;
  var _reduceMotion = false;
  var _defaultSoundEnabled = true;
  var _videoMutedByDefault = true;
  var _melodyInstrumentProgram = MelodyInstrument.defaultProgram;

  AppUiStyle get uiStyle => _uiStyle;
  AppThemeMode get themeMode => _themeMode;
  bool get compactList => _compactList;
  bool get reduceMotion => _reduceMotion;
  bool get defaultSoundEnabled => _defaultSoundEnabled;
  bool get videoMutedByDefault => _videoMutedByDefault;
  int get melodyInstrumentProgram => _melodyInstrumentProgram;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _uiStyle = AppUiStyle.values.firstWhere(
      (style) => style.name == prefs.getString(_uiStyleKey),
      orElse: () => AppUiStyle.warm,
    );
    _themeMode = AppThemeMode.values.firstWhere(
      (mode) => mode.name == prefs.getString(_themeModeKey),
      orElse: () => AppThemeMode.system,
    );
    _compactList = prefs.getBool(_compactListKey) ?? false;
    _reduceMotion = prefs.getBool(_reduceMotionKey) ?? false;
    _defaultSoundEnabled = prefs.getBool(_defaultSoundKey) ?? true;
    _videoMutedByDefault = prefs.getBool(_videoMutedKey) ?? true;
    _melodyInstrumentProgram = _validInstrumentProgram(
      prefs.getInt(_melodyInstrumentKey),
    );
    notifyListeners();
  }

  Future<void> setUiStyle(AppUiStyle value) async {
    if (_uiStyle == value) return;
    _uiStyle = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uiStyleKey, value.name);
  }

  Future<void> setThemeMode(AppThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value.name);
  }

  Future<void> setCompactList(bool value) async {
    if (_compactList == value) return;
    _compactList = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_compactListKey, value);
  }

  Future<void> setReduceMotion(bool value) async {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reduceMotionKey, value);
  }

  Future<void> setDefaultSoundEnabled(bool value) async {
    if (_defaultSoundEnabled == value) return;
    _defaultSoundEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_defaultSoundKey, value);
  }

  Future<void> setVideoMutedByDefault(bool value) async {
    if (_videoMutedByDefault == value) return;
    _videoMutedByDefault = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_videoMutedKey, value);
  }

  Future<void> setMelodyInstrumentProgram(int value) async {
    final program = _validInstrumentProgram(value);
    if (_melodyInstrumentProgram == program) return;
    _melodyInstrumentProgram = program;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_melodyInstrumentKey, program);
  }

  Future<void> reset() async {
    _uiStyle = AppUiStyle.warm;
    _themeMode = AppThemeMode.system;
    _compactList = false;
    _reduceMotion = false;
    _defaultSoundEnabled = true;
    _videoMutedByDefault = true;
    _melodyInstrumentProgram = MelodyInstrument.defaultProgram;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uiStyleKey);
    await prefs.remove(_themeModeKey);
    await prefs.remove(_compactListKey);
    await prefs.remove(_reduceMotionKey);
    await prefs.remove(_defaultSoundKey);
    await prefs.remove(_videoMutedKey);
    await prefs.remove(_melodyInstrumentKey);
  }

  int _validInstrumentProgram(int? value) {
    if (value == null) return MelodyInstrument.defaultProgram;
    return melodyInstruments.any((instrument) => instrument.program == value)
        ? value
        : MelodyInstrument.defaultProgram;
  }
}
