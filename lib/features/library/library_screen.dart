import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../player/player_controller.dart';
import 'library_controller.dart';
import '../../widgets/add_to_playlist_sheet.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryController>(builder: (_, ctrl, __) => Scaffold(
      backgroundColor: AuraColors.background,
      appBar: AppBar(
        backgroundColor: AuraColors.background,
        elevation: 0,
        title: _searching
          ? TextField(
              controller: _searchCtrl, autofocus: true,
              style: const TextStyle(color: AuraColors.text),
              decoration: InputDecoration(
                hintText: 'Buscar canciones...',
                hintStyle: TextStyle(color: AuraColors.textMuted),
                border: InputBorder.none),
              onChanged: ctrl.search)
          : const Text('Canciones', style: TextStyle(
              color: AuraColors.text, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search, color: AuraColors.textMuted),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) { _searchCtrl.clear(); ctrl.search(''); }
            }),
          IconButton(
            icon: const Icon(Icons.refresh, color: AuraColors.textMuted),
            onPressed: ctrl.scanLibrary),
        ],
      ),
      body: ctrl.isLoading
        ? const Center(child: CircularProgressIndicator(color: AuraColors.primary))
        : ctrl.error != null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, color: AuraColors.accent, size: 48),
              const SizedBox(height: 12),
              Text(ctrl.error!, style: const TextStyle(color: AuraColors.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: ctrl.scanLibrary, child: const Text('Reintentar'))]))
          : ctrl.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.music_off, color: AuraColors.textMuted, size: 64),
                const SizedBox(height: 16),
                Text('No se encontraron canciones',
                    style: TextStyle(color: AuraColors.textMuted, fontSize: 16))]))
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(children: [
                    Text('\${ctrl.songs.length} canciones',
                        style: TextStyle(color: AuraColors.textMuted, fontSize: 13))])),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160),
                    itemCount: ctrl.songs.length,
                    itemBuilder: (_, i) => _SongTile(
                      song: ctrl.songs[i],
                      onTap: () => ctrl.playSong(ctrl.songs[i])))),
              ]),
      floatingActionButton: ctrl.songs.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: ctrl.shuffleAll,
            backgroundColor: AuraColors.primary,
            icon: const Icon(Icons.shuffle),
            label: const Text('Aleatorio'))
        : null,
    ));
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  const _SongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final playing = context.watch<PlayerController>().currentSong?.id == song.id;
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
                color: AuraColors.surfaceHigh,
                child: Icon(Icons.music_note,
                    color: playing ? AuraColors.primary : AuraColors.textMuted))))),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: playing ? AuraColors.primary : AuraColors.text,
                fontWeight: playing ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14)),
        subtitle: Text('${song.artist} • ${song.durationFormatted}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
        trailing: playing
            ? const Icon(Icons.equalizer, color: AuraColors.primary, size: 20)
            : null,
        onTap: onTap,
      ),
    );
  }
}
}
