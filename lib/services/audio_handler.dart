import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import '../data/models/song.dart';

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

enum LoopMode { off, one, all }

enum ProcessingState { idle, loading, buffering, ready, completed }

class NativePlayer {
  static const _channel = MethodChannel('com.daviddev.aura/player');
  static const _eventChannel = EventChannel('com.daviddev.aura/player_events');

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  ProcessingState _processingState = ProcessingState.idle;
  LoopMode _loopMode = LoopMode.off;
  bool _shuffleEnabled = false;
  double _speed = 1.0;
  int _sessionId = 0;

  final _positionController = StreamController<Duration>.broadcast();
  final _bufferedController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _processingStateController = StreamController<ProcessingState>.broadcast();
  final _playbackEventController = StreamController<void>.broadcast();

  NativePlayer() {
    _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (e) => debugPrint('[NativePlayer] EventChannel error: $e'),
    );
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final map = event as Map<dynamic, dynamic>;

    _position = Duration(milliseconds: (map['position'] as int?) ?? 0);
    _duration = Duration(milliseconds: (map['duration'] as int?) ?? 0);
    _playing = (map['playing'] as bool?) ?? false;
    _speed = (map['speed'] as double?) ?? 1.0;
    _sessionId = (map['sessionId'] as int?) ?? 0;

    final stateIndex = (map['processingState'] as int?) ?? 0;
    _processingState = ProcessingState.values[stateIndex.clamp(0, ProcessingState.values.length - 1)];

    final loopIndex = (map['loopMode'] as int?) ?? 0;
    _loopMode = LoopMode.values[loopIndex.clamp(0, LoopMode.values.length - 1)];

    _positionController.add(_position);
    _durationController.add(_duration);
    _playingController.add(_playing);
    _processingStateController.add(_processingState);
    _playbackEventController.add(null);
  }

  Duration get position => _position;
  Duration get duration => _duration;
  bool get playing => _playing;
  ProcessingState get processingState => _processingState;
  LoopMode get loopMode => _loopMode;
  bool get shuffleModeEnabled => _shuffleEnabled;
  double get speed => _speed;
  int get androidAudioSessionId => _sessionId;

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get bufferedPositionStream => _bufferedController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<ProcessingState> get processingStateStream => _processingStateController.stream;
  Stream<void> get playbackEventStream => _playbackEventController.stream;

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        positionStream,
        bufferedPositionStream,
        durationStream,
        (p, b, d) => PositionData(p, b, d ?? Duration.zero),
      );

  Future<void> setAudioSource(String uri) async {
    await _channel.invokeMethod('setAudioSource', {'uri': uri});
  }

  Future<void> play() async {
    await _channel.invokeMethod('play');
  }

  Future<void> pause() async {
    await _channel.invokeMethod('pause');
  }

  Future<void> seek(Duration position) async {
    await _channel.invokeMethod('seek', {'position': position.inMilliseconds});
  }

  Future<void> setLoopMode(LoopMode mode) async {
    _loopMode = mode;
    await _channel.invokeMethod('setLoopMode', {'mode': mode.index});
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    _shuffleEnabled = enabled;
    await _channel.invokeMethod('setShuffleMode', {'enabled': enabled});
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _channel.invokeMethod('setSpeed', {'speed': speed});
  }

  Future<void> dispose() async {
    await _channel.invokeMethod('dispose');
    _positionController.close();
    _bufferedController.close();
    _durationController.close();
    _playingController.close();
    _processingStateController.close();
    _playbackEventController.close();
  }
}

class AuraAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final NativePlayer _player = NativePlayer();
  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _sessionIdSent = false;
  bool _isSkipping = false;
  final _errorController = StreamController<AudioError>.broadcast();
  final _queueChangeController = StreamController<void>.broadcast();
  void Function(int songId)? onSongChanged;
  void Function(int sessionId)? onAudioSessionId;

  Stream<AudioError> get errorStream => _errorController.stream;
  Stream<void> get onQueueChanged => _queueChangeController.stream;

  AuraAudioHandler() { _init(); }

  void _init() {
    _player.playbackEventStream.listen((_) {
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const { MediaAction.seek },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: {
          ProcessingState.idle:      AudioProcessingState.idle,
          ProcessingState.loading:   AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready:     AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.position,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));
    });
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.ready && !_sessionIdSent) {
        _sessionIdSent = true;
        final sessionId = _player.androidAudioSessionId;
        if (sessionId != 0) {
          debugPrint('[AudioHandler] sessionId=$sessionId');
          onAudioSessionId?.call(sessionId);
        }
      }
      if (state == ProcessingState.completed && !_isSkipping) skipToNext();
    });
  }

  Stream<PositionData> get positionDataStream => _player.positionDataStream;
  Stream<bool> get playingStream => _player.playingStream;

  Song? get currentSong => _queue.isNotEmpty ? _queue[_currentIndex] : null;
  List<Song> get songQueue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  NativePlayer get player => _player;

  @override Future<void> play()  => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final m = {
      AudioServiceRepeatMode.none:  LoopMode.off,
      AudioServiceRepeatMode.one:   LoopMode.one,
      AudioServiceRepeatMode.all:   LoopMode.all,
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

  Future<void> setShuffleEnabled(bool e) => _player.setShuffleModeEnabled(e);

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
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await _loadCurrent();
    }
  }

  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    _queue = queue ?? [song];
    _currentIndex = index ?? _queue.indexOf(song);
    if (_currentIndex < 0) { _currentIndex = 0; _queue.insert(0, song); }
    _queueChangeController.add(null);
    await _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    if (_queue.isEmpty) return;
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
      await _player.setAudioSource(s.uri);
      await _player.play();
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
    _queueChangeController.add(null);
  }

  Future<void> playNext(Song song) async {
    _queue.insert(_currentIndex + 1, song);
    _queueChangeController.add(null);
  }

  Future<void> removeFromQueue(int i) async {
    if (i == _currentIndex) return;
    _queue.removeAt(i);
    if (i < _currentIndex) _currentIndex--;
    _queueChangeController.add(null);
  }

  Future<void> restoreQueue(List<Song> songs, int index, {bool notify = true}) async {
    if (songs.isEmpty) return;
    _queue = List.from(songs);
    _currentIndex = index.clamp(0, _queue.length - 1);
    if (notify) _queueChangeController.add(null);
    await _loadCurrent();
  }
}
