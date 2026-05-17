import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../player/player_controller.dart';
import 'library_controller.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../widgets/loading_indicator.dart';
import '../home/widgets/recommendation_section.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() { _debounce?.cancel(); _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bg = AuraColors.backgroundOf(context);
    final txt = AuraColors.textOf(context);
    final txtMuted = AuraColors.textMutedOf(context);
    return Consumer<LibraryController>(builder: (_, ctrl, __) => Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: _searching
          ? TextField(
              controller: _searchCtrl, autofocus: true,
              style: TextStyle(color: txt),
              decoration: InputDecoration(
                hintText: 'Buscar canciones...',
                hintStyle: TextStyle(color: txtMuted),
                border: InputBorder.none),
              onChanged: (q) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  ctrl.search(q);
                });
              })
          : Text('Canciones', style: TextStyle(
              color: txt, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search, color: txtMuted),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) { _debounce?.cancel(); _searchCtrl.clear(); ctrl.search(''); }
            }),
          IconButton(
            icon: Icon(Icons.refresh, color: txtMuted),
            onPressed: ctrl.scanLibrary),
        ],
      ),
      body: _buildBody(ctrl),
      floatingActionButton: ctrl.songs.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: ctrl.shuffleAll,
            backgroundColor: AuraColors.primary,
            icon: const Icon(Icons.shuffle),
            label: const Text('Aleatorio'))
        : null,
    ));
  }

  Widget _buildBody(LibraryController ctrl) {
    final txtMuted = AuraColors.textMutedOf(context);
    final txt = AuraColors.textOf(context);
    final surfaceHigh = AuraColors.surfaceHighOf(context);
    switch (ctrl.status) {
      case LibraryStatus.loading:
        return const AuraLoadingIndicator();
      case LibraryStatus.noPermission:
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.no_accounts, color: AuraColors.accent, size: 64),
          const SizedBox(height: 16),
          Text('Permiso de audio denegado', style: TextStyle(color: AuraColors.textMuted, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Concede permisos para ver tus canciones', style: TextStyle(color: AuraColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await openAppSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Abrir ajustes'),
            style: ElevatedButton.styleFrom(backgroundColor: AuraColors.primary),
          ),
        ]));
      case LibraryStatus.error:
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: AuraColors.accent, size: 48),
          const SizedBox(height: 12),
          Text(ctrl.errorMessage ?? 'Error desconocido', style: TextStyle(color: txtMuted)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: ctrl.scanLibrary, child: const Text('Reintentar')),
        ]));
      case LibraryStatus.empty:
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.music_off, color: txtMuted, size: 64),
          const SizedBox(height: 16),
          Text('No se encontraron canciones', style: TextStyle(color: txtMuted, fontSize: 16)),
        ]));
      case LibraryStatus.initial:
      case LibraryStatus.loaded:
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const RecommendationSection(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Text('TODAS LAS CANCIONES',
                        style: TextStyle(
                            color: txtMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${ctrl.songs.length} canciones',
                        style:
                            TextStyle(color: txtMuted, fontSize: 11)),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _SongTile(
                  song: ctrl.songs[i],
                  onTap: () => ctrl.playSong(ctrl.songs[i])),
              childCount: ctrl.songs.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ]);
    }
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 48, height: 48,
            child: QueryArtworkWidget(
              id: song.albumId ?? 0, type: ArtworkType.ALBUM,
              nullArtworkWidget: Container(
                color: surfaceHigh,
                child: Icon(Icons.music_note,
                    color: playing ? AuraColors.primary : txtMuted))))),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: playing ? AuraColors.primary : txt,
                fontWeight: playing ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14)),
        subtitle: Text('${song.artist} • ${song.durationFormatted}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: txtMuted, fontSize: 12)),
        trailing: playing
            ? const Icon(Icons.equalizer, color: AuraColors.primary, size: 20)
            : null,
        onTap: onTap,
      ),
    );
  }
}