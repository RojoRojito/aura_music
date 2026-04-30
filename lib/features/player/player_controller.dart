import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/song.dart';
import '../../services/audio_handler.dart';
import '../../services/dynamic_theme_service.dart';
import '../settings/settings_controller.dart';

class PlayerController extends ChangeNotifier {
  final AuraAudioHandler _h;
  final DynamicThemeService _theme = DynamicThemeService.instance;
  SettingsController? _settings;
  StreamSubscription<void>? _sleepTimerSub;

  PlayerController(this._h);

  void initSleepTimer(SettingsController settings) {
    _settings = settings;
    _sleepTimerSub?.cancel();
    _sleepTimerSub = settings.onSleepTimerExpired.listen((_) {
      _h.pause();
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

  @override
  void dispose() {
    _sleepTimerSub?.cancel();
    super.dispose();
  }
}