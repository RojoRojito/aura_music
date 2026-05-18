import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens/tokens.dart';
import '../../widgets/loading_indicator.dart';
import '../../data/models/song.dart';
import '../../services/media_scanner.dart';
import '../player/player_controller.dart';
import '../../widgets/song_tile.dart';

class AlbumDetailScreen extends StatefulWidget {
  final AlbumModel album;
  const AlbumDetailScreen({super.key, required this.album});

  @override State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final scanner = context.read<MediaScanner>();
    final songs = await scanner.songsByAlbum(widget.album.id);
    setState(() { _songs = songs; _loading = false; });
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
              title: Text(widget.album.album,
                  style: AuraTypography.title.copyWith(color: AuraColors.text),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              background: Stack(children: [
                Positioned.fill(
                  child: Hero(
                    tag: 'album_art_${widget.album.id}',
                    child: QueryArtworkWidget(
                      id: widget.album.id, type: ArtworkType.ALBUM,
                      nullArtworkWidget: Container(
                        color: AuraColors.surfaceHigh,
                        child: const Icon(Icons.album, color: AuraColors.primary, size: 80))))),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AuraColors.background.withOpacity(0.8)],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                Text('${_songs.length} canciones',
                    style: AuraTypography.caption),
                const Spacer(),
                Text(widget.album.artist ?? 'Artista desconocido',
                    style: AuraTypography.caption),
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
          const SliverToBoxAdapter(child: SizedBox(height: AuraSpacing.xl)),
          _loading
            ? const SliverFillRemaining(
                child: const AuraLoadingIndicator())
            : _songs.isEmpty
              ? const SliverFillRemaining(
                  child: Center(child: Text('Sin canciones',
                      style: TextStyle(color: AuraColors.textMuted))))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => SongTile(
                      song: _songs[i],
                      onTap: () => ctrl.playSong(_songs[i], queue: _songs),
                      showAlbumArt: false,
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
