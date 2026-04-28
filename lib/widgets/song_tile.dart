import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../features/player/player_controller.dart';
import 'add_to_playlist_sheet.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool showAlbumArt;
  final Widget? trailing;
  final bool enableActions;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.showAlbumArt = true,
    this.trailing,
    this.enableActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final playing = context.watch<PlayerController>().currentSong?.id == song.id;
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: showAlbumArt
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 48, height: 48,
              child: QueryArtworkWidget(
                id: song.albumId ?? 0, type: ArtworkType.ALBUM,
                nullArtworkWidget: Container(
                  color: AuraColors.surfaceHigh,
                  child: Icon(Icons.music_note,
                      color: playing ? AuraColors.primary : AuraColors.textMuted)))))
        : null,
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: playing ? AuraColors.primary : AuraColors.text,
              fontWeight: playing ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14)),
      subtitle: Text('${song.artist} • ${song.durationFormatted}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
      trailing: trailing ??
        (playing ? const Icon(Icons.equalizer, color: AuraColors.primary, size: 20) : null),
      onTap: onTap,
    );

    if (!enableActions) return tile;

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
      child: tile,
    );
  }
}