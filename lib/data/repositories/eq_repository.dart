import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/eq_config.dart';

class EqRepository extends ChangeNotifier {
  final Map<int, EqConfig> _cache = {};

  Future<Database> get database => AppDatabase.instance.database;

  // ─── Global EQ (SharedPreferences) ────────────────────────

  Future<EqConfig> loadGlobal() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('eq_global_config');
    if (json == null) return EqConfig.flat();
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return EqConfig.fromMap(map);
    } catch (e) {
      debugPrint('[EQ_REPO] loadGlobal parse error: $e');
      return EqConfig.flat();
    }
  }

  Future<void> saveGlobal(EqConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eq_global_config', jsonEncode(config.toMap()));
  }

  Future<void> resetGlobal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('eq_global_config');
  }

  // ─── Per-song EQ (legacy, kept for DB migration compat) ──

  Future<EqConfig?> loadForSong(int songId) async {
    if (_cache.containsKey(songId)) return _cache[songId]!;
    final db = await database;
    final maps = await db.query(
      'eq_configs',
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    if (maps.isEmpty) return null;
    final config = EqConfig.fromMap(maps.first);
    _cache[songId] = config;
    notifyListeners();
    return config;
  }

  Future<void> saveForSong(EqConfig config) async {
    final db = await database;
    await db.insert(
      'eq_configs',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cache[config.songId] = config;
    notifyListeners();
  }

  Future<void> deleteForSong(int songId) async {
    final db = await database;
    await db.delete(
      'eq_configs',
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    _cache.remove(songId);
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
