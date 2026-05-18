import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens/tokens.dart';
import '../../data/models/song.dart';
import '../../data/models/song_stats.dart';
import '../player/player_controller.dart';
import 'library_controller.dart';
import '../../widgets/aura_animations.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../widgets/aura_empty_state.dart';
import '../../widgets/aura_loading_state.dart';
import '../../services/media_scanner.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryController>(builder: (_, ctrl, __) {
      return Column(
        children: [
          _buildSearchBar(ctrl),
          Expanded(child: _buildBody(ctrl)),
        ],
      );
    });
  }

  Widget _buildSearchBar(LibraryController ctrl) {
    final txt = AuraColors.textOf(context);
    final txtMuted = AuraColors.textMutedOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.lg,
        vertical: AuraSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _searching
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: TextStyle(color: txt),
                    decoration: InputDecoration(
                      hintText: 'Buscar canciones...',
                      hintStyle: TextStyle(color: txtMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AuraRadius.md),
                      ),
                      filled: true,
                      fillColor: AuraColors.surfaceHigh,
                    ),
                    onChanged: (q) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        ctrl.search(q);
                      });
                    },
                  )
                : const SizedBox.shrink(),
          ),
          if (!_searching) ...[
            IconButton(
              icon: const Icon(Icons.search),
              color: txtMuted,
              onPressed: () => setState(() => _searching = true),
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              color: txtMuted,
              onPressed: () => _showSortOptions(ctrl),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              color: txtMuted,
              onPressed: () {
                ctrl.scanLibrary();
                ctrl.refreshStats();
              },
            ),
          ],
          if (_searching)
            IconButton(
              icon: const Icon(Icons.close),
              color: txtMuted,
              onPressed: () {
                setState(() => _searching = false);
                _debounce?.cancel();
                _searchCtrl.clear();
                ctrl.search('');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBody(LibraryController ctrl) {
    final txtMuted = AuraColors.textMutedOf(context);
    switch (ctrl.status) {
      case LibraryStatus.loading:
        return const AuraLoadingState(state: AuraState.loading);
      case LibraryStatus.noPermission:
        return AuraEmptyState(
          icon: Icons.no_accounts,
          title: 'Permiso de audio denegado',
          message: 'Concede permisos para ver tus canciones',
          actionLabel: 'Abrir ajustes',
          onAction: () async => await openAppSettings(),
        );
      case LibraryStatus.error:
        return AuraEmptyState(
          icon: Icons.error_outline,
          title: 'Error al cargar',
          message: ctrl.errorMessage ?? 'Error desconocido',
          actionLabel: 'Reintentar',
          onAction: ctrl.scanLibrary,
        );
      case LibraryStatus.empty:
        return const AuraEmptyState(
          icon: Icons.music_off,
          title: 'No se encontraron canciones',
          message: 'Escanea tu biblioteca para encontrar música',
        );
      case LibraryStatus.initial:
      case LibraryStatus.loaded:
        return RefreshIndicator(
          onRefresh: () async {
            ctrl.scanLibrary();
            ctrl.refreshStats();
          },
          child: CustomScrollView(
            slivers: [
              if (ctrl.hasSections && !_searching) ...[
                _buildSection(
                  context,
                  'RECIENTES',
                  ctrl.recentlyPlayed,
                  ctrl,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AuraSpacing.xl)),
                _buildSection(
                  context,
                  'MÁS ESCUCHADAS',
                  ctrl.mostPlayed,
                  ctrl,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AuraSpacing.xl)),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.lg),
                  child: Row(
                    children: [
                      Text(
                        _searching ? 'RESULTADOS' : 'TODAS LAS CANCIONES',
                        style: AuraTypography.overline.copyWith(
                          color: txtMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${ctrl.songs.length} canciones',
                        style: AuraTypography.caption.copyWith(color: txtMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AuraSpacing.sm)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _SongTile(
                    song: ctrl.songs[i],
                    onTap: () => ctrl.playSong(ctrl.songs[i]),
                  ),
                  childCount: ctrl.songs.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
        );
    }
  }

  Widget _buildSection(
    BuildContext context,
    String label,
    List<SongStats> stats,
    LibraryController ctrl,
  ) {
    final txtMuted = AuraColors.textMutedOf(context);
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.lg),
            child: Text(label, style: AuraTypography.overline.copyWith(color: txtMuted)),
          ),
          const SizedBox(height: AuraSpacing.sm),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.lg),
              itemCount: stats.length,
              itemBuilder: (_, i) => _SectionCard(
                stat: stats[i],
                onTap: () => _playFromStats(stats, i, ctrl),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playFromStats(
    List<SongStats> stats,
    int index,
    LibraryController ctrl,
  ) async {
    final scanner = context.read<MediaScanner>();
    final ctrl2 = context.read<PlayerController>();
    final song = await scanner.getSongById(stats[index].songId);
    if (song != null) {
      ctrl2.playSong(song);
    }
  }

  void _showSortOptions(LibraryController ctrl) {
    showAuraBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AuraSpacing.lg),
              child: Text(
                'Ordenar por',
                style: AuraTypography.headline,
              ),
            ),
            ...SortOption.values.map((option) {
              final isActive = ctrl.sortOption == option;
              return ListTile(
                leading: Icon(
                  _sortIcon(option),
                  color: isActive ? AuraColors.primary : AuraColors.textMuted,
                ),
                title: Text(
                  _sortLabel(option),
                  style: TextStyle(
                    color: isActive ? AuraColors.primary : AuraColors.text,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isActive
                    ? Icon(
                        ctrl.ascending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color: AuraColors.primary,
                        size: 18,
                      )
                    : null,
                onTap: () {
                  ctrl.setSort(option);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: AuraSpacing.sm),
          ],
        ),
      ),
    );
  }

  IconData _sortIcon(SortOption option) {
    switch (option) {
      case SortOption.title:
        return Icons.sort_by_alpha;
      case SortOption.artist:
        return Icons.person;
      case SortOption.album:
        return Icons.album;
      case SortOption.duration:
        return Icons.timer;
      case SortOption.dateAdded:
        return Icons.calendar_today;
    }
  }

  String _sortLabel(SortOption option) {
    switch (option) {
      case SortOption.title:
        return 'Título';
      case SortOption.artist:
        return 'Artista';
      case SortOption.album:
        return 'Álbum';
      case SortOption.duration:
        return 'Duración';
      case SortOption.dateAdded:
        return 'Fecha agregada';
    }
  }
}

class _SectionCard extends StatelessWidget {
  final SongStats stat;
  final VoidCallback onTap;
  const _SectionCard({required this.stat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surface = AuraColors.surfaceOf(context);
    final txt = AuraColors.textOf(context);
    final txtMuted = AuraColors.textMutedOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: AuraSpacing.md),
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
                child: QueryArtworkWidget(
                  id: stat.songId,
                  type: ArtworkType.ALBUM,
                  nullArtworkWidget: Container(
                    color: AuraColors.surfaceHigh,
                    child: const Icon(
                      Icons.music_note,
                      color: AuraColors.primary,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AuraSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraTypography.label.copyWith(color: txt),
                  ),
                  Text(
                    stat.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  const _SongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final playing = context.watch<PlayerController>().currentSong?.id == song.id;
    final txt = AuraColors.textOf(context);
    final txtMuted = AuraColors.textMutedOf(context);
    final surfaceHigh = AuraColors.surfaceHighOf(context);
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => AddToPlaylistSheet.show(context, song),
            backgroundColor: AuraColors.secondary,
            foregroundColor: Colors.white,
            icon: Icons.playlist_add,
            label: 'Lista',
          ),
        ],
      ),
      child: ListTile(
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
          style: AuraTypography.title.copyWith(
            color: playing ? AuraColors.primary : txt,
            fontWeight: playing ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '${song.artist} • ${song.durationFormatted}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AuraTypography.caption.copyWith(color: txtMuted),
        ),
        trailing: playing
            ? const AuraPlayingBars(height: 14, barWidth: 2.5, spacing: 2)
            : null,
        onTap: onTap,
      ),
    );
  }
}
