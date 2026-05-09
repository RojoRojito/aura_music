import 'dart:convert';

class EqConfig {
  final int songId;
  final List<double> bandGains;
  final double bassBoost;
  final double virtualizer;
  final bool enabled;
  final String? presetName;

  static const Map<String, List<double>> presets = {
    'Plano':       [0,0,0,0,0,0,0,0,0,0,0,0],
    'Rock':        [4,3,2,0,-1,-1,0,2,3,3,3,2],
    'Pop':         [-1,0,1,2,2,0,-1,-1,0,0,0,0],
    'Jazz':        [2,1,0,1,2,3,3,2,1,1,0,0],
    'Clásica':     [3,2,2,1,0,0,0,0,2,2,2,3],
    'Hip-Hop':     [4,4,2,1,-1,-1,0,0,1,1,0,0],
    'Electrónica': [3,3,2,0,-1,-1,1,2,2,1,1,2],
    'Latino':      [3,2,0,-1,-1,0,1,2,3,3,2,1],
  };

  const EqConfig({
    required this.songId,
    required this.bandGains,
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
    this.enabled = true,
    this.presetName,
  });

  Map<String, dynamic> toMap() {
    return {
      'song_id': songId,
      'band_gains': jsonEncode(bandGains),
      'bass_boost': bassBoost,
      'virtualizer': virtualizer,
      'enabled': enabled ? 1 : 0,
      'preset_name': presetName,
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
      songId: map['song_id'] as int,
      bandGains: bands,
      bassBoost: (map['bass_boost'] as num?)?.toDouble() ?? 0.0,
      virtualizer: (map['virtualizer'] as num?)?.toDouble() ?? 0.0,
      enabled: (map['enabled'] as int?) == 1,
      presetName: map['preset_name'] as String?,
    );
  }

  EqConfig copyWith({
    int? songId,
    List<double>? bandGains,
    double? bassBoost,
    double? virtualizer,
    bool? enabled,
    String? presetName,
  }) {
    return EqConfig(
      songId: songId ?? this.songId,
      bandGains: bandGains ?? this.bandGains,
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
      enabled: enabled ?? this.enabled,
      presetName: presetName ?? this.presetName,
    );
  }

  static EqConfig flat({required int songId}) {
    return EqConfig(
      songId: songId,
      bandGains: List.filled(12, 0.0),
      bassBoost: 0.0,
      virtualizer: 0.0,
      enabled: true,
      presetName: 'Plano',
    );
  }

  @override
  String toString() {
    return 'EqConfig(songId: $songId, bands: ${bandGains.length}, '
        'bass: $bassBoost, virtualizer: $virtualizer, '
        'enabled: $enabled, preset: $presetName)';
  }
}