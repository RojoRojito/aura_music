import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens/tokens.dart';
import '../../data/models/playlist.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../widgets/aura_empty_state.dart';
import '../../widgets/aura_animations.dart';
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

    return repo.playlists.isEmpty
        ? AuraEmptyState(
            icon: Icons.queue_music,
            title: 'Sin listas de reproduccion',
            message: 'Crea tu primera lista para organizar tu musica',
            actionLabel: 'Crear lista',
            onAction: () => _showCreate(context),
          )
        : CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpacing.lg,
                    vertical: AuraSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tus listas',
                        style: AuraTypography.headline,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: AuraColors.primary,
                        onPressed: () => _showCreate(context),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.lg),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AuraSpacing.md,
                    mainAxisSpacing: AuraSpacing.md,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _PlaylistCard(
                      playlist: repo.playlists[i],
                      onTap: () => _navigateToDetail(repo.playlists[i]),
                      onLongPress: () => _showPlaylistMenu(repo.playlists[i]),
                      onDelete: () => _confirmDelete(repo.playlists[i]),
                    ),
                    childCount: repo.playlists.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          );
  }

  void _navigateToDetail(Playlist pl) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: pl)),
    );
  }

  void _showPlaylistMenu(Playlist pl) {
    HapticFeedback.mediumImpact();
    showAuraBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renombrar'),
              onTap: () {
                Navigator.pop(ctx);
                _showRename(pl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AuraColors.error),
              title: const Text('Eliminar', style: TextStyle(color: AuraColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(pl);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Playlist pl) {
    showAuraDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text('¿Eliminar "${pl.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<PlaylistRepository>().deletePlaylist(pl.id!);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AuraColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showRename(Playlist pl) {
    final ctrl = TextEditingController(text: pl.name);
    showAuraDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar lista'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre de la lista'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty && ctrl.text != pl.name) {
                context.read<PlaylistRepository>().renamePlaylist(pl.id!, ctrl.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showCreate(BuildContext ctx) {
    final ctrl = TextEditingController();
    showAuraDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Nueva lista'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre de la lista'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                ctx.read<PlaylistRepository>().createPlaylist(ctrl.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AuraColors.surfaceOf(context);
    final txt = AuraColors.textOf(context);
    final txtMuted = AuraColors.textMutedOf(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AuraRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AuraRadius.md),
                ),
                child: _PlaylistArtwork(playlist: playlist),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AuraSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraTypography.label.copyWith(
                      color: txt,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${playlist.songCount} canciones',
                    style: AuraTypography.caption.copyWith(color: txtMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistArtwork extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistArtwork({required this.playlist});

  @override
  Widget build(BuildContext context) {
    if (playlist.songs.isEmpty) {
      return Container(
        color: AuraColors.surfaceHigh,
        child: const Icon(
          Icons.queue_music,
          color: AuraColors.primary,
          size: 40,
        ),
      );
    }

    final firstSong = playlist.songs.first;
    final albumId = firstSong.albumId ?? 0;

    return QueryArtworkWidget(
      id: albumId,
      type: ArtworkType.ALBUM,
      nullArtworkWidget: Container(
        color: AuraColors.surfaceHigh,
        child: const Icon(
          Icons.music_note,
          color: AuraColors.primary,
          size: 40,
        ),
      ),
    );
  }
}
