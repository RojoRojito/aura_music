import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../models/song_stats.dart';

class StatsRepository extends ChangeNotifier {
  StatsRepository();

  static final StatsRepository instance = StatsRepository._();
  StatsRepository._();

  Future<void> recordPlay({
    required int songId,
    required String title,
    required String artist,
    required double durationSeconds,
    required double listenedSeconds,
    required bool isFavorite,
  }) async {
    final db = await AppDatabase.instance.database;

    final wasSkipped = listenedSeconds < 30.0 && listenedSeconds < durationSeconds * 0.5;
    final now = DateTime.now().toIso8601String();

    await db.insert('play_events', {
      'song_id': songId,
      'title': title,
      'artist': artist,
      'duration_seconds': durationSeconds,
      'listened_seconds': listenedSeconds,
      'was_skipped': wasSkipped ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
      'played_at': now,
    });

    final existing = await db.query(
      'song_stats',
      where: 'song_id = ?',
      whereArgs: [songId],
    );

    if (existing.isNotEmpty) {
      final currentPlayCount = (existing[0]['play_count'] as int?) ?? 0;
      final currentSkipCount = (existing[0]['skip_count'] as int?) ?? 0;
      final currentListened = (existing[0]['total_listened_seconds'] as num?) ?? 0;
      final currentDuration = (existing[0]['total_duration_seconds'] as num?) ?? 0;

      await db.update(
        'song_stats',
        {
          'play_count': currentPlayCount + (wasSkipped ? 0 : 1),
          'skip_count': currentSkipCount + (wasSkipped ? 1 : 0),
          'total_listened_seconds': (currentListened.toDouble()) + listenedSeconds,
          'total_duration_seconds': (currentDuration.toDouble()) + durationSeconds,
          'is_favorite': isFavorite ? 1 : 0,
          'last_played': now,
        },
        where: 'song_id = ?',
        whereArgs: [songId],
      );
    } else {
      await db.insert('song_stats', {
        'song_id': songId,
        'title': title,
        'artist': artist,
        'play_count': wasSkipped ? 0 : 1,
        'skip_count': wasSkipped ? 1 : 0,
        'total_listened_seconds': listenedSeconds,
        'total_duration_seconds': durationSeconds,
        'is_favorite': isFavorite ? 1 : 0,
        'last_played': now,
      });
    }

    notifyListeners();
  }

  Future<List<SongStats>> getAllStats() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('song_stats', orderBy: 'play_count DESC');
    return maps.map((m) => SongStats.fromMap(m)).toList();
  }

  Future<void> updateFavoriteStatus(int songId, bool isFavorite) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'song_stats',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    notifyListeners();
  }

  Future<void> clearOldEvents({int keepDays = 30}) async {
    final db = await AppDatabase.instance.database;
    final cutoff = DateTime.now().subtract(Duration(days: keepDays)).toIso8601String();
    await db.delete('play_events', where: "played_at < ?", whereArgs: [cutoff]);
  }
}