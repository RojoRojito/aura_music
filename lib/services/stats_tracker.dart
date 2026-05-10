import 'dart:async';
import '../data/repositories/stats_repository.dart';
import '../data/repositories/favorites_repository.dart';
import '../../data/models/song.dart';
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
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  StatsTracker({
    required this.statsRepository,
    required this.audioHandler,
  });

  Future<void> init(FavoritesRepository favRepo) async {
    final originalCallback = audioHandler.onSongChanged;
    audioHandler.onSongChanged = (songId) async {
      await _onSongChanged(songId, favRepo);
      if (originalCallback != null) {
        originalCallback(songId);
      }
    };

    _positionSub = audioHandler.player.positionStream.listen((pos) {
      _listenedSeconds = pos.inSeconds.toDouble();
    });

    _durationSub = audioHandler.player.durationStream.listen((dur) {
      _currentDuration = dur?.inSeconds.toDouble() ?? 0;
    });
  }

  Future<void> _onSongChanged(int songId, FavoritesRepository favRepo) async {
    if (_currentSongId != null && _currentSongId != songId) {
      await _flushCurrent();
    }

    final song = audioHandler.currentSong;
    if (song != null) {
      _currentSongId = song.id;
      _currentTitle = song.title;
      _currentArtist = song.artist ?? '';
      _isFavorite = favRepo.isFavorite(songId);
    }

    _listenedSeconds = 0;
    _currentDuration = song?.duration.toDouble() ?? 0;
  }

  Future<void> _flushCurrent() async {
    if (_currentSongId == null) return;

    await statsRepository.recordPlay(
      songId: _currentSongId!,
      title: _currentTitle,
      artist: _currentArtist,
      durationSeconds: _currentDuration,
      listenedSeconds: _listenedSeconds,
      isFavorite: _isFavorite,
    );
  }

  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
  }
}