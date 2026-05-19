import 'package:sqflite/sqflite.dart';
import '../../data/database/app_database.dart';
import '../../data/models/song_features.dart';

class SongFeaturesRepository {
  Future<SongFeatures?> getFeatures(int songId) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'song_features',
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    if (maps.isEmpty) return null;
    return SongFeatures.fromMap(maps.first);
  }

  Future<void> saveFeatures(SongFeatures features) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'song_features',
      features.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SongFeatures>> getAllFeatures() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('song_features');
    return maps.map((m) => SongFeatures.fromMap(m)).toList();
  }

  Future<Map<int, SongFeatures>> getAllFeaturesMap() async {
    final all = await getAllFeatures();
    return {for (final f in all) f.songId: f};
  }
}
