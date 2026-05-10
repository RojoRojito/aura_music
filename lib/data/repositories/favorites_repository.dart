import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/song.dart';

class FavoritesRepository extends ChangeNotifier {
  static Database? _db;
  final Set<int> _favoriteIds = {};

  Set<int> get favoriteIds => _favoriteIds;

  bool isFavorite(int songId) => _favoriteIds.contains(songId);

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'aura.db');
    return openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''CREATE TABLE IF NOT EXISTS favorites (
        song_id INTEGER PRIMARY KEY)''');
    });
  }

  Future<void> loadFavorites() async {
    final db = await database;
    final maps = await db.query('favorites');
    _favoriteIds.clear();
    for (final m in maps) {
      _favoriteIds.add(m['song_id'] as int);
    }
    notifyListeners();
  }

  Future<void> toggleFavorite(int songId) async {
    final db = await database;
    if (_favoriteIds.contains(songId)) {
      await db.delete('favorites', where: 'song_id = ?', whereArgs: [songId]);
      _favoriteIds.remove(songId);
    } else {
      await db.insert('favorites', {'song_id': songId});
      _favoriteIds.add(songId);
    }
    notifyListeners();
  }

  Future<void> addFavorite(int songId) async {
    if (_favoriteIds.contains(songId)) return;
    final db = await database;
    await db.insert('favorites', {'song_id': songId}, conflictAlgorithm: ConflictAlgorithm.ignore);
    _favoriteIds.add(songId);
    notifyListeners();
  }

  Future<void> removeFavorite(int songId) async {
    if (!_favoriteIds.contains(songId)) return;
    final db = await database;
    await db.delete('favorites', where: 'song_id = ?', whereArgs: [songId]);
    _favoriteIds.remove(songId);
    notifyListeners();
  }
}