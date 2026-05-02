import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/media_scanner.dart';
import '../../data/models/song.dart';
import '../player/player_controller.dart';
import '../../widgets/song_tile.dart';

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});
  @override State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  List<ArtistModel> _artists = [];
  List<ArtistModel> _filtered = [];
  bool _loading = true;
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final artists = await context.read<MediaScanner>().scanArtists();
    setState(() { _artists = artists; _filtered = artists; _loading = false; });
  }

  void _search(String q) {
    setState(() {
      _searching = q.isNotEmpty;
      _filtered = q.isEmpty
          ? _artists
          : _artists.where((a) =>
              a.artist.toLowerCase().contains(q.toLowerCase())
          ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = settings.themeMode == ThemeMode.dark;
    final bgColor = isDark ? AuraColors.background : AuraColors.lightBackground;
    final textColor = isDark ? AuraColors.text : AuraColors.lightText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: _searching
          ? TextField(
              controller: _searchCtrl, autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Buscar artistas...',
                hintStyle: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted),
                border: InputBorder.none),
              onChanged: _search)
          : Text('Artistas', style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search,
                color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) { _searchCtrl.clear(); _filtered = _artists; }
              });
            }),
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted),
            onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AuraColors.primary))
        : _filtered.isEmpty
          ? Center(child: Text('No hay artistas',
              style: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted)))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 160),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _ArtistTile(artist: _filtered[i])),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final ArtistModel artist;
  const _ArtistTile({required this.artist});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = settings.themeMode == ThemeMode.dark;
    final textColor = isDark ? AuraColors.text : AuraColors.lightText;
    final mutedColor = isDark ? AuraColors.textMuted : AuraColors.lightTextMuted;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(width: 48, height: 48,
          child: QueryArtworkWidget(
            id: artist.id, type: ArtworkType.ARTIST,
            nullArtworkWidget: Container(
              color: isDark ? AuraColors.surfaceHigh : AuraColors.lightSurfaceHigh,
              child: Icon(Icons.person, color: isDark ? AuraColors.primary : AuraColors.primary)))),
      title: Text(artist.artist.isNotEmpty ? artist.artist! : 'Artista desconocido',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor, fontSize: 15)),
      subtitle: Text('${artist.numberOfTracks} canciones',
          style: TextStyle(color: mutedColor, fontSize: 12)),
      onTap: () => _showArtistDetail(context),
    );
  }

  void _showArtistDetail(BuildContext ctx) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => _ArtistDetailScreen(artist: artist)));
  }
}

class _ArtistDetailScreen extends StatefulWidget {
  final ArtistModel artist;
  const _ArtistDetailScreen({super.key, required this.artist});

  @override State<_ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<_ArtistDetailScreen> {
  List<Song> _songs = [];
  List<AlbumModel> _albums = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scanner = context.read<MediaScanner>();
    final songs = await scanner.songsByArtist(widget.artist.id);
    final albums = await scanner.albumsByArtist(widget.artist.id);
    setState(() { _songs = songs; _albums = albums; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final settings = context.watch<SettingsController>();
    final isDark = settings.themeMode == ThemeMode.dark;
    final bgColor = isDark ? AuraColors.background : AuraColors.lightBackground;
    final textColor = isDark ? AuraColors.text : AuraColors.lightText;
    final surfaceColor = isDark ? AuraColors.surface : AuraColors.lightSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: bgColor,
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.artist.artist.isNotEmpty ? widget.artist.artist! : 'Artista',
                  style: TextStyle(color: textColor, fontSize: 16),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              background: Stack(children: [
                Positioned.fill(
                  child: QueryArtworkWidget(
                    id: widget.artist.id, type: ArtworkType.ARTIST,
                    nullArtworkWidget: Container(
                      color: isDark ? AuraColors.surfaceHigh : AuraColors.lightSurfaceHigh,
                      child: Icon(Icons.person, color: isDark ? AuraColors.primary : AuraColors.primary, size: 80)))),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, bgColor.withOpacity(0.8)])))),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                Text('${_songs.length} canciones • ${_albums.length} albumes',
                    style: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted, fontSize: 13)),
              ]))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _songs.isNotEmpty ? () => _playAll(ctrl) : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Reproducir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuraColors.primary,
                  foregroundColor: Colors.white)))),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          _loading
            ? const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AuraColors.primary)))
            : _songs.isEmpty
              ? SliverFillRemaining(
                  child: Center(child: Text('Sin canciones',
                      style: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted))))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => SongTile(
                      song: _songs[i],
                      onTap: () => ctrl.playSong(_songs[i], queue: _songs),
                      enableActions: true,
                    ),
                    childCount: _songs.length)),
        ],
      ),
      floatingActionButton: _songs.isNotEmpty
        ? FloatingActionButton(
            onPressed: () => _shuffleAll(ctrl),
            backgroundColor: AuraColors.secondary,
            child: const Icon(Icons.shuffle))
        : null,
    );
  }

  void _playAll(PlayerController ctrl) {
    if (_songs.isNotEmpty) {
      ctrl.playSong(_songs.first, queue: _songs);
    }
  }

  void _shuffleAll(PlayerController ctrl) {
    if (_songs.isNotEmpty) {
      final shuffled = List<Song>.from(_songs)..shuffle();
      ctrl.playSong(shuffled.first, queue: shuffled);
    }
  }
}