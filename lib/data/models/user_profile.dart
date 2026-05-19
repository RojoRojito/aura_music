import 'dart:convert';

class UserProfile {
  final Map<String, double> genreAffinities;
  final Map<String, double> moodAffinities;
  final Map<String, double> artistAffinities;
  final Map<int, String> hourlyGenrePreference;
  final List<String> recentSearchMoods;
  final DateTime lastUpdated;
  final int totalSongsAnalyzed;

  const UserProfile({
    this.genreAffinities = const {},
    this.moodAffinities = const {},
    this.artistAffinities = const {},
    this.hourlyGenrePreference = const {},
    this.recentSearchMoods = const [],
    required this.lastUpdated,
    this.totalSongsAnalyzed = 0,
  });

  factory UserProfile.empty() {
    return UserProfile(lastUpdated: DateTime.now());
  }

  String? get topGenre {
    if (genreAffinities.isEmpty) return null;
    return genreAffinities.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  String? get topMood {
    if (moodAffinities.isEmpty) return null;
    return moodAffinities.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  bool get hasData => totalSongsAnalyzed > 0;

  String toJson() {
    final hourlyStringKeys = <String, String>{};
    for (final entry in hourlyGenrePreference.entries) {
      hourlyStringKeys[entry.key.toString()] = entry.value;
    }

    return jsonEncode({
      'genreAffinities': genreAffinities,
      'moodAffinities': moodAffinities,
      'artistAffinities': artistAffinities,
      'hourlyGenrePreference': hourlyStringKeys,
      'recentSearchMoods': recentSearchMoods,
      'lastUpdated': lastUpdated.toIso8601String(),
      'totalSongsAnalyzed': totalSongsAnalyzed,
    });
  }

  factory UserProfile.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;

    final hourlyRaw =
        (map['hourlyGenrePreference'] as Map<String, dynamic>?) ?? {};
    final hourlyParsed = <int, String>{};
    for (final entry in hourlyRaw.entries) {
      final hour = int.tryParse(entry.key);
      if (hour != null) {
        hourlyParsed[hour] = entry.value as String;
      }
    }

    return UserProfile(
      genreAffinities:
          _toDoubleMap(map['genreAffinities'] as Map<String, dynamic>?),
      moodAffinities:
          _toDoubleMap(map['moodAffinities'] as Map<String, dynamic>?),
      artistAffinities:
          _toDoubleMap(map['artistAffinities'] as Map<String, dynamic>?),
      hourlyGenrePreference: hourlyParsed,
      recentSearchMoods:
          (map['recentSearchMoods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.parse(map['lastUpdated'] as String)
          : DateTime.now(),
      totalSongsAnalyzed: (map['totalSongsAnalyzed'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, double> _toDoubleMap(Map<String, dynamic>? raw) {
    if (raw == null) return {};
    return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }
}
