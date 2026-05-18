/// EqualizerEngineConfig — Shared DSP configuration model.
///
/// This model represents the complete state of the DSP engine
/// and is shared between:
/// - Flutter UI (equalizer_screen.dart)
/// - Flutter state (equalizer_state.dart)
/// - Flutter controller (equalizer_controller.dart)
/// - Native bridge (native_equalizer_service.dart)
///
/// It extends the existing EqConfig model with additional
/// engine-specific fields for the new DSP architecture.
class EqualizerEngineConfig {
  // ─── EQ Bands ───────────────────────────────────────────────

  /// 12-band UI equalizer gains in dB (-12 to +12)
  final List<double> bandGains;

  /// Whether the EQ is enabled
  final bool enabled;

  /// Current preset name (null if custom)
  final String? presetName;

  // ─── Bass Processing ────────────────────────────────────────

  /// Bass boost strength in dB (0-15)
  final double bassBoost;

  /// Target bass frequency in Hz (30, 60, 80, or 100)
  final int bassFrequencyHz;

  // ─── Spatial Audio ──────────────────────────────────────────

  /// Virtualizer strength (0.0-1.0)
  final double virtualizer;

  // ─── Loudness ───────────────────────────────────────────────

  /// Loudness enhancer gain in dB (0-10)
  final double loudness;

  /// Whether loudness enhancer is enabled
  final bool loudnessEnabled;

  // ─── Limiter (DynamicsProcessing) ───────────────────────────

  /// Limiter threshold in dB (-12 to 0)
  final double limiterThreshold;

  /// Limiter ratio (1:1 to 20:1, ∞:1 for true limiting)
  final double limiterRatio;

  /// Limiter attack time in ms (1-200)
  final double limiterAttack;

  /// Limiter release time in ms (1-200)
  final double limiterRelease;

  /// Limiter post-gain in dB (0-6)
  final double limiterPostGain;

  /// Whether the limiter is enabled
  final bool limiterEnabled;

  // ─── UI Configuration ───────────────────────────────────────

  /// Number of visual bands to display (5, 7, or 10)
  final int visualBandCount;

  // ─── Engine State ───────────────────────────────────────────

  /// DSP engine mode: "dynamics_processing", "legacy", or "unavailable"
  final String engineMode;

  /// Whether the native DSP engine is available
  final bool engineAvailable;

  const EqualizerEngineConfig({
    this.bandGains = const [],
    this.enabled = true,
    this.presetName,
    this.bassBoost = 0.0,
    this.bassFrequencyHz = 80,
    this.virtualizer = 0.0,
    this.loudness = 0.0,
    this.loudnessEnabled = false,
    this.limiterThreshold = -3.0,
    this.limiterRatio = 4.0,
    this.limiterAttack = 10.0,
    this.limiterRelease = 100.0,
    this.limiterPostGain = 0.0,
    this.limiterEnabled = false,
    this.visualBandCount = 5,
    this.engineMode = "unavailable",
    this.engineAvailable = false,
  });

  /// Create a flat (default) configuration.
  factory EqualizerEngineConfig.flat() {
    return const EqualizerEngineConfig(
      bandGains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      enabled: true,
      presetName: 'Plano',
      bassBoost: 0.0,
      bassFrequencyHz: 80,
      virtualizer: 0.0,
      loudness: 0.0,
      loudnessEnabled: false,
      limiterThreshold: -3.0,
      limiterRatio: 4.0,
      limiterAttack: 10.0,
      limiterRelease: 100.0,
      limiterPostGain: 0.0,
      limiterEnabled: false,
      visualBandCount: 5,
    );
  }

  /// Convert from the legacy EqConfig model.
  factory EqualizerEngineConfig.fromEqConfig(EqConfig eqConfig, {
    String engineMode = "unavailable",
    bool engineAvailable = false,
  }) {
    return EqualizerEngineConfig(
      bandGains: eqConfig.bandGains,
      enabled: eqConfig.enabled,
      presetName: eqConfig.presetName,
      bassBoost: eqConfig.bassBoost,
      bassFrequencyHz: eqConfig.bassFrequencyHz,
      virtualizer: eqConfig.virtualizer,
      loudness: eqConfig.loudness,
      loudnessEnabled: eqConfig.loudnessEnabled,
      limiterThreshold: eqConfig.limiterThreshold,
      limiterRatio: eqConfig.limiterRatio,
      limiterAttack: eqConfig.limiterAttack,
      limiterRelease: eqConfig.limiterRelease,
      limiterPostGain: eqConfig.limiterPostGain,
      limiterEnabled: eqConfig.limiterEnabled,
      visualBandCount: eqConfig.visualBandCount,
      engineMode: engineMode,
      engineAvailable: engineAvailable,
    );
  }

  /// Convert to the legacy EqConfig model for persistence.
  EqConfig toEqConfig() {
    return EqConfig(
      bandGains: bandGains,
      enabled: enabled,
      presetName: presetName,
      bassBoost: bassBoost,
      bassFrequencyHz: bassFrequencyHz,
      virtualizer: virtualizer,
      loudness: loudness,
      loudnessEnabled: loudnessEnabled,
      limiterThreshold: limiterThreshold,
      limiterRatio: limiterRatio,
      limiterAttack: limiterAttack,
      limiterRelease: limiterRelease,
      limiterPostGain: limiterPostGain,
      limiterEnabled: limiterEnabled,
      visualBandCount: visualBandCount,
    );
  }

  EqualizerEngineConfig copyWith({
    List<double>? bandGains,
    bool? enabled,
    String? presetName,
    double? bassBoost,
    int? bassFrequencyHz,
    double? virtualizer,
    double? loudness,
    bool? loudnessEnabled,
    double? limiterThreshold,
    double? limiterRatio,
    double? limiterAttack,
    double? limiterRelease,
    double? limiterPostGain,
    bool? limiterEnabled,
    int? visualBandCount,
    String? engineMode,
    bool? engineAvailable,
  }) {
    return EqualizerEngineConfig(
      bandGains: bandGains ?? this.bandGains,
      enabled: enabled ?? this.enabled,
      presetName: presetName ?? this.presetName,
      bassBoost: bassBoost ?? this.bassBoost,
      bassFrequencyHz: bassFrequencyHz ?? this.bassFrequencyHz,
      virtualizer: virtualizer ?? this.virtualizer,
      loudness: loudness ?? this.loudness,
      loudnessEnabled: loudnessEnabled ?? this.loudnessEnabled,
      limiterThreshold: limiterThreshold ?? this.limiterThreshold,
      limiterRatio: limiterRatio ?? this.limiterRatio,
      limiterAttack: limiterAttack ?? this.limiterAttack,
      limiterRelease: limiterRelease ?? this.limiterRelease,
      limiterPostGain: limiterPostGain ?? this.limiterPostGain,
      limiterEnabled: limiterEnabled ?? this.limiterEnabled,
      visualBandCount: visualBandCount ?? this.visualBandCount,
      engineMode: engineMode ?? this.engineMode,
      engineAvailable: engineAvailable ?? this.engineAvailable,
    );
  }

  @override
  String toString() {
    return 'EqualizerEngineConfig('
        'bands: ${bandGains.length}, '
        'enabled: $enabled, '
        'preset: $presetName, '
        'bass: $bassBoost, '
        'virtualizer: $virtualizer, '
        'loudness: $loudness, '
        'limiter: $limiterEnabled, '
        'mode: $engineMode)';
  }
}

// Import needed for EqConfig conversion
// This is done via a separate import in files that use this model
// to avoid circular dependencies.
// ignore: unused_import
import '../data/models/eq_config.dart';
