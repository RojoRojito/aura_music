import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/media_scanner.dart';
import '../../data/models/song.dart';
import '../../data/models/artist.dart';
import '../player/player_controller.dart';
import '../../widgets/song_tile.dart';

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});
  @override State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  List<ArtistModel> _artists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final artists = await context.read<MediaScanner>().scanArtists();
    setState(() { _artists = artists; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.background,
      appBar: AppBar(
        backgroundColor: AuraColors.background,
        elevation: 0,
        title: const Text('Artistas', style: TextStyle(
            color: AuraColors.text, fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AuraColors.primary))
        : _artists.isEmpty
          ? const Center(child: Text('No hay artistas',
              style: TextStyle(color: AuraColors.textMuted)))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 160),
              itemCount: _artists.length,
              itemBuilder: (_, i) => _ArtistTile(artist: _artists[i])),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final ArtistModel artist;
  const _ArtistTile({required this.artist});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(width: 48, height: 48,
          child: QueryArtworkWidget(
            id: artist.id, type: ArtworkType.ARTIST,
            nullArtworkWidget: Container(
              color: AuraColors.surfaceHigh,
              child: const Icon(Icons.person, color: AuraColors.primary))))),
      title: Text(artist.artist ?? 'Artista desconocido',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AuraColors.text, fontSize: 15)),
      subtitle: Text('${artist.numberOfTracks ?? 0} canciones',
          style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
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
    return Scaffold(
      backgroundColor: AuraColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AuraColors.background,
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.artist.artist ?? 'Artista',
                  style: const TextStyle(color: AuraColors.text, fontSize: 16),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              background: Stack(children: [
                Positioned.fill(
                  child: QueryArtworkWidget(
                    id: widget.artist.id, type: ArtworkType.ARTIST,
                    nullArtworkWidget: Container(
                      color: AuraColors.surfaceHigh,
                      child: const Icon(Icons.person, color: AuraColors.primary, size: 80)))),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AuraColors.background.withOpacity(0.8)])))),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                Text('${_songs.length} canciones • ${_albums.length} albumes',
                    style: const TextStyle(color: AuraColors.textMuted, fontSize: 13)),
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
              ? const SliverFillRemaining(
                  child: Center(child: Text('Sin canciones',
                      style: TextStyle(color: AuraColors.textMuted))))
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
