import 'package:flutter/material.dart';
import '../../data/models/song.dart';
import '../../services/media_scanner.dart';
import '../player/player_controller.dart';

enum LibraryStatus { initial, loading, loaded, empty, noPermission, error }

class LibraryController extends ChangeNotifier {
  final MediaScanner _scanner;
  final PlayerController _player;
  List<Song> _all = [], _filtered = [];
  String _query = '';
  LibraryStatus _status = LibraryStatus.initial;

  LibraryController(this._scanner, this._player) { scanLibrary(); }

  List<Song> get songs => _filtered;
  LibraryStatus get status => _status;
  bool get isEmpty => _status == LibraryStatus.empty;
  bool get isLoading => _status == LibraryStatus.loading;
  String? get errorMessage {
    if (_status == LibraryStatus.noPermission) return 'Permiso de audio denegado';
    if (_status == LibraryStatus.error) return 'Error al cargar canciones';
    return null;
  }

  Future<void> scanLibrary() async {
    _status = LibraryStatus.loading; notifyListeners();
    final result = await _scanner.scanSongs();

    switch (result.status) {
      case ScanStatus.noPermission:
        _status = LibraryStatus.noPermission;
        break;
      case ScanStatus.error:
        _status = LibraryStatus.error;
        break;
      case ScanStatus.success:
        _all = result.songs;
        _filter();
        _status = _all.isEmpty ? LibraryStatus.empty : LibraryStatus.loaded;
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void search(String q) { _query = q.toLowerCase(); _filter(); }

  void _filter() {
    _filtered = _query.isEmpty
        ? List.from(_all)
        : _all.where((s) =>
            s.title.toLowerCase().contains(_query) ||
            s.artist.toLowerCase().contains(_query) ||
            s.album.toLowerCase().contains(_query)).toList();
    notifyListeners();
  }

  void playSong(Song s)  => _player.playSong(s, queue: _all);
  void shuffleAll() {
    if (_all.isEmpty) return;
    final sh = List<Song>.from(_all)..shuffle();
    _player.playSong(sh.first, queue: sh);
  }
}