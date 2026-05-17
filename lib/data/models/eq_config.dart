import 'dart:convert';

class EqConfig {
  static const int globalId = 0;

  final int songId;
  final List<double> bandGains;
  final double bassBoost;
  final double virtualizer;
  final bool enabled;
  final String? presetName;
  final double loudness;
  final bool loudnessEnabled;
  final double limiterThreshold;
  final double limiterRatio;
  final double limiterAttack;
  final double limiterRelease;
  final double limiterPostGain;
  final bool limiterEnabled;
  final int bassFrequencyHz;
  final int visualBandCount;

  static const Map<String, Map<int, double>> presetCurves = {
    'Plano':       {31:0, 62:0, 125:0, 250:0, 500:0, 1000:0, 2000:0, 4000:0, 8000:0, 16000:0},
    'Rock':        {31:4, 62:3, 125:2, 250:0, 500:-1, 1000:-1, 2000:0, 4000:2, 8000:3, 16000:3},
    'Pop':         {31:-1, 62:0, 125:1, 250:2, 500:2, 1000:0, 2000:-1, 4000:-1, 8000:0, 16000:0},
    'Jazz':        {31:2, 62:1, 125:0, 250:1, 500:2, 1000:3, 2000:3, 4000:2, 8000:1, 16000:1},
    'Clásica':     {31:3, 62:2, 125:2, 250:1, 500:0, 1000:0, 2000:0, 4000:0, 8000:2, 16000:3},
    'Hip-Hop':     {31:5, 62:4, 125:2, 250:1, 500:-1, 1000:-1, 2000:0, 4000:0, 8000:1, 16000:1},
    'Electrónica': {31:4, 62:3, 125:2, 250:0, 500:-1, 1000:-1, 2000:1, 4000:2, 8000:2, 16000:2},
    'Latino':      {31:3, 62:2, 125:0, 250:-1, 500:-1, 1000:0, 2000:1, 4000:2, 8000:3, 16000:2},
  };

  const EqConfig({
    this.songId = 0,
    required this.bandGains,
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
    this.enabled = true,
    this.presetName,
    this.loudness = 0.0,
    this.loudnessEnabled = false,
    this.limiterThreshold = -3.0,
    this.limiterRatio = 4.0,
    this.limiterAttack = 10.0,
    this.limiterRelease = 100.0,
    this.limiterPostGain = 0.0,
    this.limiterEnabled = false,
    this.bassFrequencyHz = 80,
    this.visualBandCount = 5,
  });

  Map<String, dynamic> toMap() {
    return {
      'song_id': songId,
      'band_gains': jsonEncode(bandGains),
      'bass_boost': bassBoost,
      'virtualizer': virtualizer,
      'enabled': enabled ? 1 : 0,
      'preset_name': presetName,
      'loudness': loudness,
      'loudness_enabled': loudnessEnabled ? 1 : 0,
      'limiter_threshold': limiterThreshold,
      'limiter_ratio': limiterRatio,
      'limiter_attack': limiterAttack,
      'limiter_release': limiterRelease,
      'limiter_post_gain': limiterPostGain,
      'limiter_enabled': limiterEnabled ? 1 : 0,
      'bass_frequency_hz': bassFrequencyHz,
      'visual_band_count': visualBandCount,
    };
  }

  factory EqConfig.fromMap(Map<String, dynamic> map) {
    final bandsRaw = map['band_gains'];
    List<double> bands;
    if (bandsRaw is String) {
      bands = (jsonDecode(bandsRaw) as List).map((e) => (e as num).toDouble()).toList();
    } else if (bandsRaw is List) {
      bands = bandsRaw.map((e) => (e as num).toDouble()).toList();
    } else {
      bands = List.filled(12, 0.0);
    }
    return EqConfig(
      songId: (map['song_id'] as num?)?.toInt() ?? 0,
      bandGains: bands,
      bassBoost: (map['bass_boost'] as num?)?.toDouble() ?? 0.0,
      virtualizer: (map['virtualizer'] as num?)?.toDouble() ?? 0.0,
      enabled: (map['enabled'] as int?) == 1,
      presetName: map['preset_name'] as String?,
      loudness: (map['loudness'] as num?)?.toDouble() ?? 0.0,
      loudnessEnabled: (map['loudness_enabled'] as int?) == 1,
      limiterThreshold: (map['limiter_threshold'] as num?)?.toDouble() ?? -3.0,
      limiterRatio: (map['limiter_ratio'] as num?)?.toDouble() ?? 4.0,
      limiterAttack: (map['limiter_attack'] as num?)?.toDouble() ?? 10.0,
      limiterRelease: (map['limiter_release'] as num?)?.toDouble() ?? 100.0,
      limiterPostGain: (map['limiter_post_gain'] as num?)?.toDouble() ?? 0.0,
      limiterEnabled: (map['limiter_enabled'] as int?) == 1,
      bassFrequencyHz: (map['bass_frequency_hz'] as num?)?.toInt() ?? 80,
      visualBandCount: (map['visual_band_count'] as num?)?.toInt() ?? 5,
    );
  }

  EqConfig copyWith({
    int? songId,
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
    return EqConfig(
      songId: songId ?? this.songId,
      bandGains: bandGains ?? this.bandGains,
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
      enabled: enabled ?? this.enabled,
      presetName: presetName,
      loudness: loudness ?? this.loudness,
      loudnessEnabled: loudnessEnabled ?? this.loudnessEnabled,
      limiterThreshold: limiterThreshold ?? this.limiterThreshold,
      limiterRatio: limiterRatio ?? this.limiterRatio,
      limiterAttack: limiterAttack ?? this.limiterAttack,
      limiterRelease: limiterRelease ?? this.limiterRelease,
      limiterPostGain: limiterPostGain ?? this.limiterPostGain,
      limiterEnabled: limiterEnabled ?? this.limiterEnabled,
      bassFrequencyHz: bassFrequencyHz ?? this.bassFrequencyHz,
      visualBandCount: visualBandCount ?? this.visualBandCount,
    );
  }

  static EqConfig flat() {
    return EqConfig(
      songId: globalId,
      bandGains: List.filled(12, 0.0),
      bassBoost: 0.0,
      virtualizer: 0.0,
      enabled: true,
      presetName: 'Plano',
    );
  }

  static EqConfig global() {
    return EqConfig(
      songId: globalId,
      bandGains: List.filled(12, 0.0),
      bassBoost: 0.0,
      virtualizer: 0.0,
      enabled: true,
      limiterEnabled: false,
      loudnessEnabled: false,
      presetName: 'Plano',
    );
  }

  @override
  String toString() {
    return 'EqConfig(bands: ${bandGains.length}, bass: $bassBoost, virtualizer: $virtualizer, '
        'enabled: $enabled, preset: $presetName, loudness: $loudness, '
        'limiter: $limiterEnabled, bassHz: $bassFrequencyHz)';
  }
}
