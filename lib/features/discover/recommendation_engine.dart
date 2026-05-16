import 'package:flutter/foundation.dart';
import '../../data/models/song.dart';
import '../../data/models/song_stats.dart';
import '../../data/repositories/stats_repository.dart';
import '../../services/media_scanner.dart';

class RecommendationEngine extends ChangeNotifier {
  final StatsRepository statsRepository;

  RecommendationEngine(this.statsRepository);

  List<SongStats> _allStats = [];
  List<SongStats> _topPicks = [];
  List<SongStats> _mostPlayed = [];
  bool _isLoading = false;

  List<SongStats> get topPicks => _topPicks;
  List<SongStats> get mostPlayed => _mostPlayed;
  bool get isLoading => _isLoading;
  bool get hasData => _topPicks.isNotEmpty || _mostPlayed.isNotEmpty;

  Future<void> compute() async {
    _isLoading = true;
    notifyListeners();

    _allStats = await statsRepository.getAllStats();

    final scored = _allStats.map((s) => s.copyWith(score: s.computeScore())).toList();

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
    notifyListeners();
  }

  Future<void> refresh() => compute();

  Future<List<Song>> statsToSongs(List<SongStats> stats, MediaScanner scanner) async {
    final songs = <Song>[];
    for (final stat in stats) {
      final song = await scanner.getSongById(stat.songId);
      if (song != null) songs.add(song);
    }
    return songs;
  }
}