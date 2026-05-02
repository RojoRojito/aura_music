import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/models/playlist.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});
  @override State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<PlaylistRepository>().loadPlaylists();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlaylistRepository>();
    final settings = context.watch<SettingsController>();
    final isDark = settings.themeMode == ThemeMode.dark;
    final bgColor = isDark ? AuraColors.background : AuraColors.lightBackground;
    final textColor = isDark ? AuraColors.text : AuraColors.lightText;
    final mutedColor = isDark ? AuraColors.textMuted : AuraColors.lightTextMuted;

    final filtered = _searching && _searchCtrl.text.isNotEmpty
        ? repo.playlists.where((p) => p.name.toLowerCase().contains(_searchCtrl.text.toLowerCase())).toList()
        : repo.playlists;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor, elevation: 0,
        title: _searching
          ? TextField(
              controller: _searchCtrl, autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Buscar listas...',
                hintStyle: TextStyle(color: mutedColor),
                border: InputBorder.none),
              onChanged: (_) => setState(() {}))
          : Text('Listas', style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search, color: mutedColor),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) { _searchCtrl.clear(); }
              });
            }),
        ],
      ),
      body: filtered.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.queue_music, color: mutedColor, size: 64),
            const SizedBox(height: 16),
            Text(_searching ? 'No hay listas con ese nombre' : 'Sin listas de reproduccion',
                style: TextStyle(color: mutedColor, fontSize: 15)),
            if (!_searching) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _showCreate(context),
                icon: const Icon(Icons.add),
                label: const Text('Crear lista'),
                style: ElevatedButton.styleFrom(backgroundColor: AuraColors.primary)),
            ],
          ]))
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 160),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final pl = filtered[i];
              return ListTile(
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? AuraColors.surfaceHigh : AuraColors.lightSurfaceHigh,
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.queue_music, color: AuraColors.primary)),
                title: Text(pl.name, style: TextStyle(color: textColor)),
                subtitle: Text('${pl.songCount} canciones', style: TextStyle(color: mutedColor, fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: mutedColor, size: 20),
                    onPressed: () => _showEdit(context, repo, pl)),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: mutedColor, size: 20),
                    onPressed: () => _confirmDelete(context, repo, pl)),
                ]),
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

  void _confirmDelete(BuildContext ctx, PlaylistRepository repo, Playlist pl) {
    final isDark = ctx.read<SettingsController>().themeMode == ThemeMode.dark;
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AuraColors.surface : AuraColors.lightSurface,
        title: Text('Eliminar lista', style: TextStyle(color: isDark ? AuraColors.text : AuraColors.lightText)),
        content: Text('¿Eliminar "${pl.name}"?',
            style: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted))),
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
    final isDark = ctx.read<SettingsController>().themeMode == ThemeMode.dark;
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: isDark ? AuraColors.surface : AuraColors.lightSurface,
      title: Text('Nueva lista', style: TextStyle(color: isDark ? AuraColors.text : AuraColors.lightText)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: TextStyle(color: isDark ? AuraColors.text : AuraColors.lightText),
        decoration: InputDecoration(
          hintText: 'Nombre de la lista',
          hintStyle: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted))),
        TextButton(
          onPressed: () {
            if (ctrl.text.isNotEmpty) {
              ctx.read<PlaylistRepository>().createPlaylist(ctrl.text);
              Navigator.pop(ctx);
            }
          },
          child: const Text('Crear', style: TextStyle(color: AuraColors.primary))),
      ],
    ));
  }

  void _showEdit(BuildContext ctx, PlaylistRepository repo, Playlist pl) {
    final ctrl = TextEditingController(text: pl.name);
    final isDark = ctx.read<SettingsController>().themeMode == ThemeMode.dark;
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: isDark ? AuraColors.surface : AuraColors.lightSurface,
      title: Text('Editar nombre', style: TextStyle(color: isDark ? AuraColors.text : AuraColors.lightText)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: TextStyle(color: isDark ? AuraColors.text : AuraColors.lightText),
        decoration: InputDecoration(
          hintText: 'Nombre de la lista',
          hintStyle: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted))),
        TextButton(
          onPressed: () async {
            if (ctrl.text.isNotEmpty && ctrl.text != pl.name) {
              await repo.updatePlaylistName(pl.id!, ctrl.text);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Guardar', style: TextStyle(color: AuraColors.primary))),
      ],
    ));
  }
}