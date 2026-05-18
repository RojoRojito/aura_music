import 'dart:async';
import '../data/repositories/stats_repository.dart';
import '../data/repositories/favorites_repository.dart';
import 'audio_handler.dart';

class StatsTracker {
  final StatsRepository statsRepository;
  final AuraAudioHandler audioHandler;

  int? _currentSongId;
  String _currentTitle = '';
  String _currentArtist = '';
  double _currentDuration = 0;
  double _listenedSeconds = 0;
  bool _isFavorite = false;
  int? _lastFinishedSongId;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  FavoritesRepository? _favRepo;

  StatsTracker({
    required this.statsRepository,
    required this.audioHandler,
  });

  Future<void> init(FavoritesRepository favRepo) async {
    _favRepo = favRepo;

    _positionSub = audioHandler.player.positionStream.listen((pos) {
      _listenedSeconds = pos.inSeconds.toDouble();
    });

    _durationSub = audioHandler.player.durationStream.listen((dur) {
      _currentDuration = dur?.inSeconds.toDouble() ?? 0;
    });

    final song = audioHandler.currentSong;
    if (song != null) {
      _currentSongId = song.id;
      _currentTitle = song.title;
      _currentArtist = song.artist;
      _currentDuration = song.duration.toDouble();
      _isFavorite = favRepo.isFavorite(song.id);
    }
  }

  Future<void> handleSongChanged(int songId) async {
    if (_currentSongId != null && _currentSongId != songId) {
      final completionRate = _currentDuration > 0
          ? _listenedSeconds / _currentDuration
          : 0.0;

      if (completionRate >= 0.90) {
        _lastFinishedSongId = _currentSongId;
      }

      final isRepeat = songId == _lastFinishedSongId;
      await _flushCurrent(isRepeat: isRepeat);

      if (isRepeat) {
        _lastFinishedSongId = null;
      }
    }

    final song = audioHandler.currentSong;
    if (song != null) {
      _currentSongId = song.id;
      _currentTitle = song.title;
      _currentArtist = song.artist;
      _isFavorite = _favRepo?.isFavorite(songId) ?? false;
    }

    _listenedSeconds = 0;
    _currentDuration = song?.duration.toDouble() ?? 0;
  }

  Future<void> _flushCurrent({bool isRepeat = false}) async {
    if (_currentSongId == null) return;

    await statsRepository.recordPlay(
      songId: _currentSongId!,
      title: _currentTitle,
      artist: _currentArtist,
      durationSeconds: _currentDuration,
      listenedSeconds: _listenedSeconds,
      isFavorite: _isFavorite,
      isRepeat: isRepeat,
    );
  }

  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
  }
}
