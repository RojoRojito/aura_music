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
           await db.execute('''
             CREATE TABLE IF NOT EXISTS play_events (
               id INTEGER PRIMARY KEY AUTOINCREMENT,
               song_id INTEGER NOT NULL,
               title TEXT NOT NULL,
               artist TEXT NOT NULL,
               duration_seconds REAL NOT NULL,
               listened_seconds REAL NOT NULL,
               was_skipped INTEGER NOT NULL DEFAULT 0,
               is_favorite INTEGER NOT NULL DEFAULT 0,
               played_at TEXT NOT NULL)
           ''');
           await db.execute('''
             CREATE TABLE IF NOT EXISTS song_stats (
               song_id INTEGER PRIMARY KEY,
               title TEXT NOT NULL,
               artist TEXT NOT NULL,
               play_count INTEGER NOT NULL DEFAULT 0,
               skip_count INTEGER NOT NULL DEFAULT 0,
               total_listened_seconds REAL NOT NULL DEFAULT 0,
               total_duration_seconds REAL NOT NULL DEFAULT 0,
               is_favorite INTEGER NOT NULL DEFAULT 0,
               last_played TEXT)
           ''');
         },
         onOpen: (db) async {
           await db.execute('''
             CREATE TABLE IF NOT EXISTS play_events (
               id INTEGER PRIMARY KEY AUTOINCREMENT,
               song_id INTEGER NOT NULL,
               title TEXT NOT NULL,
               artist TEXT NOT NULL,
               duration_seconds REAL NOT NULL,
               listened_seconds REAL NOT NULL,
               was_skipped INTEGER NOT NULL DEFAULT 0,
               is_favorite INTEGER NOT NULL DEFAULT 0,
               played_at TEXT NOT NULL)
           ''');
           await db.execute('''
             CREATE TABLE IF NOT EXISTS song_stats (
               song_id INTEGER PRIMARY KEY,
               title TEXT NOT NULL,
               artist TEXT NOT NULL,
               play_count INTEGER NOT NULL DEFAULT 0,
               skip_count INTEGER NOT NULL DEFAULT 0,
               total_listened_seconds REAL NOT NULL DEFAULT 0,
               total_duration_seconds REAL NOT NULL DEFAULT 0,
               is_favorite INTEGER NOT NULL DEFAULT 0,
               last_played TEXT)
           ''');
         },
       );
     }
}