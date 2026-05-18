import 'package:flutter/material.dart';
import '../../data/models/song.dart';
import '../../services/media_scanner.dart';
import '../../data/repositories/stats_repository.dart';
import '../../data/models/song_stats.dart';
import '../player/player_controller.dart';

enum LibraryStatus { initial, loading, loaded, empty, noPermission, error }

enum SortOption {
  title,
  artist,
  album,
  duration,
  dateAdded,
}

class LibraryController extends ChangeNotifier {
  final MediaScanner _scanner;
  final PlayerController _player;
  final StatsRepository _stats;
  List<Song> _all = [], _filtered = [];
  String _query = '';
  LibraryStatus _status = LibraryStatus.initial;
  SortOption _sortOption = SortOption.title;
  bool _ascending = true;

  List<SongStats> _recentlyPlayed = [];
  List<SongStats> _mostPlayed = [];
  bool _statsLoaded = false;

  LibraryController(this._scanner, this._player, this._stats) {
    scanLibrary();
    _loadStats();
  }

  List<Song> get songs => _filtered;
  LibraryStatus get status => _status;
  bool get isEmpty => _status == LibraryStatus.empty;
  bool get isLoading => _status == LibraryStatus.loading;
  SortOption get sortOption => _sortOption;
  bool get ascending => _ascending;

  List<SongStats> get recentlyPlayed => _recentlyPlayed;
  List<SongStats> get mostPlayed => _mostPlayed;
  bool get hasSections => _statsLoaded && _recentlyPlayed.isNotEmpty;

  String? _scanErrorMessage;

  String? get errorMessage {
    if (_status == LibraryStatus.noPermission) return 'Permiso de audio denegado';
    if (_status == LibraryStatus.error) return _scanErrorMessage ?? 'Error al cargar canciones';
    return null;
  }

  Future<void> scanLibrary() async {
    _status = LibraryStatus.loading;
    _scanErrorMessage = null;
    notifyListeners();
    try {
      final result = await _scanner.scanSongs();

      switch (result.status) {
        case ScanStatus.noPermission:
          _status = LibraryStatus.noPermission;
          break;
        case ScanStatus.error:
          _status = LibraryStatus.error;
          _scanErrorMessage = result.errorMessage;
          break;
        case ScanStatus.success:
          _all = result.songs;
          _applySortAndFilter();
          _status = _all.isEmpty ? LibraryStatus.empty : LibraryStatus.loaded;
          break;
        default:
          _status = LibraryStatus.error;
          _scanErrorMessage = 'Estado inesperado: ${result.status}';
          break;
      }
    } catch (e) {
      _status = LibraryStatus.error;
      _scanErrorMessage = e.toString();
      debugPrint('scanLibrary error: $e');
    }
    notifyListeners();
  }

  Future<void> _loadStats() async {
    try {
      _recentlyPlayed = await _stats.getRecentlyPlayed(limit: 10);
      _mostPlayed = await _stats.getMostPlayed(limit: 10);
      _statsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  void search(String q) {
    _query = q.toLowerCase();
    _applySortAndFilter();
  }

  void setSort(SortOption option) {
    if (_sortOption == option) {
      _ascending = !_ascending;
    } else {
      _sortOption = option;
      _ascending = true;
    }
    _applySortAndFilter();
  }

  void _applySortAndFilter() {
    var list = _query.isEmpty
        ? List<Song>.from(_all)
        : _all
            .where((s) =>
                s.title.toLowerCase().contains(_query) ||
                s.artist.toLowerCase().contains(_query) ||
                s.album.toLowerCase().contains(_query))
            .toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortOption) {
        case SortOption.title:
          cmp = a.title.compareTo(b.title);
          break;
        case SortOption.artist:
          cmp = a.artist.compareTo(b.artist);
          break;
        case SortOption.album:
          cmp = a.album.compareTo(b.album);
          break;
        case SortOption.duration:
          cmp = a.duration.compareTo(b.duration);
          break;
        case SortOption.dateAdded:
          cmp = (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0);
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    _filtered = list;
    notifyListeners();
  }

  void playSong(Song s) => _player.playSong(s, queue: _all);
  void shuffleAll() {
    if (_all.isEmpty) return;
    final sh = List<Song>.from(_all)..shuffle();
    _player.playSong(sh.first, queue: sh);
  }

  Future<void> refreshStats() async {
    await _loadStats();
  }
}
