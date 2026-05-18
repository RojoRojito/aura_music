import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens/tokens.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../widgets/aura_empty_state.dart';
import '../../widgets/aura_animations.dart';
import '../player/player_controller.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Playlist _playlist;
  bool _isEditing = false;
  final _editCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistRepository>().loadPlaylists();
    });
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
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
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(playlist),
          if (playlist.songs.isEmpty)
            SliverFillRemaining(
              child: AuraEmptyState(
                icon: Icons.queue_music,
                title: 'Playlist vacía',
                message: 'Agrega canciones desde tu biblioteca',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AuraSpacing.lg),
                child: Row(
                  children: [
                    Text(
                      '${playlist.songCount} canciones',
                      style: AuraTypography.caption.copyWith(
                        color: AuraColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: AuraSpacing.sm),
                    const Text('•', style: AuraTypography.caption),
                    const SizedBox(width: AuraSpacing.sm),
                    Text(
                      _formatDuration(playlist.totalDuration),
                      style: AuraTypography.caption.copyWith(
                        color: AuraColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _playAll(ctrl, playlist),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Reproducir'),
                      ),
                    ),
                    const SizedBox(width: AuraSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _shuffleAll(ctrl, playlist),
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Aleatorio'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AuraColors.secondary,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AuraSpacing.sm)),
            SliverReorderableList(
              itemCount: playlist.songs.length,
              onReorder: (oldIndex, newIndex) =>
                  _reorderSong(repo, playlist, oldIndex, newIndex),
              itemBuilder: (ctx, i) {
                final song = playlist.songs[i];
                return ReorderableDragStartListener(
                  key: Key('song_${song.id}'),
                  index: i,
                  child: _SongTile(
                    song: song,
                    index: i,
                    onTap: () => ctrl.playSong(song, queue: playlist.songs),
                    onRemove: () => _removeSong(repo, playlist, song),
                    onPlayNext: () => _playNext(ctrl, song),
                    onMoveToTop: () => _moveToTop(repo, playlist, song, i),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Playlist playlist) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AuraColors.background,
      flexibleSpace: FlexibleSpaceBar(
        title: _isEditing
            ? SizedBox(
                width: 200,
                child: TextField(
                  controller: _editCtrl,
                  autofocus: true,
                  style: AuraTypography.headline.copyWith(color: AuraColors.text),
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (val) {
                    if (val.isNotEmpty && val != playlist.name) {
                      context
                          .read<PlaylistRepository>()
                          .renamePlaylist(playlist.id!, val);
                    }
                    setState(() => _isEditing = false);
                  },
                ),
              )
            : GestureDetector(
                onLongPress: () {
                  _editCtrl.text = playlist.name;
                  setState(() => _isEditing = true);
                },
                child: Text(
                  playlist.name,
                  style: AuraTypography.headline,
                ),
              ),
        background: Stack(
          children: [
            Positioned.fill(
              child: _PlaylistBackground(playlist: playlist),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AuraColors.background.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _showDeleteDialog(context),
        ),
      ],
    );
  }

  void _reorderSong(
    PlaylistRepository repo,
    Playlist playlist,
    int oldIndex,
    int newIndex,
  ) {
    HapticFeedback.mediumImpact();
    repo.reorderSongs(playlist.id!, oldIndex, newIndex);
  }

  void _removeSong(PlaylistRepository repo, Playlist playlist, Song song) {
    repo.removeSong(playlist.id!, song.id);
  }

  void _playNext(PlayerController ctrl, Song song) {
    ctrl.playNext(song);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${song.title} sera la siguiente'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _moveToTop(
    PlaylistRepository repo,
    Playlist playlist,
    Song song,
    int currentIndex,
  ) {
    if (currentIndex > 0) {
      repo.reorderSongs(playlist.id!, currentIndex, 0);
    }
  }

  void _playAll(PlayerController ctrl, Playlist playlist) {
    if (playlist.songs.isNotEmpty) {
      ctrl.playSong(playlist.songs.first, queue: playlist.songs);
    }
  }

  void _shuffleAll(PlayerController ctrl, Playlist playlist) {
    if (playlist.songs.isNotEmpty) {
      final shuffled = List<Song>.from(playlist.songs)..shuffle();
      ctrl.playSong(shuffled.first, queue: shuffled);
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  void _showDeleteDialog(BuildContext ctx) {
    showAuraDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar playlist'),
        content: Text('¿Eliminar "${_playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<PlaylistRepository>().deletePlaylist(_playlist.id!);
              Navigator.pop(ctx);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AuraColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistBackground extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistBackground({required this.playlist});

  @override
  Widget build(BuildContext context) {
    if (playlist.songs.isEmpty) {
      return Container(
        color: AuraColors.surfaceHigh,
        child: const Icon(
          Icons.queue_music,
          color: AuraColors.primary,
          size: 80,
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
          size: 80,
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onPlayNext;
  final VoidCallback onMoveToTop;

  const _SongTile({
    required this.song,
    required this.index,
    required this.onTap,
    required this.onRemove,
    required this.onPlayNext,
    required this.onMoveToTop,
  });

  @override
  Widget build(BuildContext context) {
    final txt = AuraColors.textOf(context);
    final txtMuted = AuraColors.textMutedOf(context);
    final surfaceHigh = AuraColors.surfaceHighOf(context);
    final playing = context.watch<PlayerController>().currentSong?.id == song.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.lg,
        vertical: AuraSpacing.xs,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AuraRadius.sm),
        child: SizedBox(
          width: 48,
          height: 48,
          child: QueryArtworkWidget(
            id: song.albumId ?? 0,
            type: ArtworkType.ALBUM,
            nullArtworkWidget: Container(
              color: surfaceHigh,
              child: Icon(
                Icons.music_note,
                color: playing ? AuraColors.primary : txtMuted,
              ),
            ),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: playing ? AuraColors.primary : txt,
          fontWeight: playing ? FontWeight.w600 : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        '${song.artist} • ${song.durationFormatted}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: txtMuted, fontSize: 12),
      ),
      trailing: playing
          ? const Icon(Icons.equalizer, color: AuraColors.primary, size: 20)
          : const Icon(Icons.drag_handle, color: AuraColors.textMuted),
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
    );
  }

  void _showContextMenu(BuildContext ctx) {
    HapticFeedback.mediumImpact();
    showAuraBottomSheet(
      context: ctx,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Reproducir siguiente'),
              onTap: () {
                Navigator.pop(context);
                onPlayNext();
              },
            ),
            ListTile(
              leading: const Icon(Icons.vertical_align_top),
              title: const Text('Mover al inicio'),
              onTap: () {
                Navigator.pop(context);
                onMoveToTop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AuraColors.error),
              title: const Text('Eliminar de la lista',
                  style: TextStyle(color: AuraColors.error)),
              onTap: () {
                Navigator.pop(context);
                onRemove();
              },
            ),
          ],
        ),
      ),
    );
  }
}
