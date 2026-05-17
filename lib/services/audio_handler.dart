import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../data/models/song.dart';

export 'package:just_audio/just_audio.dart' show LoopMode;

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  const PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioError {
  final String message;
  final bool isRecoverable;
  const AudioError(this.message, {this.isRecoverable = true});
}

class AuraAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  List<Song> _queue = [];
  List<Song> _displayQueue = [];
  int _currentIndex = 0;
  bool _sessionIdSent = false;
  bool _isSkipping = false;
  bool _shuffleEnabled = false;
  List<int> _shuffleMap = [];
  final _errorController = StreamController<AudioError>.broadcast();
  final _queueChangeController = StreamController<void>.broadcast();
  void Function(int songId)? onSongChanged;
  void Function(int sessionId)? onAudioSessionId;

  Stream<AudioError> get errorStream => _errorController.stream;
  Stream<void> get onQueueChanged => _queueChangeController.stream;

  AuraAudioHandler() {
    debugPrint('[AudioHandler] Constructor called');
    _init();
  }

  void _init() {
    debugPrint('[AudioHandler] _init() called');
    _player.playbackEventStream.listen((event) {
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));
    });

    _player.processingStateStream.listen((state) {
      debugPrint('[AudioHandler] processingState=$state, _sessionIdSent=$_sessionIdSent');
      if (state == ProcessingState.completed && !_isSkipping) skipToNext();
    });

    _player.androidAudioSessionId.listen((sessionId) {
      debugPrint('[AudioHandler] androidAudioSessionId stream: $sessionId');
      if (sessionId != null && sessionId != 0 && !_sessionIdSent) {
        _sessionIdSent = true;
        debugPrint('[AudioHandler] sessionId VALIDO=$sessionId');
        debugPrint('[AudioHandler] onAudioSessionId callback is null: ${onAudioSessionId == null}');
        try {
          onAudioSessionId?.call(sessionId);
          debugPrint('[AudioHandler] onAudioSessionId callback executed OK');
        } catch (e) {
          debugPrint('[AudioHandler] onAudioSessionId callback ERROR: $e');
        }
      }
    });
  }

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (p, b, d) => PositionData(p, b, d ?? Duration.zero),
      );

  Stream<bool> get playingStream => _player.playingStream;

  Song? get currentSong => _queue.isNotEmpty ? _queue[_currentIndex] : null;
  List<Song> get songQueue => List.unmodifiable(_displayQueue.isNotEmpty ? _displayQueue : _queue);
  int get currentIndex => _currentIndex;
  AudioPlayer get player => _player;
  bool get shuffleEnabled => _shuffleEnabled;

  void _updateDisplayQueue() {
    if (_shuffleEnabled && _queue.isNotEmpty) {
      _displayQueue = _shuffleMap.map((i) => _queue[i]).toList();
    } else {
      _displayQueue = List.from(_queue);
    }
    _queueChangeController.add(null);
  }

  void _buildShuffleMap() {
    _shuffleMap = List.generate(_queue.length, (i) => i);
    final rng = Random();
    for (var i = _shuffleMap.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = _shuffleMap[i];
      _shuffleMap[i] = _shuffleMap[j];
      _shuffleMap[j] = tmp;
    }
    final currentIdx = _shuffleMap.indexOf(_currentIndex);
    if (currentIdx > 0) {
      final tmp = _shuffleMap[0];
      _shuffleMap[0] = _shuffleMap[currentIdx];
      _shuffleMap[currentIdx] = tmp;
    }
    _currentIndex = _shuffleMap[0];
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final m = {
      AudioServiceRepeatMode.none: LoopMode.off,
      AudioServiceRepeatMode.one: LoopMode.one,
      AudioServiceRepeatMode.all: LoopMode.all,
      AudioServiceRepeatMode.group: LoopMode.all,
    }[repeatMode] ?? LoopMode.off;
    await _player.setLoopMode(m);
  }

  Future<void> setRepeatLoopMode(LoopMode m) => _player.setLoopMode(m);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _player.setShuffleModeEnabled(
        shuffleMode != AudioServiceShuffleMode.none);
  }

  Future<void> setShuffleEnabled(bool e) async {
    _shuffleEnabled = e;
    await _player.setShuffleModeEnabled(e);
    if (e) {
      _buildShuffleMap();
    } else {
      _shuffleMap = [];
    }
    _updateDisplayQueue();
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> skipToNext() async {
    if (_isSkipping) return;
    _isSkipping = true;
    try {
      if (_queue.isEmpty) return;
      final currentLoop = _player.loopMode;
      if (currentLoop == LoopMode.one) {
        await _player.seek(Duration.zero);
        await _player.play();
      } else if (_shuffleEnabled && _shuffleMap.isNotEmpty) {
        final currentShuffleIdx = _shuffleMap.indexOf(_currentIndex);
        if (currentShuffleIdx < _shuffleMap.length - 1) {
          _currentIndex = _shuffleMap[currentShuffleIdx + 1];
          await _loadCurrent();
        } else if (currentLoop == LoopMode.all) {
          _currentIndex = _shuffleMap[0];
          await _loadCurrent();
        }
      } else if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        await _loadCurrent();
      } else if (currentLoop == LoopMode.all) {
        _currentIndex = 0;
        await _loadCurrent();
      }
    } finally {
      _isSkipping = false;
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_shuffleEnabled && _shuffleMap.isNotEmpty) {
      final currentShuffleIdx = _shuffleMap.indexOf(_currentIndex);
      if (currentShuffleIdx > 0) {
        _currentIndex = _shuffleMap[currentShuffleIdx - 1];
        await _loadCurrent();
      }
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await _loadCurrent();
    }
  }

  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    _queue = queue ?? [song];
    _currentIndex = index ?? _queue.indexOf(song);
    if (_currentIndex < 0) {
      _currentIndex = 0;
      _queue.insert(0, song);
    }
    if (_shuffleEnabled) _buildShuffleMap();
    _updateDisplayQueue();
    await _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    if (_queue.isEmpty) return;
    debugPrint('[AudioHandler] _loadCurrent: song=${_queue[_currentIndex].title}');
    _sessionIdSent = false;
    final s = _queue[_currentIndex];
    mediaItem.add(MediaItem(
      id: s.uri,
      title: s.title,
      artist: s.artist,
      album: s.album,
      duration: Duration(milliseconds: s.duration),
      artUri: s.albumArtUri != null ? Uri.parse(s.albumArtUri!) : null,
    ));
    try {
      debugPrint('[AudioHandler] _loadCurrent: setAudioSource...');
      await _player.setAudioSource(AudioSource.uri(Uri.parse(s.uri)));
      debugPrint('[AudioHandler] _loadCurrent: play()...');
      await _player.play();
      debugPrint('[AudioHandler] _loadCurrent: play() started, onSongChanged...');
      onSongChanged?.call(s.id);
    } catch (e) {
      _errorController.add(AudioError(
        'No se pudo reproducir: ${s.title}',
        isRecoverable: true,
      ));
      debugPrint('Audio error: $e');
      if (_currentIndex < _queue.length - 1) {
        skipToNext();
      }
    }
  }

  Future<void> addToQueue(Song song) async {
    _queue.add(song);
    if (_shuffleEnabled) _buildShuffleMap();
    _updateDisplayQueue();
  }

  Future<void> playNext(Song song) async {
    _queue.insert(_currentIndex + 1, song);
    if (_shuffleEnabled) _buildShuffleMap();
    _updateDisplayQueue();
  }

  Future<void> removeFromQueue(int i) async {
    if (i == _currentIndex) return;
    final actualIdx = _shuffleEnabled ? _shuffleMap[i] : i;
    _queue.removeAt(actualIdx);
    if (actualIdx < _currentIndex) _currentIndex--;
    if (_shuffleEnabled) _buildShuffleMap();
    _updateDisplayQueue();
  }

  Future<void> restoreQueue(List<Song> songs, int index,
      {bool notify = true}) async {
    if (songs.isEmpty) return;
    _queue = List.from(songs);
    _currentIndex = index.clamp(0, _queue.length - 1);
    if (_shuffleEnabled) _buildShuffleMap();
    if (notify) _updateDisplayQueue();
    await _loadCurrent();
  }
}
