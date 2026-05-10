import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'aura.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS favorites (
            song_id INTEGER PRIMARY KEY)
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS eq_configs (
            song_id INTEGER PRIMARY KEY,
            band_gains TEXT NOT NULL,
            bass_boost REAL DEFAULT 0.0,
            virtualizer REAL DEFAULT 0.0,
            enabled INTEGER DEFAULT 1,
            preset_name TEXT)
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL)
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS playlist_songs (
            playlist_id INTEGER,
            song_id INTEGER,
            song_title TEXT,
            song_artist TEXT,
            song_uri TEXT,
            song_duration INTEGER,
            album_id INTEGER,
            position INTEGER,
            PRIMARY KEY (playlist_id, song_id))
        ''');
      },
    );
  }
}