import 'dart:math';

import '../../data/models/song_stats.dart';

class UserGenreAffinity {
  final String genre;
  final double score;

  UserGenreAffinity({required this.genre, required this.score});
}

class EngagementScorer {
  static double compute(SongStats stats) {
    final completionRate = stats.completionRate;
    final skipRate = stats.skipRate;

    double baseScore = (stats.playCount * 3.0) +
        (completionRate * 5.0) +
        (stats.isFavorite ? 10.0 : 0.0) -
        (skipRate * 4.0) +
        (stats.repeatCount * 2.0) +
        (stats.playlistAddCount * 1.5);

    double decayFactor = 1.0;
    if (stats.lastPlayed != null) {
      final daysSince = DateTime.now().difference(stats.lastPlayed!).inDays;
      decayFactor = pow(0.97, daysSince).toDouble();
    }

    double decayedScore = baseScore * decayFactor;

    double fatiguePenalty = 0.0;
    if (stats.lastPlayed != null) {
      final hoursSince = DateTime.now().difference(stats.lastPlayed!).inHours;
      if (hoursSince < 1) {
        fatiguePenalty = 8.0;
      } else if (hoursSince < 2) {
        fatiguePenalty = 5.0;
      } else if (hoursSince < 6) {
        fatiguePenalty = 2.0;
      }
    }

    double recencyBonus = 0.0;
    if (stats.lastPlayed != null) {
      final daysSince = DateTime.now().difference(stats.lastPlayed!).inDays;
      if (daysSince == 0) {
        recencyBonus = 3.0;
      } else if (daysSince <= 3) {
        recencyBonus = 2.0;
      } else if (daysSince <= 7) {
        recencyBonus = 1.0;
      }
    }

    double finalScore = decayedScore - fatiguePenalty + recencyBonus;
    return finalScore.clamp(0.0, double.infinity);
  }

  static double computePredicted(String genre, UserGenreAffinity affinity) {
    return affinity.score * 0.5;
  }
}
