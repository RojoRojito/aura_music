import '../../data/models/song_features.dart';
import '../../data/models/user_profile.dart';

class ContentScorer {
  static double compute({
    required SongFeatures features,
    required UserProfile profile,
  }) {
    if (!features.isEnriched) return 0.0;

    final genreScore =
        profile.genreAffinities[features.normalizedGenre] ?? 0.0;

    double moodScore = 0.0;
    if (features.moodTags.isNotEmpty) {
      final moodSum = features.moodTags
          .map((m) => profile.moodAffinities[m] ?? 0.0)
          .reduce((a, b) => a + b);
      moodScore = moodSum / features.moodTags.length;
    }

    double artistScore = 0.0;

    return ((genreScore * 0.40) + (moodScore * 0.35) + (artistScore * 0.25))
        .clamp(0.0, 10.0);
  }

  static double computeFull({
    required SongFeatures features,
    required String artistName,
    required UserProfile profile,
  }) {
    if (!features.isEnriched) return 0.0;

    final genreScore =
        profile.genreAffinities[features.normalizedGenre] ?? 0.0;

    double moodScore = 0.0;
    if (features.moodTags.isNotEmpty) {
      final moodSum = features.moodTags
          .map((m) => profile.moodAffinities[m] ?? 0.0)
          .reduce((a, b) => a + b);
      moodScore = moodSum / features.moodTags.length;
    }

    final artistKey = artistName.toLowerCase().trim();
    final artistScore = profile.artistAffinities[artistKey] ?? 0.0;

    return ((genreScore * 0.40) + (moodScore * 0.35) + (artistScore * 0.25))
        .clamp(0.0, 10.0);
  }

  static double computePredicted({
    required SongFeatures features,
    required String artistName,
    required UserProfile profile,
  }) {
    final full = computeFull(
      features: features,
      artistName: artistName,
      profile: profile,
    );
    return full * 0.7;
  }
}
