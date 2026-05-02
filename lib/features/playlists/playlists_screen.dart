import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/playlist_repository.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});
  @override State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PlaylistRepository>().loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlaylistRepository>();
    return Scaffold(
      backgroundColor: AuraColors.background,
      appBar: AppBar(
        backgroundColor: AuraColors.background, elevation: 0,
        title: const Text('Listas', style: TextStyle(
            color: AuraColors.text, fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: repo.playlists.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.queue_music, color: AuraColors.textMuted, size: 64),
            const SizedBox(height: 16),
            const Text('Sin listas de reproduccion',
                style: TextStyle(color: AuraColors.textMuted, fontSize: 15)),
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
                    color: AuraColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.queue_music, color: AuraColors.primary)),
                title: Text(pl.name,
                    style: const TextStyle(color: AuraColors.text)),
                subtitle: Text('${pl.songCount} canciones',
                    style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AuraColors.textMuted),
                  onPressed: () => _confirmDelete(context, repo, pl)),
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

  void _confirmDelete(BuildContext ctx, PlaylistRepository repo, pl) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AuraColors.surface,
        title: const Text('Eliminar lista', style: TextStyle(color: AuraColors.text)),
        content: Text('¿Eliminar "${pl.name}"?',
            style: const TextStyle(color: AuraColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AuraColors.textMuted))),
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
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: AuraColors.surface,
      title: const Text('Nueva lista',
          style: TextStyle(color: AuraColors.text)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: const TextStyle(color: AuraColors.text),
        decoration: const InputDecoration(
          hintText: 'Nombre de la lista',
          hintStyle: TextStyle(color: AuraColors.textMuted))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AuraColors.textMuted))),
        TextButton(
          onPressed: () {
            if (ctrl.text.isNotEmpty) {
              ctx.read<PlaylistRepository>().createPlaylist(ctrl.text);
              Navigator.pop(ctx);
            }
          },
          child: const Text('Crear',
              style: TextStyle(color: AuraColors.primary))),
      ],
    ));
  }
}
