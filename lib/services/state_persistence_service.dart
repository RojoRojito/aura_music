import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/song.dart';

class QueueState {
  final List<Song> queue;
  final int currentIndex;
  final Duration position;
  final DateTime timestamp;

  const QueueState({
    required this.queue,
    required this.currentIndex,
    required this.position,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'queue': queue.map((s) => s.toJson()).toList(),
    'currentIndex': currentIndex,
    'position': position.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
  };

  factory QueueState.fromJson(Map<String, dynamic> json) => QueueState(
    queue: (json['queue'] as List).map((s) => Song.fromJson(s)).toList(),
    currentIndex: json['currentIndex'] as int,
    position: Duration(milliseconds: json['position'] as int),
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  bool get isStale => DateTime.now().difference(timestamp).inHours > 24;
}

class StatePersistenceService {
  static const String _keyQueue = 'queue_state';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveQueueState(List<Song> queue, int currentIndex, Duration position) async {
    if (queue.isEmpty) return;
    _prefs ??= await SharedPreferences.getInstance();

    final state = QueueState(
      queue: queue,
      currentIndex: currentIndex,
      position: position,
      timestamp: DateTime.now(),
    );

    await _prefs!.setString(_keyQueue, jsonEncode(state.toJson()));
  }

  Future<QueueState?> restoreQueueState() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_keyQueue);
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final state = QueueState.fromJson(json);
      if (state.isStale) {
        await clearQueueState();
        return null;
      }
      return state;
    } catch (_) {
      await clearQueueState();
      return null;
    }
  }

  Future<void> clearQueueState() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_keyQueue);
  }
}