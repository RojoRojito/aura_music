import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../../data/models/playlist.dart';
import '../../data/repositories/playlist_repository.dart';

class AddToPlaylistSheet extends StatelessWidget {
  final Song song;
  const AddToPlaylistSheet({super.key, required this.song});

  static Future<void> show(BuildContext context, Song song) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AuraColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AddToPlaylistSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistRepository>(
      builder: (_, repo, __) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Agregar a playlist',
                style: TextStyle(color: AuraColors.text, fontSize: 18, fontWeight: FontWeight.bold))),
          Flexible(
            child: repo.playlists.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No hay playlists',
                      style: TextStyle(color: AuraColors.textMuted)))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: repo.playlists.length,
                  itemBuilder: (_, i) {
                    final pl = repo.playlists[i];
                    return ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AuraColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.queue_music, color: AuraColors.primary, size: 20)),
                      title: Text(pl.name,
                          style: const TextStyle(color: AuraColors.text)),
                      subtitle: Text('${pl.songCount} canciones',
                          style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
                      onTap: () => _addToPlaylist(context, repo, pl),
                    );
                  }),
          ),
          const Divider(color: AuraColors.divider),
          ListTile(
            leading: const Icon(Icons.add, color: AuraColors.secondary),
            title: const Text('Crear nueva playlist',
                style: TextStyle(color: AuraColors.secondary)),
            onTap: () => _showCreateDialog(context, repo),
          ),
          const SizedBox(height: 16),
        ]);
      },
    );
  }

  void _addToPlaylist(BuildContext context, PlaylistRepository repo, Playlist pl) async {
    await repo.addSong(pl.id!, song);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Agregado a ${pl.name}'),
          backgroundColor: AuraColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCreateDialog(BuildContext context, PlaylistRepository repo) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AuraColors.surface,
        title: const Text('Nueva playlist',
            style: TextStyle(color: AuraColors.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AuraColors.text),
          decoration: const InputDecoration(
            hintText: 'Nombre de la playlist',
            hintStyle: TextStyle(color: AuraColors.textMuted))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AuraColors.textMuted))),
          TextButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                await repo.createPlaylist(ctrl.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playlist "${ctrl.text}" creada'),
                      backgroundColor: AuraColors.surfaceHigh,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Crear', style: TextStyle(color: AuraColors.primary))),
        ],
      ),
    );
  }
}