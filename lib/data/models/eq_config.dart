import 'dart:convert';

class EqConfig {
  final int songId;
  final List<int> bandLevels;
  final int bassBoostStrength;
  final int virtualizerStrength;
  final bool enabled;
  final String? presetName;

  const EqConfig({
    required this.songId,
    required this.bandLevels,
    this.bassBoostStrength = 0,
    this.virtualizerStrength = 0,
    this.enabled = true,
    this.presetName,
  });

  Map<String, dynamic> toMap() {
    return {
      'song_id': songId,
      'band_levels': jsonEncode(bandLevels),
      'bass_boost': bassBoostStrength,
      'virtualizer': virtualizerStrength,
      'enabled': enabled ? 1 : 0,
      'preset_name': presetName,
    };
  }

  factory EqConfig.fromMap(Map<String, dynamic> map) {
    return EqConfig(
      songId: map['song_id'] as int,
      bandLevels: (jsonDecode(map['band_levels'] as String) as List)
          .map((e) => e as int)
          .toList(),
      bassBoostStrength: map['bass_boost'] as int? ?? 0,
      virtualizerStrength: map['virtualizer'] as int? ?? 0,
      enabled: (map['enabled'] as int?) == 1,
      presetName: map['preset_name'] as String?,
    );
  }

  EqConfig copyWith({
    int? songId,
    List<int>? bandLevels,
    int? bassBoostStrength,
    int? virtualizerStrength,
    bool? enabled,
    String? presetName,
  }) {
    return EqConfig(
      songId: songId ?? this.songId,
      bandLevels: bandLevels ?? this.bandLevels,
      bassBoostStrength: bassBoostStrength ?? this.bassBoostStrength,
      virtualizerStrength: virtualizerStrength ?? this.virtualizerStrength,
      enabled: enabled ?? this.enabled,
      presetName: presetName ?? this.presetName,
    );
  }

  /// Configuración plana (sin EQ)
  static EqConfig flat({required int songId}) {
    return EqConfig(
      songId: songId,
      bandLevels: [],
      bassBoostStrength: 0,
      virtualizerStrength: 0,
      enabled: true,
      presetName: 'Plano',
    );
  }

  @override
  String toString() {
    return 'EqConfig(songId: $songId, bands: ${bandLevels.length}, '
        'bass: $bassBoostStrength, virtualizer: $virtualizerStrength, '
        'enabled: $enabled, preset: $presetName)';
  }
}
