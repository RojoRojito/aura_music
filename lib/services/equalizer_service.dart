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
  int _nativeBandCount = 5;
  List<int> _nativeBandFrequencies = [];
  List<int> _bandMapping = []; // _bandMapping[uiBand] = nativeBand

  int get nativeBandCount => _nativeBandCount;
  List<int> get nativeBandFrequencies => _nativeBandFrequencies;

  EqualizerService(this._eqRepository);

  EqConfig? get currentConfig => _currentConfig;
  bool get isEnabled => _currentConfig?.enabled ?? false;
  int? get currentSongId => _currentSongId;

  Future<void> initSession(int sessionId) async {
    debugPrint('[EQ] initSession recibido: sessionId=$sessionId');
    try {
      await _channel.invokeMethod("initSession", {"sessionId": sessionId});
      _nativeBandCount = await _channel.invokeMethod("getBandCount") ?? 5;
      final freqsRaw = await _channel.invokeMethod("getBandFrequencies");
      if (freqsRaw is List) {
        _nativeBandFrequencies = freqsRaw.map((e) => (e as num).toInt()).toList();
      }
      _buildBandMapping();
      debugPrint('[EQ] initSession OK, nativeBandCount=$_nativeBandCount, '
          'nativeFreqs=$_nativeBandFrequencies, mapping=$_bandMapping');
      if (_currentConfig != null) {
        await _applyFullConfig(_currentConfig!);
        debugPrint('[EQ] config reaplicada');
      }
    } catch (e) {
      debugPrint('[EQ] initSession ERROR: $e');
    }
  }

  void _buildBandMapping() {
    // Map each 12-band UI frequency to closest native band
    _bandMapping = List.generate(bandCount, (uiIdx) {
      final uiFreq = bandFrequencies[uiIdx];
      var bestIdx = 0;
      var bestDiff = 999999999;
      for (var nIdx = 0; nIdx < _nativeBandFrequencies.length; nIdx++) {
        final diff = (uiFreq - _nativeBandFrequencies[nIdx]).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          bestIdx = nIdx;
        }
      }
      return bestIdx;
    });
  }

  /// Aggregate 12 UI band gains into native band gains
  List<double> _mapToNativeBands(List<double> uiGains) {
    final nativeGains = List.filled(_nativeBandCount, 0.0);
    final nativeCounts = List.filled(_nativeBandCount, 0);
    for (var i = 0; i < bandCount && i < uiGains.length; i++) {
      final nIdx = _bandMapping[i];
      nativeGains[nIdx] += uiGains[i];
      nativeCounts[nIdx]++;
    }
    for (var i = 0; i < _nativeBandCount; i++) {
      if (nativeCounts[i] > 0) nativeGains[i] /= nativeCounts[i];
    }
    return nativeGains;
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
      debugPrint('[EQ] _applyFullConfig: enabled=${config.enabled}, nativeBands=$_nativeBandCount');
      await _channel.invokeMethod("setEnabled", {"enabled": config.enabled});

      final nativeGains = _mapToNativeBands(config.bandGains);
      debugPrint('[EQ] mapped gains: ui=${config.bandGains} → native=$nativeGains');
      for (var i = 0; i < _nativeBandCount; i++) {
        await _channel.invokeMethod("setBandGain", {
          "bandIndex": i,
          "gainDb": nativeGains[i],
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

    // Recalculate the native band this UI band maps to
    if (index < _bandMapping.length) {
      final nIdx = _bandMapping[index];
      // Average all UI bands that map to this native band
      var sum = 0.0;
      var count = 0;
      for (var i = 0; i < bandCount; i++) {
        if (_bandMapping[i] == nIdx && i < newBands.length) {
          sum += newBands[i];
          count++;
        }
      }
      final nativeGain = count > 0 ? sum / count : 0.0;
      try {
        debugPrint('[EQ] setBandGain ui=$index → native=$nIdx, gain=$nativeGain');
        await _channel.invokeMethod("setBandGain", {
          "bandIndex": nIdx,
          "gainDb": nativeGain,
        });
      } catch (e) {
        debugPrint('[EQ] setBandGain ERROR: $e');
      }
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
