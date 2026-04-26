import 'package:flutter/material.dart';
import '../../data/models/song.dart';
import '../../services/media_scanner.dart';
import '../player/player_controller.dart';

class LibraryController extends ChangeNotifier {
  final MediaScanner _scanner;
  final PlayerController _player;
  List<Song> _all = [], _filtered = [];
  String _query = '';
  bool isLoading = false;
  String? error;

  LibraryController(this._scanner, this._player) { scanLibrary(); }

  List<Song> get songs => _filtered;
  bool get isEmpty => _all.isEmpty && !isLoading;

  Future<void> scanLibrary() async {
    isLoading = true; error = null; notifyListeners();
    try {
      _all = await _scanner.scanSongs();
      _filter();
    } catch (e) {
      error = 'Error: \$e';
    } finally {
      isLoading = false; notifyListeners();
    }
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
