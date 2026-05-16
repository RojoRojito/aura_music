import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/models/eq_config.dart';
import '../data/repositories/eq_repository.dart';
import 'audio_handler.dart';

class EqualizerService extends ChangeNotifier {
  final EqRepository _eqRepository;
  late final AndroidEqualizer _equalizer;
  late final AndroidBassBoost _bassBoost;
  late final AndroidVirtualizer _virtualizer;

  EqConfig? _currentConfig;
  int? _currentSongId;

  EqualizerService(this._eqRepository);

  void attachEffects(AuraAudioHandler handler) {
    _equalizer = handler.androidEqualizer;
    _bassBoost = handler.androidBassBoost;
    _virtualizer = handler.androidVirtualizer;
  }

  Future<void> loadForSong(int songId) async {
    _currentSongId = songId;
    final config = await _eqRepository.loadForSong(songId);
    _currentConfig = config ?? EqConfig.flat(songId: songId);
    await _applyFullConfig(_currentConfig!);
    notifyListeners();
  }

  Future<void> _applyFullConfig(EqConfig config) async {
    try {
      await _equalizer.setEnabled(config.enabled);
      await _bassBoost.setEnabled(config.enabled);
      await _virtualizer.setEnabled(config.enabled);

      final params = await _equalizer.parameters;
      final bands = params.bands;
      for (int i = 0; i < bands.length && i < config.bandGains.length; i++) {
        await bands[i].setGain(config.bandGains[i]);
      }

      if (config.bassBoost > 0) {
        await _bassBoost.setStrength(
          (config.bassBoost / 15.0 * 1000).round().clamp(0, 1000));
      }

      if (config.virtualizer > 0) {
        await _virtualizer.setStrength(
          (config.virtualizer * 1000).round().clamp(0, 1000));
      }
    } catch (e) {
      debugPrint('[EQ] applyFullConfig error: $e');
    }
  }

  Future<void> setBandGain(int index, double gainDb) async {
    if (_currentConfig == null) {
      if (_currentSongId == null) return;
      _currentConfig = EqConfig.flat(songId: _currentSongId!);
    }
    final clampedGain = gainDb.clamp(-12.0, 12.0);
    final newBands = List<double>.from(_currentConfig!.bandGains);
    if (index < newBands.length) newBands[index] = clampedGain;

    _currentConfig = _currentConfig!.copyWith(bandGains: newBands, presetName: null);

    try {
      final params = await _equalizer.parameters;
      if (index < params.bands.length) {
        await params.bands[index].setGain(clampedGain);
      }
    } catch (e) {
      debugPrint('[EQ] setBandGain error: $e');
    }

    if (_currentSongId != null) {
      await _eqRepository.saveForSong(_currentConfig!);
    }
    notifyListeners();
  }

  Future<void> setBassBoost(double value) async {
    if (_currentConfig == null) {
      if (_currentSongId == null) return;
      _currentConfig = EqConfig.flat(songId: _currentSongId!);
    }
    final clampedValue = value.clamp(0.0, 15.0);
    _currentConfig = _currentConfig!.copyWith(bassBoost: clampedValue);

    try {
      await _bassBoost.setStrength(
        (clampedValue / 15.0 * 1000).round().clamp(0, 1000));
    } catch (e) {
      debugPrint('[EQ] setBassBoost error: $e');
    }

    if (_currentSongId != null) {
      await _eqRepository.saveForSong(_currentConfig!);
    }
    notifyListeners();
  }

  Future<void> setVirtualizer(double value) async {
    if (_currentConfig == null) {
      if (_currentSongId == null) return;
      _currentConfig = EqConfig.flat(songId: _currentSongId!);
    }
    final clampedValue = value.clamp(0.0, 1.0);
    _currentConfig = _currentConfig!.copyWith(virtualizer: clampedValue);

    try {
      await _virtualizer.setStrength(
        (clampedValue * 1000).round().clamp(0, 1000));
    } catch (e) {
      debugPrint('[EQ] setVirtualizer error: $e');
    }

    if (_currentSongId != null) {
      await _eqRepository.saveForSong(_currentConfig!);
    }
    notifyListeners();
  }

  Future<void> toggleEnabled() async {
    if (_currentSongId == null) return;
    _currentConfig ??= EqConfig.flat(songId: _currentSongId!);
    final newEnabled = !_currentConfig!.enabled;
    _currentConfig = _currentConfig!.copyWith(enabled: newEnabled);

    try {
      await _equalizer.setEnabled(newEnabled);
      await _bassBoost.setEnabled(newEnabled);
      await _virtualizer.setEnabled(newEnabled);
    } catch (e) {
      debugPrint('[EQ] toggleEnabled error: $e');
    }

    if (_currentSongId != null) {
      await _eqRepository.saveForSong(_currentConfig!);
    }
    notifyListeners();
  }

  Future<void> applyPreset(String name) async {
    if (_currentSongId == null) return;
    final gains = EqConfig.presets[name];
    if (gains == null) return;

    _currentConfig = (_currentConfig ?? EqConfig.flat(songId: _currentSongId!))
        .copyWith(bandGains: gains, presetName: name);

    await _applyFullConfig(_currentConfig!);
    await _eqRepository.saveForSong(_currentConfig!);
    notifyListeners();
  }

  Future<void> resetSong() async {
    if (_currentSongId == null) return;
    _currentConfig = EqConfig.flat(songId: _currentSongId!);
    await _applyFullConfig(_currentConfig!);
    await _eqRepository.deleteForSong(_currentSongId!);
    notifyListeners();
  }

  Future<int> getBandCount() async {
    try {
      final params = await _equalizer.parameters;
      return params.bands.length;
    } catch (_) {
      return 10;
    }
  }

  EqConfig? get currentConfig => _currentConfig;
  bool get isEnabled => _currentConfig?.enabled ?? false;
}
