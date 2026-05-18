import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/tokens/tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../../data/models/playlist.dart';
import '../../data/repositories/playlist_repository.dart';
import 'aura_animations.dart';
import '../features/player/player_controller.dart';

class AddToPlaylistSheet extends StatelessWidget {
  final Song song;
  const AddToPlaylistSheet({super.key, required this.song});

  static Future<void> show(BuildContext context, Song song) {
    return showAuraBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddToPlaylistSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<PlayerController>();
    
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(
        padding: EdgeInsets.all(AuraSpacing.xl),
        child: Text('Opciones',
            style: AuraTypography.headline)),
      ListTile(
        leading: const Icon(Icons.queue_music, color: AuraColors.primary),
        title: const Text('Añadir a la cola',
            style: AuraTypography.title),
        onTap: () async {
          await ctrl.addToQueue(song);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${song.title} añadido a la cola'),
                backgroundColor: AuraColors.surfaceHigh,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.queue_play_next, color: AuraColors.secondary),
        title: const Text('Reproducir siguiente',
            style: AuraTypography.title),
        onTap: () async {
          await ctrl.playNext(song);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${song.title} reproducirá después'),
                backgroundColor: AuraColors.surfaceHigh,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
      const Divider(color: AuraColors.divider),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: AuraSpacing.xl, vertical: AuraSpacing.sm),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Agregar a playlist',
              style: AuraTypography.caption)),
      ),
      Flexible(
        child: Consumer<PlaylistRepository>(
          builder: (_, repo, __) {
            return repo.playlists.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AuraSpacing.xl),
                  child: Text('No hay playlists',
                      style: AuraTypography.body))
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
                          borderRadius: BorderRadius.circular(AuraRadius.sm)),
                        child: const Icon(Icons.queue_music, color: AuraColors.primary, size: 20)),
                      title: Text(pl.name,
                          style: AuraTypography.title),
                      subtitle: Text('${pl.songCount} canciones',
                          style: AuraTypography.caption),
                      onTap: () => _addToPlaylist(context, repo, pl),
                    );
                  },
                );
          },
        ),
      ),
      ListTile(
        leading: const Icon(Icons.add, color: AuraColors.secondary),
        title: const Text('Crear nueva playlist',
            style: AuraTypography.title),
        onTap: () => _showCreateDialog(context),
      ),
      const SizedBox(height: AuraSpacing.xl),
    ]);
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

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final repo = context.read<PlaylistRepository>();
    showAuraDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nombre de la playlist')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
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
            child: const Text('Crear')),
        ],
      ),
    );
  }
}