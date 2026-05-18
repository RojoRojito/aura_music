import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/models/eq_config.dart';
import '../data/repositories/eq_repository.dart';
import 'native_equalizer_service.dart';

/// EqualizerState — Dedicated EQ state management.
///
/// This class owns the EQ configuration state and handles:
/// - Loading/saving global EQ config
/// - Tracking current configuration
/// - Band mapping between UI (12 bands) and native (device-dependent) bands
/// - Preset application
/// - Persistence via EqRepository
///
/// It does NOT communicate with native DSP directly.
/// That is handled by NativeEqualizerService.
///
/// Usage:
/// - EqualizerController reads from this state
/// - EqualizerController writes to NativeEqualizerService
/// - This class notifies listeners when state changes
class EqualizerState extends ChangeNotifier {
  final EqRepository _eqRepository;
  final NativeEqualizerService _nativeService;

  static const List<int> bandFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 12000, 16000, 20000
  ];
  static const int bandCount = 12;

  EqConfig? _currentConfig;
  int _nativeBandCount = 5;
  List<int> _nativeBandFrequencies = [];
  bool _isAvailable = false;
  String _engineMode = "unavailable";

  int get nativeBandCount => _nativeBandCount;
  List<int> get nativeBandFrequencies => _nativeBandFrequencies;
  bool get isAvailable => _isAvailable;
  String get engineMode => _engineMode;

  EqConfig? get currentConfig => _currentConfig;
  bool get isEnabled => _currentConfig?.enabled ?? false;
  bool get limiterEnabled => _currentConfig?.limiterEnabled ?? false;
  bool get loudnessEnabled => _currentConfig?.loudnessEnabled ?? false;
  double get loudness => _currentConfig?.loudness ?? 0.0;
  double get bassBoost => _currentConfig?.bassBoost ?? 0.0;
  double get virtualizer => _currentConfig?.virtualizer ?? 0.0;

  EqualizerState(this._eqRepository, this._nativeService);

  /// Initialize the session with a native audio session ID.
  /// Called when just_audio provides androidAudioSessionId.
  Future<void> initSession(int sessionId) async {
    debugPrint('[EQState] initSession: sessionId=$sessionId');
    try {
      await _nativeService.initSession(sessionId);

      // Fetch native band info
      _nativeBandCount = await _nativeService.getBandCount();
      final freqsRaw = await _nativeService.getBandFrequencies();
      _nativeBandFrequencies = freqsRaw;

      // Check engine mode
      _engineMode = await _nativeService.getEngineMode();

      _isAvailable = true;
      debugPrint('[EQState] initSession OK: bands=$_nativeBandCount, mode=$_engineMode');

      // Reapply stored config if available
      if (_currentConfig != null) {
        await _applyFullConfig(_currentConfig!);
        debugPrint('[EQState] config reapplied after session init');
      }
    } catch (e) {
      _isAvailable = false;
      _engineMode = "unavailable";
      debugPrint('[EQState] initSession ERROR: $e');
    }
    notifyListeners();
  }

  /// Load global EQ config from persistence.
  Future<void> loadGlobal() async {
    debugPrint('[EQState] loadGlobal');
    _currentConfig = await _eqRepository.loadGlobal();
    debugPrint('[EQState] Global config loaded: enabled=${_currentConfig!.enabled}, preset=${_currentConfig!.presetName}');
    notifyListeners();
  }

  /// Save current config to persistence.
  Future<void> saveGlobal() async {
    if (_currentConfig == null) return;
    await _eqRepository.saveGlobal(_currentConfig!);
  }

  /// Update the current config and notify listeners.
  void updateConfig(EqConfig newConfig) {
    _currentConfig = newConfig;
    notifyListeners();
  }

  /// Update a single field of the current config.
  void updateConfigField({
    List<double>? bandGains,
    double? bassBoost,
    double? virtualizer,
    bool? enabled,
    String? presetName,
    double? loudness,
    bool? loudnessEnabled,
    double? limiterThreshold,
    double? limiterRatio,
    double? limiterAttack,
    double? limiterRelease,
    double? limiterPostGain,
    bool? limiterEnabled,
    int? bassFrequencyHz,
    int? visualBandCount,
  }) {
    if (_currentConfig == null) {
      _currentConfig = EqConfig.flat();
    }
    _currentConfig = _currentConfig!.copyWith(
      bandGains: bandGains,
      bassBoost: bassBoost,
      virtualizer: virtualizer,
      enabled: enabled,
      presetName: presetName,
      loudness: loudness,
      loudnessEnabled: loudnessEnabled,
      limiterThreshold: limiterThreshold,
      limiterRatio: limiterRatio,
      limiterAttack: limiterAttack,
      limiterRelease: limiterRelease,
      limiterPostGain: limiterPostGain,
      limiterEnabled: limiterEnabled,
      bassFrequencyHz: bassFrequencyHz,
      visualBandCount: visualBandCount,
    );
    notifyListeners();
  }

  /// Map 12 UI band gains to native device band gains.
  List<double> mapToNativeBands(List<double> uiGains) {
    final nativeGains = List<double>.filled(_nativeBandCount, 0.0);
    for (var nIdx = 0; nIdx < _nativeBandCount; nIdx++) {
      final nativeFreq = _nativeBandFrequencies[nIdx].toDouble();
      nativeGains[nIdx] = _interpolateGain(nativeFreq, uiGains);
    }
    return nativeGains;
  }

  /// Interpolate gain at a target frequency using logarithmic scaling.
  double _interpolateGain(double targetFreq, List<double> gains) {
    if (bandFrequencies.isEmpty || gains.isEmpty) return 0.0;
    if (targetFreq <= bandFrequencies.first) return gains.first;
    if (targetFreq >= bandFrequencies.last) return gains.last;

    for (var i = 0; i < bandFrequencies.length - 1; i++) {
      if (bandFrequencies[i] <= targetFreq && bandFrequencies[i + 1] >= targetFreq) {
        final logTarget = _log(targetFreq);
        final logLow = _log(bandFrequencies[i].toDouble());
        final logHigh = _log(bandFrequencies[i + 1].toDouble());
        final t = (logTarget - logLow) / (logHigh - logLow);
        return gains[i] + t * (gains[i + 1] - gains[i]);
      }
    }
    return 0.0;
  }

  double _log(double x) => log(x);

  /// Apply a full EQ configuration to the native DSP engine.
  Future<void> _applyFullConfig(EqConfig config) async {
    try {
      debugPrint('[EQState] _applyFullConfig: enabled=${config.enabled}, nativeBands=$_nativeBandCount');
      await _nativeService.setEnabled(config.enabled);

      // Map 12 UI bands to native bands
      final nativeGains = mapToNativeBands(config.bandGains);
      debugPrint('[EQState] mapped gains: ui=${config.bandGains} → native=$nativeGains');
      for (var i = 0; i < _nativeBandCount; i++) {
        await _nativeService.setBandGain(i, nativeGains[i]);
      }

      await _nativeService.setBassBoost(config.bassBoost);
      await _nativeService.setVirtualizer(config.virtualizer);
      await _nativeService.setLoudness(config.loudness);
      await _nativeService.setLoudnessEnabled(config.loudnessEnabled);

      // Limiter
      try {
        await _nativeService.setLimiterEnabled(config.limiterEnabled);
        if (config.limiterEnabled) {
          await _nativeService.setLimiterParams(
            threshold: config.limiterThreshold,
            ratio: config.limiterRatio,
            attack: config.limiterAttack,
            release: config.limiterRelease,
            postGain: config.limiterPostGain,
          );
        }
      } catch (e) {
        debugPrint('[EQState] Limiter not available: $e');
      }

      debugPrint('[EQState] Full config applied successfully');
    } catch (e) {
      debugPrint('[EQState] _applyFullConfig ERROR: $e');
    }
  }

  /// Apply a preset curve to the current configuration.
  Future<void> applyPreset(String name) async {
    if (_currentConfig == null) return;
    final curve = EqConfig.presetCurves[name];
    if (curve == null) return;

    // Convert frequency→gain map to 12-band list via interpolation
    final sortedFreqs = curve.keys.toList()..sort();
    final sortedGains = sortedFreqs.map((f) => curve[f]!.toDouble()).toList();
    final newBands = <double>[];
    for (final freq in bandFrequencies) {
      newBands.add(_interpolateGain(freq.toDouble(), sortedGains));
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

  /// Reset to flat EQ configuration.
  Future<void> reset() async {
    _currentConfig = EqConfig.flat();
    await _applyFullConfig(_currentConfig!);
    await _eqRepository.resetGlobal();
    notifyListeners();
  }

  /// Mark the engine as unavailable (e.g., on error).
  void markUnavailable() {
    _isAvailable = false;
    _engineMode = "unavailable";
    notifyListeners();
  }
}
