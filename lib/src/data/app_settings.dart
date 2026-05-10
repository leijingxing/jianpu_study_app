import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppUiStyle {
  warm('练习室'),
  fresh('清晨'),
  focus('谱架');

  const AppUiStyle(this.label);

  final String label;
}

class AppSettings extends ChangeNotifier {
  static const _uiStyleKey = 'settings_ui_style_v1';
  static const _compactListKey = 'settings_compact_list_v1';
  static const _reduceMotionKey = 'settings_reduce_motion_v1';
  static const _defaultSoundKey = 'settings_default_sound_v1';
  static const _videoMutedKey = 'settings_video_muted_v1';

  var _uiStyle = AppUiStyle.warm;
  var _compactList = false;
  var _reduceMotion = false;
  var _defaultSoundEnabled = true;
  var _videoMutedByDefault = true;

  AppUiStyle get uiStyle => _uiStyle;
  bool get compactList => _compactList;
  bool get reduceMotion => _reduceMotion;
  bool get defaultSoundEnabled => _defaultSoundEnabled;
  bool get videoMutedByDefault => _videoMutedByDefault;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _uiStyle = AppUiStyle.values.firstWhere(
      (style) => style.name == prefs.getString(_uiStyleKey),
      orElse: () => AppUiStyle.warm,
    );
    _compactList = prefs.getBool(_compactListKey) ?? false;
    _reduceMotion = prefs.getBool(_reduceMotionKey) ?? false;
    _defaultSoundEnabled = prefs.getBool(_defaultSoundKey) ?? true;
    _videoMutedByDefault = prefs.getBool(_videoMutedKey) ?? true;
    notifyListeners();
  }

  Future<void> setUiStyle(AppUiStyle value) async {
    if (_uiStyle == value) return;
    _uiStyle = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uiStyleKey, value.name);
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

  Future<void> reset() async {
    _uiStyle = AppUiStyle.warm;
    _compactList = false;
    _reduceMotion = false;
    _defaultSoundEnabled = true;
    _videoMutedByDefault = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uiStyleKey);
    await prefs.remove(_compactListKey);
    await prefs.remove(_reduceMotionKey);
    await prefs.remove(_defaultSoundKey);
    await prefs.remove(_videoMutedKey);
  }
}
