import 'dart:async';

import 'package:flutter_midi_pro/flutter_midi_pro.dart';

class PlatformInstrumentBackend {
  static const _soundFontAsset = 'assets/soundfonts/generaluser-gs-v2.0.3.sf2';
  static const _channel = 0;
  static const _bank = 0;
  static const _defaultProgram = 73;

  final _midi = MidiPro();
  final _noteVersions = <int, int>{};
  Future<int?>? _loading;
  var _disabled = false;
  int? _soundFontId;
  int? _selectedProgram;

  Future<bool> playMidiNote({
    required int midi,
    required int durationMs,
    required double volume,
    required int program,
  }) async {
    if (_disabled || volume <= 0) return false;
    final sfId = await _loadSoundFont();
    if (sfId == null) return false;

    final key = midi.clamp(0, 127).toInt();
    final velocity = (volume.clamp(0, 1) * 116 + 8).round().clamp(1, 127);
    final version = (_noteVersions[key] ?? 0) + 1;
    _noteVersions[key] = version;

    try {
      await _selectProgram(sfId, program);
      await _midi.stopNote(sfId: sfId, channel: _channel, key: key);
      await _midi.playNote(
        sfId: sfId,
        channel: _channel,
        key: key,
        velocity: velocity,
      );
      Timer(Duration(milliseconds: durationMs.clamp(80, 8000)), () {
        if (_noteVersions[key] == version) {
          _midi.stopNote(sfId: sfId, channel: _channel, key: key);
        }
      });
      return true;
    } catch (_) {
      _disabled = true;
      return false;
    }
  }

  Future<int?> _loadSoundFont() {
    final existing = _soundFontId;
    if (existing != null) return Future.value(existing);
    return _loading ??= _loadSoundFontInner();
  }

  Future<int?> _loadSoundFontInner() async {
    try {
      final sfId = await _midi.loadSoundfontAsset(
        assetPath: _soundFontAsset,
        bank: _bank,
        program: _defaultProgram,
      );
      await _midi.controlChange(
        sfId: sfId,
        channel: _channel,
        controller: 7,
        value: 118,
      );
      _soundFontId = sfId;
      return sfId;
    } catch (_) {
      _disabled = true;
      return null;
    }
  }

  Future<void> _selectProgram(int sfId, int program) async {
    final normalized = program.clamp(0, 127).toInt();
    if (_selectedProgram == normalized) return;
    await _midi.selectInstrument(
      sfId: sfId,
      channel: _channel,
      bank: _bank,
      program: normalized,
    );
    _selectedProgram = normalized;
  }

  Future<void> dispose() async {
    try {
      final sfId = _soundFontId;
      if (sfId != null) {
        await _midi.stopAllNotes(sfId: sfId);
        await _midi.unloadSoundfont(sfId);
      }
      await _midi.dispose();
    } catch (_) {
      // The MIDI plugin is best-effort here; disposal must not break navigation.
    }
  }
}
