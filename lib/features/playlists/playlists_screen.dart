import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/playlist_repository.dart';
import '../library/library_controller.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});
  @override State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  void _loadPlaylists() {
    final libCtrl = context.read<LibraryController>();
    final playlistRepo = context.read<PlaylistRepository>();
    if (libCtrl.status == LibraryStatus.loaded && libCtrl.songs.isNotEmpty) {
      final songCache = {for (final s in libCtrl.songs) s.id: s};
      playlistRepo.loadPlaylistsResolved(songCache);
    } else {
      playlistRepo.loadPlaylists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlaylistRepository>();
    final bg = AuraColors.backgroundOf(context);
    final txt = AuraColors.textOf(context);
    final txtMuted = AuraColors.textMutedOf(context);
    final surface = AuraColors.surfaceOf(context);
    final surfaceHigh = AuraColors.surfaceHighOf(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg, elevation: 0,
        title: Text('Listas', style: TextStyle(
            color: txt, fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: repo.playlists.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.queue_music, color: txtMuted, size: 64),
            const SizedBox(height: 16),
            Text('Sin listas de reproduccion',
                style: TextStyle(color: txtMuted, fontSize: 15)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showCreate(context),
              icon: const Icon(Icons.add),
              label: const Text('Crear lista'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AuraColors.primary)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 160),
            itemCount: repo.playlists.length,
            itemBuilder: (_, i) {
              final pl = repo.playlists[i];
              return ListTile(
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: surfaceHigh,
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.queue_music, color: AuraColors.primary)),
                title: Text(pl.name,
                    style: TextStyle(color: txt)),
                subtitle: Text('${pl.songCount} canciones',
                    style: TextStyle(color: txtMuted, fontSize: 12)),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: txtMuted),
                  onPressed: () => _confirmDelete(context, repo, pl, surface, txt, txtMuted)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(playlist: pl)));
                },
              );
            }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreate(context),
        backgroundColor: AuraColors.primary,
        child: const Icon(Icons.add)),
    );
  }

  void _confirmDelete(BuildContext ctx, PlaylistRepository repo, pl, Color surface, Color txt, Color txtMuted) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: surface,
        title: Text('Eliminar lista', style: TextStyle(color: txt)),
        content: Text('¿Eliminar "${pl.name}"?',
            style: TextStyle(color: txtMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: txtMuted))),
          TextButton(
            onPressed: () {
              repo.deletePlaylist(pl.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: AuraColors.accent))),
        ],
      ),
    );
  }

  void _showCreate(BuildContext ctx) {
    final ctrl = TextEditingController();
    final surface = AuraColors.surfaceOf(ctx);
    final txt = AuraColors.textOf(ctx);
    final txtMuted = AuraColors.textMutedOf(ctx);
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: surface,
      title: Text('Nueva lista',
          style: TextStyle(color: txt)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: TextStyle(color: txt),
        decoration: InputDecoration(
          hintText: 'Nombre de la lista',
          hintStyle: TextStyle(color: txtMuted))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: txtMuted))),
        TextButton(
          onPressed: () {
            if (ctrl.text.isNotEmpty) {
              ctx.read<PlaylistRepository>().createPlaylist(ctrl.text);
              Navigator.pop(ctx);
            }
          },
          child: Text('Crear',
              style: TextStyle(color: AuraColors.primary))),
      ],
    ));
  }
}
