import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class PlaylistRepository extends ChangeNotifier {
  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  Future<Database> get database => AppDatabase.instance.database;

  Future<void> loadPlaylists() async {
    final db = await database;
    final maps = await db.query('playlists', orderBy: 'created_at DESC');
    _playlists = [];
    for (final m in maps) {
      final songs = await _getSongs(m['id'] as int);
      _playlists.add(Playlist.fromMap(m).copyWith(songs: songs));
    }
    notifyListeners();
  }

  Future<void> loadPlaylistsResolved(Map<int, Song> songCache) async {
    final db = await database;
    final maps = await db.query('playlists', orderBy: 'created_at DESC');
    _playlists = [];
    for (final m in maps) {
      final songs = await _getSongsResolved(m['id'] as int, songCache);
      _playlists.add(Playlist.fromMap(m).copyWith(songs: songs));
    }
    notifyListeners();
  }

  Future<List<Song>> _getSongs(int plId) async {
    final db = await database;
    final maps = await db.query('playlist_songs',
        where: 'playlist_id = ?', whereArgs: [plId], orderBy: 'position ASC');
    return maps.map((m) => Song(
      id: m['song_id'] as int,
      title: m['song_title'] as String,
      artist: m['song_artist'] as String,
      album: (m['song_album'] as String?) ?? '',
      uri: m['song_uri'] as String,
      duration: m['song_duration'] as int,
      albumId: m['album_id'] as int?,
    )).toList();
  }

  Future<List<Song>> _getSongsResolved(int plId, Map<int, Song> songCache) async {
    final db = await database;
    final maps = await db.query('playlist_songs',
        where: 'playlist_id = ?', whereArgs: [plId], orderBy: 'position ASC');
    final songs = <Song>[];
    for (final m in maps) {
      final songId = m['song_id'] as int;
      final cached = songCache[songId];
      if (cached != null) {
        songs.add(cached);
      } else {
        songs.add(Song(
          id: songId,
          title: m['song_title'] as String,
          artist: m['song_artist'] as String,
          album: (m['song_album'] as String?) ?? '',
          uri: m['song_uri'] as String,
          duration: m['song_duration'] as int,
          albumId: m['album_id'] as int?,
        ));
      }
    }
    return songs;
  }

  Future<void> createPlaylist(String name) async {
    final db = await database;
    await db.insert('playlists',
        {'name': name, 'created_at': DateTime.now().toIso8601String()});
    await loadPlaylists();
  }

  Future<void> deletePlaylist(int id) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
    await db.delete('playlist_songs', where: 'playlist_id = ?', whereArgs: [id]);
    await loadPlaylists();
  }

  Future<void> addSong(int plId, Song song) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM playlist_songs WHERE playlist_id = ?', [plId])) ?? 0;
    await db.insert('playlist_songs', {
      'playlist_id': plId, 'song_id': song.id,
      'song_title': song.title, 'song_artist': song.artist,
      'song_album': song.album, 'song_uri': song.uri,
      'song_duration': song.duration, 'album_id': song.albumId,
      'position': count,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await loadPlaylists();
  }

  Future<void> removeSong(int plId, int songId) async {
    final db = await database;
    await db.delete('playlist_songs',
        where: 'playlist_id = ? AND song_id = ?', whereArgs: [plId, songId]);
    await loadPlaylists();
  }
}