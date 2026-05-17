import 'dart:math';
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
  int _nativeBandCount = 5;
  List<int> _nativeBandFrequencies = [];
  bool _isAvailable = false;

  int get nativeBandCount => _nativeBandCount;
  List<int> get nativeBandFrequencies => _nativeBandFrequencies;
  bool get isAvailable => _isAvailable;

  EqualizerService(this._eqRepository);

  EqConfig? get currentConfig => _currentConfig;
  bool get isEnabled => _currentConfig?.enabled ?? false;
  bool get limiterEnabled => _currentConfig?.limiterEnabled ?? false;
  bool get loudnessEnabled => _currentConfig?.loudnessEnabled ?? false;
  double get loudness => _currentConfig?.loudness ?? 0.0;

  Future<void> initSession(int sessionId) async {
    debugPrint('[EQ] initSession recibido: sessionId=$sessionId');
    try {
      await _channel.invokeMethod("initSession", {"sessionId": sessionId});
      _nativeBandCount = await _channel.invokeMethod("getBandCount") ?? 5;
      final freqsRaw = await _channel.invokeMethod("getBandFrequencies");
      if (freqsRaw is List) {
        _nativeBandFrequencies = freqsRaw.map((e) => (e as num).toInt()).toList();
      }
      _isAvailable = true;
      debugPrint('[EQ] initSession OK, nativeBandCount=$_nativeBandCount, '
          'nativeFreqs=$_nativeBandFrequencies');
      if (_currentConfig != null) {
        await _applyFullConfig(_currentConfig!);
        debugPrint('[EQ] config reaplicada');
      }
    } catch (e) {
      _isAvailable = false;
      debugPrint('[EQ] initSession ERROR: $e');
    }
    notifyListeners();
  }

  Future<void> loadGlobal() async {
    debugPrint('[EQ] loadGlobal');
    _currentConfig = await _eqRepository.loadGlobal();
    debugPrint('[EQ] Global config loaded: enabled=${_currentConfig!.enabled}, '
        'preset=${_currentConfig!.presetName}');
    await _applyFullConfig(_currentConfig!);
    notifyListeners();
  }

  Future<void> saveGlobal() async {
    if (_currentConfig == null) return;
    await _eqRepository.saveGlobal(_currentConfig!);
  }

  List<double> _mapToNativeBands(List<double> uiGains, List<int> uiFreqs) {
    final nativeGains = List<double>.filled(_nativeBandCount, 0.0);
    for (var nIdx = 0; nIdx < _nativeBandCount; nIdx++) {
      final nativeFreq = _nativeBandFrequencies[nIdx].toDouble();
      nativeGains[nIdx] = _interpolateGain(nativeFreq, uiFreqs, uiGains);
    }
    return nativeGains;
  }

  double _interpolateGain(double targetFreq, List<int> freqs, List<double> gains) {
    if (freqs.isEmpty || gains.isEmpty) return 0.0;
    if (targetFreq <= freqs.first) return gains.first;
    if (targetFreq >= freqs.last) return gains.last;

    for (var i = 0; i < freqs.length - 1; i++) {
      if (freqs[i] <= targetFreq && freqs[i + 1] >= targetFreq) {
        final logTarget = log(targetFreq);
        final logLow = log(freqs[i].toDouble());
        final logHigh = log(freqs[i + 1].toDouble());
        final t = (logTarget - logLow) / (logHigh - logLow);
        return gains[i] + t * (gains[i + 1] - gains[i]);
      }
    }
    return 0.0;
  }

  Future<void> _applyFullConfig(EqConfig config) async {
    try {
      debugPrint('[EQ] _applyFullConfig: enabled=${config.enabled}, nativeBands=$_nativeBandCount');
      await _channel.invokeMethod("setEnabled", {"enabled": config.enabled});

      // Map 12 UI bands to native bands using log interpolation
      final nativeGains = _mapToNativeBands(config.bandGains, bandFrequencies);
      debugPrint('[EQ] mapped gains: ui=${config.bandGains} → native=$nativeGains');
      for (var i = 0; i < _nativeBandCount; i++) {
        await _channel.invokeMethod("setBandGain", {
          "bandIndex": i,
          "gainDb": nativeGains[i],
        });
      }

      await _channel.invokeMethod("setBassBoost", {"gainDb": config.bassBoost});
      await _channel.invokeMethod("setVirtualizer", {"strength": config.virtualizer});

      // Loudness
      await setLoudness(config.loudness);
      await setLoudnessEnabled(config.loudnessEnabled);

      // Limiter
      try {
        await setLimiterEnabled(config.limiterEnabled);
        if (config.limiterEnabled) {
          await setLimiterParams(
            threshold: config.limiterThreshold,
            ratio: config.limiterRatio,
            attack: config.limiterAttack,
            release: config.limiterRelease,
            postGain: config.limiterPostGain,
          );
        }
      } catch (e) {
        debugPrint('[EQ] Limiter not available (API < 28?): $e');
      }

      debugPrint('[EQ] Full config applied successfully');
    } catch (e) {
      debugPrint('[EQ] _applyFullConfig ERROR: $e');
    }
  }

  Future<void> setBandGain(int index, double gainDb) async {
    if (_currentConfig == null) {
      _currentConfig = EqConfig.flat();
    }
    final clampedGain = gainDb.clamp(-12.0, 12.0);
    final newBands = List<double>.from(_currentConfig!.bandGains);
    if (index < bandCount) newBands[index] = clampedGain;

    _currentConfig = _currentConfig!.copyWith(bandGains: newBands, presetName: null);

    // Apply via log interpolation
    final nativeGains = _mapToNativeBands(newBands, bandFrequencies);
    try {
      for (var i = 0; i < _nativeBandCount; i++) {
        await _channel.invokeMethod("setBandGain", {
          "bandIndex": i,
          "gainDb": nativeGains[i],
        });
      }
    } catch (e) {
      debugPrint('[EQ] setBandGain ERROR: $e');
    }

    await saveGlobal();
    notifyListeners();
  }

  Future<void> setBassBoost(double gainDb) async {
    if (_currentConfig == null) {
      _currentConfig = EqConfig.flat();
    }
    final clampedGain = gainDb.clamp(0.0, 15.0);
    _currentConfig = _currentConfig!.copyWith(bassBoost: clampedGain);

    try {
      debugPrint('[EQ] setBassBoost($clampedGain)');
      await _channel.invokeMethod("setBassBoost", {"gainDb": clampedGain});
    } catch (e) {
      debugPrint('[EQ] setBassBoost ERROR: $e');
    }

    await saveGlobal();
    notifyListeners();
  }

  Future<void> setVirtualizer(double strength) async {
    if (_currentConfig == null) {
      _currentConfig = EqConfig.flat();
    }
    final clampedStrength = strength.clamp(0.0, 1.0);
    _currentConfig = _currentConfig!.copyWith(virtualizer: clampedStrength);

    try {
      debugPrint('[EQ] setVirtualizer($clampedStrength)');
      await _channel.invokeMethod("setVirtualizer", {"strength": clampedStrength});
    } catch (e) {
      debugPrint('[EQ] setVirtualizer ERROR: $e');
    }

    await saveGlobal();
    notifyListeners();
  }

  Future<void> toggleEnabled() async {
    debugPrint('[EQ] toggleEnabled called, current=${_currentConfig?.enabled}');
    if (_currentConfig == null) {
      _currentConfig = EqConfig.flat();
    }
    final newEnabled = !_currentConfig!.enabled;
    _currentConfig = _currentConfig!.copyWith(enabled: newEnabled);
    debugPrint('[EQ] newEnabled = $newEnabled, calling _applyFullConfig');

    await _applyFullConfig(_currentConfig!);
    await saveGlobal();
    notifyListeners();
  }

  Future<void> applyPreset(String name) async {
    if (_currentConfig == null) return;
    final curve = EqConfig.presetCurves[name];
    if (curve == null) return;

    // Convert frequency→gain map to 12-band list via interpolation
    final sortedFreqs = curve.keys.toList()..sort();
    final sortedGains = sortedFreqs.map((f) => curve[f]!.toDouble()).toList();
    final newBands = <double>[];
    for (final freq in bandFrequencies) {
      newBands.add(_interpolateGain(freq.toDouble(), sortedFreqs, sortedGains));
    }

    _currentConfig = _currentConfig!.copyWith(
      bandGains: newBands,
      bassBoost: 0.0,
      presetName: name,
    );

    await _applyFullConfig(_currentConfig!);
    await saveGlobal();
    notifyListeners();
  }

  Future<void> setLoudness(double db) async {
    final clamped = db.clamp(0.0, 10.0);
    try {
      await _channel.invokeMethod("setLoudness", {"gainDb": clamped});
    } catch (e) {
      debugPrint('[EQ] setLoudness ERROR: $e');
    }
  }

  Future<void> setLoudnessEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod("setLoudnessEnabled", {"enabled": enabled});
    } catch (e) {
      debugPrint('[EQ] setLoudnessEnabled ERROR: $e');
    }
  }

  Future<void> setLimiterEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod("setLimiterEnabled", {"enabled": enabled});
    } catch (e) {
      debugPrint('[EQ] setLimiterEnabled ERROR: $e');
    }
  }

  Future<void> setLimiterParams({
    required double threshold,
    required double ratio,
    required double attack,
    required double release,
    required double postGain,
  }) async {
    try {
      await _channel.invokeMethod("setLimiter", {
        "threshold": threshold,
        "ratio": ratio,
        "attack": attack,
        "release": release,
        "postGain": postGain,
      });
    } catch (e) {
      debugPrint('[EQ] setLimiterParams ERROR: $e');
    }
  }

  Future<void> setBassFrequency(int hz) async {
    if (_currentConfig == null) {
      _currentConfig = EqConfig.flat();
    }
    _currentConfig = _currentConfig!.copyWith(bassFrequencyHz: hz);

    try {
      await _channel.invokeMethod("setBassFrequency", {"hz": hz});
    } catch (e) {
      debugPrint('[EQ] setBassFrequency ERROR: $e');
    }

    // Apply extra EQ boost at the selected bass frequency
    if (hz != 80 && _currentConfig!.bassBoost > 0) {
      final boostAmount = _currentConfig!.bassBoost * 0.3;
      final nativeGains = _mapToNativeBands(_currentConfig!.bandGains, bandFrequencies);
      // Find closest native band
      var bestIdx = 0;
      var bestDiff = 999999;
      for (var i = 0; i < _nativeBandFrequencies.length; i++) {
        final diff = (hz - _nativeBandFrequencies[i]).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          bestIdx = i;
        }
      }
      nativeGains[bestIdx] = (nativeGains[bestIdx] + boostAmount).clamp(-12.0, 12.0);
      try {
        await _channel.invokeMethod("setBandGain", {
          "bandIndex": bestIdx,
          "gainDb": nativeGains[bestIdx],
        });
      } catch (e) {
        debugPrint('[EQ] setBassFrequency band boost ERROR: $e');
      }
    }

    await saveGlobal();
    notifyListeners();
  }

  void applyConfigDirect(EqConfig config) {
    _currentConfig = config;
    saveGlobal();
    notifyListeners();
  }

  Future<void> reset() async {
    _currentConfig = EqConfig.flat();
    await _applyFullConfig(_currentConfig!);
    await _eqRepository.resetGlobal();
    notifyListeners();
  }
}
