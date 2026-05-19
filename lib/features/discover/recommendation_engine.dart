import 'package:flutter/foundation.dart';
import '../../data/models/song.dart';
import '../../data/models/song_stats.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/stats_repository.dart';
import '../../data/repositories/song_features_repository.dart';
import '../../services/media_scanner.dart';
import 'engagement_scorer.dart';
import 'profile_builder.dart';
import 'content_scorer.dart';

class RecommendationEngine extends ChangeNotifier {
  final StatsRepository statsRepository;
  final SongFeaturesRepository featuresRepository;

  RecommendationEngine(this.statsRepository, this.featuresRepository);

  List<SongStats> _allStats = [];
  List<SongStats> _topPicks = [];
  List<SongStats> _mostPlayed = [];
  UserProfile? _userProfile;
  bool _isLoading = false;

  List<SongStats> get topPicks => _topPicks;
  List<SongStats> get mostPlayed => _mostPlayed;
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get hasData => _topPicks.isNotEmpty || _mostPlayed.isNotEmpty;

  Future<void> compute() async {
    debugPrint('[Engine] 🔄 compute() iniciado');
    _isLoading = true;
    notifyListeners();

    _allStats = await statsRepository.getAllStats();

    await _buildProfile();
    debugPrint('[Engine] 👤 UserProfile: topGenre=${_userProfile?.topGenre} topMood=${_userProfile?.topMood}');

    final featuresMap = await featuresRepository.getAllFeaturesMap();

    final scored = _allStats.map((s) {
      final engagementScore = EngagementScorer.compute(s);

      double contentScore = 0.0;
      final features = featuresMap[s.songId];
      if (features != null && features.isEnriched && _userProfile != null) {
        contentScore = ContentScorer.computeFull(
          features: features,
          artistName: s.artist,
          profile: _userProfile!,
        );
      }

      final combinedScore =
          (engagementScore * 0.60) + (contentScore * 0.40);

      return s.copyWith(
        score: combinedScore,
        engagementScore: engagementScore,
      );
    }).toList();

    _topPicks = scored
        .where((s) => s.playCount > 0 || s.isFavorite)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    _topPicks = _topPicks.take(30).toList();

    _mostPlayed = scored
        .where((s) => s.playCount > 0)
        .toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    _mostPlayed = _mostPlayed.take(10).toList();

    _isLoading = false;
    debugPrint('[Engine] ✅ compute() completado');
    debugPrint('[Engine] 📊 topPicks: ${_topPicks.length} canciones');
    if (_topPicks.isNotEmpty) {
      debugPrint('[Engine] 🥇 #1: ${_topPicks.first.title} | score: ${_topPicks.first.score.toStringAsFixed(2)}');
    }
    if (_topPicks.length >= 2) {
      debugPrint('[Engine] 🥈 #2: ${_topPicks[1].title} | score: ${_topPicks[1].score.toStringAsFixed(2)}');
    }
    if (_topPicks.length >= 3) {
      debugPrint('[Engine] 🥉 #3: ${_topPicks[2].title} | score: ${_topPicks[2].score.toStringAsFixed(2)}');
    }
    notifyListeners();
  }

  Future<void> _buildProfile() async {
    try {
      _userProfile = await ProfileBuilder.instance.build(
        allStats: _allStats,
        featuresRepo: featuresRepository,
      );
    } catch (e) {
      debugPrint('[RecommendationEngine] Failed to build profile: $e');
      _userProfile = null;
    }
  }

  Future<void> refresh() => compute();

  Future<List<Song>> statsToSongs(
      List<SongStats> stats, MediaScanner scanner) async {
    final songs = <Song>[];
    for (final stat in stats) {
      final song = await scanner.getSongById(stat.songId);
      if (song != null) songs.add(song);
    }
    return songs;
  }
}
