import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/repositories/playlist_repository.dart';
import '../player/player_controller.dart';
import '../../widgets/song_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Playlist _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
  }

  void _refresh() {
    final repo = context.read<PlaylistRepository>();
    repo.loadPlaylists();
    final updated = repo.playlists.firstWhere(
      (p) => p.id == _playlist.id,
      orElse: () => _playlist,
    );
    setState(() => _playlist = updated);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final repo = context.watch<PlaylistRepository>();
    final playlist = repo.playlists.firstWhere(
      (p) => p.id == _playlist.id,
      orElse: () => _playlist,
    );

    return Scaffold(
      backgroundColor: AuraColors.background,
      appBar: AppBar(
        backgroundColor: AuraColors.background,
        elevation: 0,
        title: Text(playlist.name,
            style: const TextStyle(color: AuraColors.text, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AuraColors.textMuted),
            onPressed: () => _showDeleteDialog(context, repo),
          ),
        ],
      ),
      body: playlist.songs.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.queue_music, color: AuraColors.textMuted, size: 64),
            const SizedBox(height: 16),
            const Text('Playlist vacía',
                style: TextStyle(color: AuraColors.textMuted, fontSize: 16)),
          ]))
        : Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(children: [
                Text('${playlist.songCount} canciones',
                    style: const TextStyle(color: AuraColors.textMuted, fontSize: 13)),
                const Spacer(),
                Text(_formatDuration(playlist.totalDuration),
                    style: const TextStyle(color: AuraColors.textMuted, fontSize: 13)),
              ])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => _playAll(ctrl),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Reproducir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuraColors.primary,
                  foregroundColor: Colors.white))),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 160),
                itemCount: playlist.songs.length,
                itemBuilder: (_, i) {
                  final song = playlist.songs[i];
                  return Dismissible(
                    key: Key('${song.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: AuraColors.accent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _removeSong(repo, song.id!),
                    child: SongTile(
                      song: song,
                      onTap: () => ctrl.playSong(song, queue: playlist.songs),
                      enableActions: false,
                    ),
                  );
                }),
            ),
          ]),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  void _playAll(PlayerController ctrl) {
    if (_playlist.songs.isNotEmpty) {
      ctrl.playSong(_playlist.songs.first, queue: _playlist.songs);
    }
  }

  void _removeSong(PlaylistRepository repo, int songId) {
    repo.removeSong(_playlist.id!, songId);
    _refresh();
  }

  void _showDeleteDialog(BuildContext context, PlaylistRepository repo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AuraColors.surface,
        title: const Text('Eliminar playlist',
            style: TextStyle(color: AuraColors.text)),
        content: Text('¿Eliminar "${_playlist.name}"?',
            style: const TextStyle(color: AuraColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AuraColors.textMuted))),
          TextButton(
            onPressed: () {
              repo.deletePlaylist(_playlist.id!);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: AuraColors.accent))),
        ],
      ),
    );
  }
}