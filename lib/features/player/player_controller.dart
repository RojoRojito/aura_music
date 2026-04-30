import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/song.dart';
import '../../services/audio_handler.dart';
import '../../services/dynamic_theme_service.dart';
import '../../services/state_persistence_service.dart';
import '../settings/settings_controller.dart';

class PlayerController extends ChangeNotifier {
  final AuraAudioHandler _h;
  final DynamicThemeService _theme = DynamicThemeService.instance;
  final StatePersistenceService _persistence = StatePersistenceService();
  StreamSubscription<void>? _sleepTimerSub;
  StreamSubscription<void>? _queueChangeSub;
  bool _initialized = false;

  PlayerController(this._h);

  Future<void> init(SettingsController settings) async {
    if (_initialized) return;
    _initialized = true;

    await _persistence.init();
    _setupSleepTimer(settings);
    _setupQueuePersistence();
    _restoreQueueIfNeeded();
  }

  void _setupSleepTimer(SettingsController settings) {
    _sleepTimerSub?.cancel();
    _sleepTimerSub = settings.onSleepTimerExpired.listen((_) {
      _h.pause();
      notifyListeners();
    });
  }

  void _setupQueuePersistence() {
    _queueChangeSub?.cancel();
    _queueChangeSub = _h.onQueueChanged.listen((_) {
      _persistence.saveQueueState(_h.songQueue, _h.currentIndex, _h.player.position);
    });
  }

  Future<void> _restoreQueueIfNeeded() async {
    final state = await _persistence.restoreQueueState();
    if (state != null && state.queue.isNotEmpty) {
      await _h.restoreQueue(state.queue, state.currentIndex);
      await _h.seek(state.position);
    }
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
    _queueChangeSub?.cancel();
    super.dispose();
  }
}