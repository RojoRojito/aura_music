import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

const int _currentVersion = 4;

typedef Migration = Future<void> Function(Database db, int from, int to);

final Map<int, Migration> _migrations = {
  2: (db, from, to) async {
    // Add foreign key constraints support (enforced via PRAGMA in onOpen)
  },
  3: (db, from, to) async {
    await db.execute(
        'ALTER TABLE playlist_songs ADD COLUMN song_album TEXT DEFAULT ""');
  },
  4: (db, from, to) async {
    await db.execute(
        'ALTER TABLE song_stats ADD COLUMN repeat_count INTEGER DEFAULT 0');
    await db.execute(
        'ALTER TABLE song_stats ADD COLUMN playlist_add_count INTEGER DEFAULT 0');
  },
};

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();
  static Database? _db;

  static const _createStatements = [
    '''CREATE TABLE IF NOT EXISTS favorites (
         song_id INTEGER PRIMARY KEY)''',
    '''CREATE TABLE IF NOT EXISTS eq_configs (
         song_id INTEGER PRIMARY KEY,
         band_gains TEXT NOT NULL,
         bass_boost REAL DEFAULT 0.0,
         virtualizer REAL DEFAULT 0.0,
         enabled INTEGER DEFAULT 1,
         preset_name TEXT)''',
    '''CREATE TABLE IF NOT EXISTS playlists (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         name TEXT NOT NULL,
         created_at TEXT NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS playlist_songs (
         playlist_id INTEGER,
         song_id INTEGER,
         song_title TEXT,
         song_artist TEXT,
         song_album TEXT DEFAULT '',
         song_uri TEXT,
         song_duration INTEGER,
         album_id INTEGER,
         position INTEGER,
         PRIMARY KEY (playlist_id, song_id))''',
    '''CREATE TABLE IF NOT EXISTS play_events (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         song_id INTEGER NOT NULL,
         title TEXT NOT NULL,
         artist TEXT NOT NULL,
         duration_seconds REAL NOT NULL,
         listened_seconds REAL NOT NULL,
         was_skipped INTEGER NOT NULL DEFAULT 0,
         is_favorite INTEGER NOT NULL DEFAULT 0,
         played_at TEXT NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS song_stats (
         song_id INTEGER PRIMARY KEY,
         title TEXT NOT NULL,
         artist TEXT NOT NULL,
         play_count INTEGER NOT NULL DEFAULT 0,
         skip_count INTEGER NOT NULL DEFAULT 0,
         total_listened_seconds REAL NOT NULL DEFAULT 0,
         total_duration_seconds REAL NOT NULL DEFAULT 0,
         is_favorite INTEGER NOT NULL DEFAULT 0,
         last_played TEXT,
         repeat_count INTEGER NOT NULL DEFAULT 0,
         playlist_add_count INTEGER NOT NULL DEFAULT 0)''',
  ];

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'aura.db');
    return openDatabase(
      path,
      version: _currentVersion,
      onCreate: (db, _) async {
        for (final sql in _createStatements) {
          await db.execute(sql);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          final migration = _migrations[v];
          if (migration != null) {
            await migration(db, oldVersion, newVersion);
          }
        }
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }
}
