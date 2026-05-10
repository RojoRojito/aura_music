import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/models/eq_config.dart';
import '../data/repositories/eq_repository.dart';

class EqualizerService extends ChangeNotifier {
  final EqRepository _eqRepository;
  static const _channel = MethodChannel("com.daviddev.aura/equalizer");

  static const List<int> bandFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 12000, 16000, 20000
  ];
  static const int bandCount = 12;

  EqConfig? _currentConfig;
  int? _currentSongId;

  EqualizerService(this._eqRepository);

  EqConfig? get currentConfig => _currentConfig;
  bool get isEnabled => _currentConfig?.enabled ?? false;
  int? get currentSongId => _currentSongId;

  Future<void> initSession(int sessionId) async {
    debugPrint('[EQ] initSession($sessionId)');
    try {
      await _channel.invokeMethod("initSession", {"sessionId": sessionId});
      if (_currentConfig != null) {
        await _applyFullConfig(_currentConfig!);
      }
    } catch (e) {
      debugPrint('[EQ] initSession ERROR: $e');
    }
  }

  Future<void> loadForSong(int songId) async {
    debugPrint('[EQ] loadForSong($songId)');
    _currentSongId = songId;
    final config = await _eqRepository.loadForSong(songId);
    _currentConfig = config ?? EqConfig.flat(songId: songId);
    debugPrint('[EQ] Config loaded: enabled=${_currentConfig!.enabled}, preset=${_currentConfig!.presetName}');
    await _applyFullConfig(_currentConfig!);
    notifyListeners();
  }

  Future<void> _applyFullConfig(EqConfig config) async {
    try {
      debugPrint('[EQ] _applyFullConfig: enabled=${config.enabled}');
      await _channel.invokeMethod("setEnabled", {"enabled": config.enabled});
      for (var i = 0; i < bandCount; i++) {
        await _channel.invokeMethod("setBandGain", {
          "bandIndex": i,
          "gainDb": config.bandGains[i],
        });
      }
      await _channel.invokeMethod("setBassBoost", {"gainDb": config.bassBoost});
      await _channel.invokeMethod("setVirtualizer", {"strength": config.virtualizer});
      debugPrint('[EQ] Full config applied successfully');
    } catch (e) {
      debugPrint('[EQ] _applyFullConfig ERROR: $e');
    }
  }

  Future<void> setBandGain(int index, double gainDb) async {
    if (_currentConfig == null) {
      if (_currentSongId == null) return;
      _currentConfig = EqConfig.flat(songId: _currentSongId!);
    }
    final clampedGain = gainDb.clamp(-12.0, 12.0);
    final newBands = List<double>.from(_currentConfig!.bandGains);
    if (index < bandCount) newBands[index] = clampedGain;

    _currentConfig = _currentConfig!.copyWith(bandGains: newBands, presetName: null);

    try {
      debugPrint('[EQ] setBandGain($index, $clampedGain)');
      await _channel.invokeMethod("setBandGain", {
        "bandIndex": index,
        "gainDb": clampedGain,
      });
    } catch (e) {
      debugPrint('[EQ] setBandGain ERROR: $e');
    }

    if (_currentSongId != null) {
      await _eqRepository.saveForSong(_currentConfig!);
    }
    notifyListeners();
  }

  Future<void> setBassBoost(double gainDb) async {
    if (_currentConfig == null) {
      if (_currentSongId == null) return;
      _currentConfig = EqConfig.flat(songId: _currentSongId!);
    }
    final clampedGain = gainDb.clamp(0.0, 15.0);
    _currentConfig = _currentConfig!.copyWith(bassBoost: clampedGain);

    try {
      debugPrint('[EQ] setBassBoost($clampedGain)');
      await _channel.invokeMethod("setBassBoost", {"gainDb": clampedGain});
    } catch (e) {
      debugPrint('[EQ] setBassBoost ERROR: $e');
    }

    if (_currentSongId != null) {
      await _eqRepository.saveForSong(_currentConfig!);
    }
    notifyListeners();
  }

  Future<void> setVirtualizer(double strength) async {
    if (_currentConfig == null) {
      if (_currentSongId == null) return;
      _currentConfig = EqConfig.flat(songId: _currentSongId!);
    }
    final clampedStrength = strength.clamp(0.0, 1.0);
    _currentConfig = _currentConfig!.copyWith(virtualizer: clampedStrength);

    try {
      debugPrint('[EQ] setVirtualizer($clampedStrength)');
      await _channel.invokeMethod("setVirtualizer", {"strength": clampedStrength});
    } catch (e) {
      debugPrint('[EQ] setVirtualizer ERROR: $e');
    }

    if (_currentSongId != null) {
      await _eqRepository.saveForSong(_currentConfig!);
    }
    notifyListeners();
  }

  Future<void> toggleEnabled() async {
    debugPrint('[EQ] toggleEnabled called, currentConfig=${_currentConfig?.enabled}, songId=$_currentSongId');
    if (_currentConfig == null) {
      if (_currentSongId == null) {
        debugPrint('[EQ] toggleEnabled: no songId, returning');
        return;
      }
      _currentConfig = EqConfig.flat(songId: _currentSongId!);
    }
    final newEnabled = !_currentConfig!.enabled;
    _currentConfig = _currentConfig!.copyWith(enabled: newEnabled);
    debugPrint('[EQ] newEnabled = $newEnabled, calling _applyFullConfig');

    await _applyFullConfig(_currentConfig!);

    if (_currentSongId != null) {
      await _eqRepository.saveForSong(_currentConfig!);
    }
    notifyListeners();
  }

  Future<void> applyPreset(String name) async {
    if (_currentConfig == null) return;
    final preset = EqConfig.presets[name];
    if (preset == null) return;

    _currentConfig = _currentConfig!.copyWith(
      bandGains: List<double>.from(preset),
      bassBoost: 0.0,
      presetName: name,
    );

    await _applyFullConfig(_currentConfig!);

    if (_currentSongId != null) {
      await _eqRepository.saveForSong(_currentConfig!);
    }
    notifyListeners();
  }

  Future<void> resetSong() async {
    if (_currentSongId == null) return;
    _currentConfig = EqConfig.flat(songId: _currentSongId!);

    await _applyFullConfig(_currentConfig!);
    await _eqRepository.deleteForSong(_currentSongId!);
    notifyListeners();
  }
}