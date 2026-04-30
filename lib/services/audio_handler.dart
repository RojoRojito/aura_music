import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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

class AuraAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  List<Song> _queue = [];
  int _currentIndex = 0;
  final _errorController = StreamController<AudioError>.broadcast();
  final _queueChangeController = StreamController<void>.broadcast();

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
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));
    });
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) skipToNext();
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
  List<Song> get songQueue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  AudioPlayer get player => _player;

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
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _loadCurrent();
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
      await _player.setAudioSource(AudioSource.uri(Uri.parse(s.uri)));
      await _player.play();
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

  Future<void> restoreQueue(List<Song> songs, int index) async {
    if (songs.isEmpty) return;
    _queue = List.from(songs);
    _currentIndex = index.clamp(0, _queue.length - 1);
    _queueChangeController.add(null);
    await _loadCurrent();
  }
}
