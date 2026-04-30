import 'package:intl/intl.dart';

class PlayEntry {
  final int? id;
  final int songId;
  final DateTime playedAt;
  final int playDurationMs;
  final bool skipped;

  const PlayEntry({
    this.id,
    required this.songId,
    required this.playedAt,
    required this.playDurationMs,
    this.skipped = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'song_id': songId,
      'played_at': playedAt.toIso8601String(),
      'play_duration': playDurationMs,
      'skipped': skipped ? 1 : 0,
    };
  }

  factory PlayEntry.fromMap(Map<String, dynamic> map) {
    return PlayEntry(
      id: map['id'] as int?,
      songId: map['song_id'] as int,
      playedAt: DateTime.parse(map['played_at'] as String),
      playDurationMs: map['play_duration'] as int,
      skipped: (map['skipped'] as int?) == 1,
    );
  }

  PlayEntry copyWith({
    int? id,
    int? songId,
    DateTime? playedAt,
    int? playDurationMs,
    bool? skipped,
  }) {
    return PlayEntry(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      playedAt: playedAt ?? this.playedAt,
      playDurationMs: playDurationMs ?? this.playDurationMs,
      skipped: skipped ?? this.skipped,
    );
  }
}
