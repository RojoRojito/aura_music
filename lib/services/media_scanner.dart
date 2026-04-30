import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/song.dart';

enum ScanStatus { idle, loading, success, noPermission, error }

class ScanResult {
  final List<Song> songs;
  final ScanStatus status;
  final String? errorMessage;

  const ScanResult({required this.songs, required this.status, this.errorMessage});
}

class MediaScanner {
  final OnAudioQuery _q = OnAudioQuery();

  Future<bool> requestPermission() async {
    var s = await Permission.audio.request();
    if (!s.isGranted) s = await Permission.storage.request();
    return s.isGranted;
  }

  Future<ScanResult> scanSongs() async {
    if (!await requestPermission()) {
      return const ScanResult(songs: [], status: ScanStatus.noPermission);
    }
    try {
      final songs = await _q.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      final filtered = songs
          .where((s) => (s.duration ?? 0) > 30000)
          .map(_map)
          .toList();
      return ScanResult(songs: filtered, status: ScanStatus.success);
    } catch (e) {
      return ScanResult(songs: [], status: ScanStatus.error, errorMessage: e.toString());
    }
  }

  Future<List<AlbumModel>> scanAlbums() =>
      _q.queryAlbums(sortType: AlbumSortType.ALBUM,
          orderType: OrderType.ASC_OR_SMALLER);

  Future<List<ArtistModel>> scanArtists() =>
      _q.queryArtists(sortType: ArtistSortType.ARTIST,
          orderType: OrderType.ASC_OR_SMALLER);

  Future<List<Song>> songsByArtist(int artistId) async {
    final r = await _q.queryAudiosFrom(AudiosFromType.ARTIST_ID, artistId);
    return r.map(_map).toList();
  }

  Future<List<AlbumModel>> albumsByArtist(int artistId) async {
    final r = await _q.queryAlbums();
    return r.where((a) => a.artistId == artistId).toList();
  }

  Future<List<Song>> songsByAlbum(int albumId) async {
    final r = await _q.queryAudiosFrom(AudiosFromType.ALBUM_ID, albumId);
    return r.map(_map).toList();
  }

  Song _map(SongModel s) => Song(
    id: s.id,
    title: s.title,
    artist: s.artist ?? 'Artista desconocido',
    album: s.album ?? 'Album desconocido',
    albumArtUri: 'content://media/external/audio/albumart/${s.albumId}',
    uri: s.uri ?? '',
    duration: s.duration ?? 0,
    albumId: s.albumId,
    artistId: s.artistId,
    genre: s.genre,
    year: null,
    trackNumber: s.track,
  );
}