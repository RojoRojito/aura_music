import 'dart:convert';

class SongFeatures {
  final int songId;
  final String? normalizedGenre;
  final String? subGenre;
  final List<String> moodTags;
  final String source;
  final DateTime enrichedAt;

  const SongFeatures({
    required this.songId,
    this.normalizedGenre,
    this.subGenre,
    this.moodTags = const [],
    this.source = 'unknown',
    required this.enrichedAt,
  });

  factory SongFeatures.fromMap(Map<String, dynamic> map) {
    return SongFeatures(
      songId: map['song_id'] as int,
      normalizedGenre: map['normalized_genre'] as String?,
      subGenre: map['sub_genre'] as String?,
      moodTags: map['mood_tags'] != null
          ? (jsonDecode(map['mood_tags'] as String) as List<dynamic>)
              .map((e) => e.toString())
              .toList()
          : [],
      source: map['source'] as String? ?? 'unknown',
      enrichedAt: map['enriched_at'] != null
          ? DateTime.parse(map['enriched_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'song_id': songId,
      'normalized_genre': normalizedGenre,
      'sub_genre': subGenre,
      'mood_tags': jsonEncode(moodTags),
      'source': source,
      'enriched_at': enrichedAt.toIso8601String(),
    };
  }

  factory SongFeatures.unknown(int songId) {
    return SongFeatures(
      songId: songId,
      source: 'unknown',
      moodTags: [],
      enrichedAt: DateTime.now(),
    );
  }

  bool get isEnriched => source != 'unknown';
}
