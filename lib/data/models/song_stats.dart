class SongStats {
  final int songId;
  final String title;
  final String artist;
  final int playCount;
  final int skipCount;
  final double totalListenedSeconds;
  final double totalDurationSeconds;
  final bool isFavorite;
  final DateTime? lastPlayed;
  final double score;
  final int repeatCount;
  final int playlistAddCount;
  final double engagementScore;

  SongStats({
    required this.songId,
    required this.title,
    required this.artist,
    this.playCount = 0,
    this.skipCount = 0,
    this.totalListenedSeconds = 0.0,
    this.totalDurationSeconds = 0.0,
    this.isFavorite = false,
    this.lastPlayed,
    this.score = 0.0,
    this.repeatCount = 0,
    this.playlistAddCount = 0,
    this.engagementScore = 0.0,
  });

  factory SongStats.fromMap(Map<String, dynamic> map) {
    return SongStats(
      songId: map['song_id'] as int,
      title: map['title'] as String,
      artist: map['artist'] as String,
      playCount: map['play_count'] as int? ?? 0,
      skipCount: map['skip_count'] as int? ?? 0,
      totalListenedSeconds:
          (map['total_listened_seconds'] as num?)?.toDouble() ?? 0.0,
      totalDurationSeconds:
          (map['total_duration_seconds'] as num?)?.toDouble() ?? 0.0,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      lastPlayed: map['last_played'] != null
          ? DateTime.parse(map['last_played'] as String)
          : null,
      repeatCount: map['repeat_count'] as int? ?? 0,
      playlistAddCount: map['playlist_add_count'] as int? ?? 0,
      engagementScore:
          (map['engagement_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'song_id': songId,
      'title': title,
      'artist': artist,
      'play_count': playCount,
      'skip_count': skipCount,
      'total_listened_seconds': totalListenedSeconds,
      'total_duration_seconds': totalDurationSeconds,
      'is_favorite': isFavorite ? 1 : 0,
      'last_played': lastPlayed?.toIso8601String(),
      'repeat_count': repeatCount,
      'playlist_add_count': playlistAddCount,
      'engagement_score': engagementScore,
    };
  }

  double get completionRate {
    if (totalDurationSeconds == 0) return 0.0;
    return (totalListenedSeconds / totalDurationSeconds).clamp(0.0, 1.0);
  }

  double get skipRate {
    final total = playCount + skipCount;
    if (total == 0) return 0.0;
    return skipCount / total;
  }

  SongStats copyWith({
    int? songId,
    String? title,
    String? artist,
    int? playCount,
    int? skipCount,
    double? totalListenedSeconds,
    double? totalDurationSeconds,
    bool? isFavorite,
    DateTime? lastPlayed,
    double? score,
    int? repeatCount,
    int? playlistAddCount,
    double? engagementScore,
  }) {
    return SongStats(
      songId: songId ?? this.songId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      playCount: playCount ?? this.playCount,
      skipCount: skipCount ?? this.skipCount,
      totalListenedSeconds:
          totalListenedSeconds ?? this.totalListenedSeconds,
      totalDurationSeconds:
          totalDurationSeconds ?? this.totalDurationSeconds,
      isFavorite: isFavorite ?? this.isFavorite,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      score: score ?? this.score,
      repeatCount: repeatCount ?? this.repeatCount,
      playlistAddCount: playlistAddCount ?? this.playlistAddCount,
      engagementScore: engagementScore ?? this.engagementScore,
    );
  }
}
