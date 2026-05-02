import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/eq_config.dart';

class EqRepository extends ChangeNotifier {
  static Database? _db;
  EqConfig? _currentConfig;
  EqConfig? get currentConfig => _currentConfig;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'aura.db');
    return openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE eq_configs (
          song_id INTEGER PRIMARY KEY,
          band_levels TEXT NOT NULL,
          bass_boost INTEGER DEFAULT 0,
          virtualizer INTEGER DEFAULT 0,
          enabled INTEGER DEFAULT 1,
          preset_name TEXT)
      ''');
    });
  }

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

  /// Carga la configuración para una canción o retorna null si no existe
  Future<EqConfig?> getOrCreate(int songId) async {
    final config = await loadForSong(songId);
    return config;
  }

  /// Verifica si existe configuración para una canción
  Future<bool> hasConfig(int songId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT 1 FROM eq_configs WHERE song_id = ? LIMIT 1',
      [songId],
    );
    return result.isNotEmpty;
  }

  /// Obtiene todas las configuraciones guardadas
   Future<List<EqConfig>> getAllConfigs() async {
    final db = await database;
    final maps = await db.query('eq_configs');
    return maps.map((m) => EqConfig.fromMap(m)).toList();
  }

  /// Limpia configuraciones antiguas (opcional, para mantenimiento)
  Future<void> clearUnusedConfigs(List<int> validSongIds) async {
    final allConfigs = await getAllConfigs();
    for (final config in allConfigs) {
      if (!validSongIds.contains(config.songId)) {
        await deleteForSong(config.songId);
      }
    }
  }
}
