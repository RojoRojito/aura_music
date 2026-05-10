import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/eq_config.dart';

class EqRepository extends ChangeNotifier {
  EqConfig? _currentConfig;
  EqConfig? get currentConfig => _currentConfig;

  Future<Database> get database => AppDatabase.instance.database;

  Future<EqConfig?> loadForSong(int songId) async {
    final db = await database;
    final maps = await db.query(
      'eq_configs',
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    if (maps.isEmpty) return null;
    _currentConfig = EqConfig.fromMap(maps.first);
    notifyListeners();
    return _currentConfig;
  }

  Future<void> saveForSong(EqConfig config) async {
    final db = await database;
    await db.insert(
      'eq_configs',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _currentConfig = config;
    notifyListeners();
  }

  Future<void> deleteForSong(int songId) async {
    final db = await database;
    await db.delete(
      'eq_configs',
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    if (_currentConfig?.songId == songId) {
      _currentConfig = null;
    }
    notifyListeners();
  }

  Future<EqConfig?> getOrCreate(int songId) async {
    final config = await loadForSong(songId);
    return config;
  }

  Future<bool> hasConfig(int songId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT 1 FROM eq_configs WHERE song_id = ? LIMIT 1',
      [songId],
    );
    return result.isNotEmpty;
  }

  Future<List<EqConfig>> getAllConfigs() async {
    final db = await database;
    final maps = await db.query('eq_configs');
    return maps.map((m) => EqConfig.fromMap(m)).toList();
  }

  Future<void> clearUnusedConfigs(List<int> validSongIds) async {
    final allConfigs = await getAllConfigs();
    for (final config in allConfigs) {
      if (!validSongIds.contains(config.songId)) {
        await deleteForSong(config.songId);
      }
    }
  }
}