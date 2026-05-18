import 'package:flutter/foundation.dart';
import '../data/models/eq_config.dart';
import '../data/repositories/eq_repository.dart';
import 'native_equalizer_service.dart';
import 'equalizer_state.dart';

/// EqualizerController — UI controller separated from DSP implementation.
///
/// This class handles all UI-facing operations:
/// - Setting individual band gains
/// - Toggling EQ on/off
/// - Applying presets
/// - Adjusting bass, virtualizer, loudness, limiter
/// - Resetting to defaults
///
/// Architecture:
/// - Reads state from EqualizerState
/// - Writes to NativeEqualizerService (native bridge)
/// - Persists via EqRepository
/// - Notifies UI listeners via ChangeNotifier
///
/// This separation ensures:
/// - UI logic is independent of native DSP implementation
/// - Easy to test (mock NativeEqualizerService)
/// - Clear ownership: State owns data, Controller owns actions, Service owns native calls
class EqualizerController extends ChangeNotifier {
  final EqualizerState _state;
  final NativeEqualizerService _native;
  final EqRepository _repository;

  static const List<int> uiFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 12000, 16000, 20000
  ];
  static const int uiBandCount = 12;

  EqualizerController(
    this._state,
    this._native,
    this._repository,
  );

  // ─── State Accessors ────────────────────────────────────────

  EqConfig? get currentConfig => _state.currentConfig;
  bool get isEnabled => _state.isEnabled;
  bool get isAvailable => _state.isAvailable;
  String get engineMode => _state.engineMode;
  int get nativeBandCount => _state.nativeBandCount;
  List<int> get nativeBandFrequencies => _state.nativeBandFrequencies;

  // ─── Session Initialization ─────────────────────────────────

  /// Initialize the DSP engine with an audio session ID.
  /// Called from main.dart when just_audio provides androidAudioSessionId.
  Future<void> initSession(int sessionId) async {
    await _state.initSession(sessionId);
    notifyListeners();
  }

  // ─── EQ Band Operations ─────────────────────────────────────

  /// Set gain for a specific UI band (0-11).
  Future<void> setBandGain(int index, double gainDb) async {
    if (_state.currentConfig == null) {
      _state.updateConfig(EqConfig.flat());
    }

    final clampedGain = gainDb.clamp(-12.0, 12.0);
    final newBands = List<double>.from(_state.currentConfig!.bandGains);
    if (index < uiBandCount) newBands[index] = clampedGain;

    _state.updateConfigField(
      bandGains: newBands,
      presetName: null, // Custom adjustment clears preset name
    );

    // Map to native bands and apply
    final nativeGains = _state.mapToNativeBands(newBands);
    for (var i = 0; i < _state.nativeBandCount; i++) {
      await _native.setBandGain(i, nativeGains[i]);
    }

    await _state.saveGlobal();
    notifyListeners();
  }

  // ─── Master Toggle ──────────────────────────────────────────

  /// Toggle the entire EQ on/off.
  Future<void> toggleEnabled() async {
    debugPrint('[EQCtrl] toggleEnabled called, current=${_state.currentConfig?.enabled}');
    if (_state.currentConfig == null) {
      _state.updateConfig(EqConfig.flat());
    }
    final newEnabled = !_state.currentConfig!.enabled;
    _state.updateConfigField(enabled: newEnabled);
    debugPrint('[EQCtrl] newEnabled = $newEnabled');

    await _native.setEnabled(newEnabled);
    await _state.saveGlobal();
    notifyListeners();
  }

  // ─── Presets ────────────────────────────────────────────────

  /// Apply a preset curve.
  Future<void> applyPreset(String name) async {
    await _state.applyPreset(name);
    notifyListeners();
  }

  // ─── Bass Boost ─────────────────────────────────────────────

  /// Set bass boost strength (0-15 dB).
  Future<void> setBassBoost(double gainDb) async {
    if (_state.currentConfig == null) {
      _state.updateConfig(EqConfig.flat());
    }
    final clampedGain = gainDb.clamp(0.0, 15.0);
    _state.updateConfigField(bassBoost: clampedGain);

    await _native.setBassBoost(clampedGain);
    await _state.saveGlobal();
    notifyListeners();
  }

  /// Set bass target frequency (30, 60, 80, or 100 Hz).
  Future<void> setBassFrequency(int hz) async {
    if (_state.currentConfig == null) {
      _state.updateConfig(EqConfig.flat());
    }
    _state.updateConfigField(bassFrequencyHz: hz);

    await _native.setBassFrequency(hz);

    // Apply extra EQ boost at the selected bass frequency
    if (hz != 80 && _state.currentConfig!.bassBoost > 0) {
      await _applyBassFrequencyBoost(hz, _state.currentConfig!.bassBoost);
    }

    await _state.saveGlobal();
    notifyListeners();
  }

  /// Apply an EQ boost at the selected bass frequency.
  Future<void> _applyBassFrequencyBoost(int hz, double boostAmount) async {
    final nativeGains = _state.mapToNativeBands(_state.currentConfig!.bandGains);

    // Find closest native band
    var bestIdx = 0;
    var bestDiff = 999999;
    for (var i = 0; i < _state.nativeBandFrequencies.length; i++) {
      final diff = (hz - _state.nativeBandFrequencies[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIdx = i;
      }
    }

    nativeGains[bestIdx] = (nativeGains[bestIdx] + boostAmount * 0.3).clamp(-12.0, 12.0);
    await _native.setBandGain(bestIdx, nativeGains[bestIdx]);
  }

  // ─── Virtualizer ────────────────────────────────────────────

  /// Set virtualizer strength (0.0-1.0).
  Future<void> setVirtualizer(double strength) async {
    if (_state.currentConfig == null) {
      _state.updateConfig(EqConfig.flat());
    }
    final clampedStrength = strength.clamp(0.0, 1.0);
    _state.updateConfigField(virtualizer: clampedStrength);

    await _native.setVirtualizer(clampedStrength);
    await _state.saveGlobal();
    notifyListeners();
  }

  // ─── Loudness ───────────────────────────────────────────────

  /// Set loudness enhancer gain (0-10 dB).
  Future<void> setLoudness(double db) async {
    if (_state.currentConfig == null) {
      _state.updateConfig(EqConfig.flat());
    }
    final clamped = db.clamp(0.0, 10.0);
    _state.updateConfigField(loudness: clamped);

    await _native.setLoudness(clamped);
    await _state.saveGlobal();
    notifyListeners();
  }

  /// Enable or disable loudness enhancer.
  Future<void> setLoudnessEnabled(bool enabled) async {
    if (_state.currentConfig == null) {
      _state.updateConfig(EqConfig.flat());
    }
    _state.updateConfigField(loudnessEnabled: enabled);

    await _native.setLoudnessEnabled(enabled);
    await _state.saveGlobal();
    notifyListeners();
  }

  // ─── Limiter ────────────────────────────────────────────────

  /// Enable or disable the limiter.
  Future<void> setLimiterEnabled(bool enabled) async {
    if (_state.currentConfig == null) {
      _state.updateConfig(EqConfig.flat());
    }
    _state.updateConfigField(limiterEnabled: enabled);

    await _native.setLimiterEnabled(enabled);
    await _state.saveGlobal();
    notifyListeners();
  }

  /// Set limiter parameters.
  Future<void> setLimiterParams({
    double? threshold,
    double? ratio,
    double? attack,
    double? release,
    double? postGain,
  }) async {
    if (_state.currentConfig == null) {
      _state.updateConfig(EqConfig.flat());
    }

    final config = _state.currentConfig!;
    _state.updateConfigField(
      limiterThreshold: threshold,
      limiterRatio: ratio,
      limiterAttack: attack,
      limiterRelease: release,
      limiterPostGain: postGain,
    );

    await _native.setLimiterParams(
      threshold: threshold ?? config.limiterThreshold,
      ratio: ratio ?? config.limiterRatio,
      attack: attack ?? config.limiterAttack,
      release: release ?? config.limiterRelease,
      postGain: postGain ?? config.limiterPostGain,
    );
    await _state.saveGlobal();
    notifyListeners();
  }

  // ─── Visual Band Count ──────────────────────────────────────

  /// Update the number of visual bands to display (5, 7, or 10).
  Future<void> setVisualBandCount(int count) async {
    if (_state.currentConfig == null) {
      _state.updateConfig(EqConfig.flat());
    }
    _state.updateConfigField(visualBandCount: count);
    await _state.saveGlobal();
    notifyListeners();
  }

  // ─── Reset ──────────────────────────────────────────────────

  /// Reset all EQ settings to defaults.
  Future<void> reset() async {
    await _state.reset();
    notifyListeners();
  }

  // ─── Direct Config Application ──────────────────────────────

  /// Apply a config directly (used by UI for bulk updates).
  void applyConfigDirect(EqConfig config) {
    _state.updateConfig(config);
    _state.saveGlobal();
    notifyListeners();
  }
}
