import 'package:flutter/foundation.dart';
import '../../data/models/song_stats.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/song_features_repository.dart';
import 'engagement_scorer.dart';

class ProfileBuilder {
  static ProfileBuilder? _instance;
  static ProfileBuilder get instance => _instance ??= ProfileBuilder._();
  ProfileBuilder._();

  Future<UserProfile> build({
    required List<SongStats> allStats,
    required SongFeaturesRepository featuresRepo,
  }) async {
    final genreRaw = <String, double>{};
    final moodRaw = <String, double>{};
    final artistRaw = <String, double>{};
    final hourlyRaw = <int, Map<String, double>>{};

    for (final stat in allStats) {
      if (stat.playCount == 0) continue;

      final features = await featuresRepo.getFeatures(stat.songId);
      if (features == null || !features.isEnriched) continue;

      final weight = EngagementScorer.compute(stat);
      if (weight <= 0) continue;

      if (features.normalizedGenre != null) {
        genreRaw[features.normalizedGenre!] =
            (genreRaw[features.normalizedGenre!] ?? 0) + weight;
      }

      for (final mood in features.moodTags) {
        moodRaw[mood] = (moodRaw[mood] ?? 0) + weight;
      }

      final artistKey = stat.artist.toLowerCase().trim();
      artistRaw[artistKey] = (artistRaw[artistKey] ?? 0) + weight;

      if (stat.lastPlayed != null) {
        final hour = stat.lastPlayed!.hour;
        hourlyRaw[hour] ??= {};
        if (features.normalizedGenre != null) {
          hourlyRaw[hour]![features.normalizedGenre!] =
              (hourlyRaw[hour]![features.normalizedGenre!] ?? 0) + weight;
        }
      }
    }

    debugPrint('[Profile] 👤 Perfil construido:');
    debugPrint('[Profile]   Géneros: ${_normalize(genreRaw)}');
    debugPrint('[Profile]   Moods: ${_normalize(moodRaw)}');
    debugPrint('[Profile]   Top artista: ${artistRaw.isEmpty ? "ninguno" : artistRaw.entries.reduce((a,b) => a.value > b.value ? a : b).key}');
    debugPrint('[Profile]   Canciones analizadas: ${allStats.where((s) => s.playCount > 0).length}');

    return UserProfile(
      genreAffinities: _normalize(genreRaw),
      moodAffinities: _normalize(moodRaw),
      artistAffinities: _normalize(artistRaw),
      hourlyGenrePreference: _buildHourlyPreference(hourlyRaw),
      lastUpdated: DateTime.now(),
      totalSongsAnalyzed: allStats.where((s) => s.playCount > 0).length,
    );
  }

  Map<String, double> _normalize(Map<String, double> raw) {
    if (raw.isEmpty) return {};
    final maxVal = raw.values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return {};
    return raw.map((k, v) => MapEntry(k, (v / maxVal * 10.0)));
  }

  Map<int, String> _buildHourlyPreference(
      Map<int, Map<String, double>> hourlyRaw) {
    final result = <int, String>{};
    for (final entry in hourlyRaw.entries) {
      if (entry.value.isEmpty) continue;
      final topGenre = entry.value.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      result[entry.key] = topGenre;
    }
    return result;
  }
}
