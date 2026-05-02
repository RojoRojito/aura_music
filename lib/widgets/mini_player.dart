import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../features/player/player_controller.dart';
import '../features/player/player_screen.dart';
import '../services/audio_handler.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final song = ctrl.currentSong;
    if (song == null) return const SizedBox.shrink();

    return Dismissible(
      key: const Key('mini_player'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.endToStart) {
          await ctrl.next();
        } else {
          await ctrl.previous();
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AuraColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.skip_previous_rounded, color: AuraColors.primary),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AuraColors.secondary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.skip_next_rounded, color: AuraColors.secondary),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => PlayerScreen(song: song),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AuraColors.surfaceHigh.withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AuraColors.divider, width: 0.5)),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 44, height: 44,
                    child: QueryArtworkWidget(
                      id: song.albumId ?? 0, type: ArtworkType.ALBUM,
                      nullArtworkWidget: Container(
                        color: AuraColors.surfaceHigh,
                        child: const Icon(Icons.music_note,
                            color: AuraColors.primary, size: 20))))),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AuraColors.text,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AuraColors.textMuted, fontSize: 11)),
                  ])),
                StreamBuilder<PositionData>(
                  stream: ctrl.pos,
                  builder: (_, snap) {
                    final pos = snap.data?.position.inMilliseconds ?? 0;
                    final dur = snap.data?.duration.inMilliseconds ?? 1;
                    return SizedBox(width: 36, height: 36,
                      child: CircularProgressIndicator(
                        value: (pos / dur).clamp(0.0, 1.0),
                        backgroundColor: AuraColors.divider,
                        valueColor: const AlwaysStoppedAnimation(AuraColors.primary),
                        strokeWidth: 2.5));
                  }),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(ctrl.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AuraColors.text, size: 28),
                  onPressed: ctrl.togglePlay),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded,
                      color: AuraColors.textMuted, size: 24),
                  onPressed: ctrl.next),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}