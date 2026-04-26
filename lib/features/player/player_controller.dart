import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/song.dart';
import '../../services/audio_handler.dart';
import '../../services/dynamic_theme_service.dart';

class PlayerController extends ChangeNotifier {
  final AuraAudioHandler _h;
  final DynamicThemeService _theme = DynamicThemeService.instance;

  PlayerController(this._h) {
    _h.playingStream.listen((_) => notifyListeners());
    _h.mediaItem.listen((_) {
      if (_h.currentSong?.albumId != null) {
        _theme.updateFromAlbumArt(_h.currentSong!.albumId!);
      }
      notifyListeners();
    });
  }

  Song? get currentSong        => _h.currentSong;
  bool get isPlaying           => _h.player.playing;
  Stream<PositionData> get pos => _h.positionDataStream;
  List<Song> get queue         => _h.songQueue;
  int get currentIndex         => _h.currentIndex;

  Color get accentColor => _theme.accentColor;

  Future<void> playSong(Song s, {List<Song>? queue}) async {
    await _h.playSong(s, queue: queue);
    notifyListeners();
  }

  Future<void> togglePlay() async {
    isPlaying ? await _h.pause() : await _h.play();
    notifyListeners();
  }

  Future<void> next()                => _h.skipToNext();
  Future<void> previous()            => _h.skipToPrevious();
  Future<void> seek(Duration p)      => _h.seek(p);
  Future<void> addToQueue(Song s)    => _h.addToQueue(s);
  Future<void> playNext(Song s)      => _h.playNext(s);
  Future<void> setRepeat(LoopMode m) => _h.setRepeatLoopMode(m);
  Future<void> setShuffle(bool e)    => _h.setShuffleEnabled(e);
  Future<void> setSpeed(double s)    => _h.setSpeed(s);
}
