import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../../services/audio_handler.dart';
import 'player_controller.dart';

class PlayerScreen extends StatefulWidget {
  final Song song;
  const PlayerScreen({super.key, required this.song});
  @override State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  LoopMode _loop = LoopMode.off;
  bool _shuffle = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final accent = ctrl.accentColor;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color.lerp(accent, AuraColors.background, 0.7)!, AuraColors.background]),
        ),
        child: SafeArea(child: Column(children: [
          _topBar(context, ctrl),
          const SizedBox(height: 20),
          _albumArt(ctrl),
          const SizedBox(height: 28),
          _songInfo(ctrl),
          const SizedBox(height: 16),
          _seekBar(ctrl),
          const SizedBox(height: 12),
          _controls(ctrl),
          const SizedBox(height: 20),
          _extras(ctrl),
        ])),
      ),
    );
  }

  Widget _topBar(BuildContext ctx, PlayerController ctrl) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(
        icon: const Icon(Icons.keyboard_arrow_down, color: AuraColors.text, size: 30),
        onPressed: () => Navigator.pop(ctx)),
      Column(children: [
        const Text('REPRODUCIENDO', style: TextStyle(
            color: AuraColors.textMuted, fontSize: 10, letterSpacing: 2)),
        Text(ctrl.currentSong?.album ?? widget.song.album,
            style: const TextStyle(
                color: AuraColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
      IconButton(
        icon: const Icon(Icons.more_vert, color: AuraColors.textMuted),
        onPressed: () => _showOptions(ctx, ctrl)),
    ]),
  );

  Widget _albumArt(PlayerController ctrl) => AnimatedScale(
    scale: ctrl.isPlaying ? 1.0 : 0.88,
    duration: const Duration(milliseconds: 300),
    child: Container(
      height: 256, width: 256,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: AuraColors.primary.withOpacity(0.4),
          blurRadius: 40, offset: const Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: QueryArtworkWidget(
          id: (ctrl.currentSong?.albumId ?? widget.song.albumId) ?? 0,
          type: ArtworkType.ALBUM, quality: 100, size: 512,
          nullArtworkWidget: Container(
            color: AuraColors.surfaceHigh,
            child: const Icon(Icons.music_note, color: AuraColors.primary, size: 80))),
      ),
    ),
  );

  Widget _songInfo(PlayerController ctrl) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ctrl.currentSong?.title ?? widget.song.title,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AuraColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(ctrl.currentSong?.artist ?? widget.song.artist,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AuraColors.textMuted, fontSize: 14)),
      ])),
      Icon(Icons.favorite_border, color: AuraColors.textMuted),
    ]),
  );

  Widget _seekBar(PlayerController ctrl) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: StreamBuilder<PositionData>(
      stream: ctrl.pos,
      builder: (_, snap) {
        final pos = snap.data?.position ?? Duration.zero;
        final dur = snap.data?.duration ?? Duration.zero;
        final prog = dur.inMs > 0 ? pos.inMs / dur.inMs : 0.0;
        return Column(children: [
          Slider(
            value: prog.clamp(0.0, 1.0),
            onChanged: (v) => ctrl.seek(
                Duration(milliseconds: (v * dur.inMs).round()))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_fmt(pos),
                  style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
              Text(_fmt(dur),
                  style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
            ])),
        ]);
      }),
  );

  Widget _controls(PlayerController ctrl) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      IconButton(icon: const Icon(Icons.skip_previous_rounded,
          color: AuraColors.text, size: 40), onPressed: ctrl.previous),
      GestureDetector(
        onTap: ctrl.togglePlay,
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: AuraColors.primary,
            boxShadow: [BoxShadow(
                color: AuraColors.primary.withOpacity(0.5),
                blurRadius: 24, spreadRadius: 4)]),
          child: Icon(
            ctrl.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white, size: 38))),
      IconButton(icon: const Icon(Icons.skip_next_rounded,
          color: AuraColors.text, size: 40), onPressed: ctrl.next),
    ],
  );

  Widget _extras(PlayerController ctrl) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(
        icon: Icon(Icons.shuffle,
            color: _shuffle ? AuraColors.primary : AuraColors.textMuted),
        onPressed: () {
          setState(() => _shuffle = !_shuffle);
          ctrl.setShuffle(_shuffle);
        }),
      IconButton(
        icon: const Icon(Icons.queue_music, color: AuraColors.textMuted),
        onPressed: () => _showQueue(context, ctrl)),
      IconButton(
        icon: Icon(
          _loop == LoopMode.off ? Icons.repeat
            : _loop == LoopMode.all ? Icons.repeat_on_outlined
            : Icons.repeat_one_on_outlined,
          color: _loop != LoopMode.off ? AuraColors.primary : AuraColors.textMuted),
        onPressed: _cycleRepeat),
    ]),
  );

  void _cycleRepeat() {
    setState(() => _loop = _loop == LoopMode.off ? LoopMode.all
        : _loop == LoopMode.all ? LoopMode.one : LoopMode.off);
    context.read<PlayerController>().setRepeat(_loop);
  }

  void _showOptions(BuildContext ctx, PlayerController ctrl) =>
    showModalBottomSheet(context: ctx,
      backgroundColor: AuraColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.queue_play_next, color: AuraColors.text),
            title: const Text('Reproducir siguiente',
                style: TextStyle(color: AuraColors.text)),
            onTap: () => Navigator.pop(ctx)),
        ListTile(leading: const Icon(Icons.info_outline, color: AuraColors.text),
            title: const Text('Información de la canción',
                style: TextStyle(color: AuraColors.text)),
            onTap: () {
              Navigator.pop(ctx);
              _showSongInfo(ctx, ctrl);
            }),
      ]));

  void _showSongInfo(BuildContext ctx, PlayerController ctrl) {
    final s = ctrl.currentSong ?? widget.song;
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: AuraColors.surface,
      title: Text(s.title, style: const TextStyle(color: AuraColors.text)),
      content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Artista', s.artist),
            _infoRow('Álbum', s.album),
            _infoRow('Duración', s.durationFormatted),
            if (s.year != null) _infoRow('Año', '${s.year}'),
            if (s.genre != null) _infoRow('Género', s.genre!),
          ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cerrar', style: TextStyle(color: AuraColors.primary)))],
    ));
  }

  Widget _infoRow(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(color: AuraColors.textMuted, fontSize: 13)),
      Expanded(child: Text(val, style: const TextStyle(color: AuraColors.text, fontSize: 13))),
    ]));

  void _showQueue(BuildContext ctx, PlayerController ctrl) =>
    showModalBottomSheet(context: ctx,
      backgroundColor: AuraColors.surface, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.6,
        builder: (_, sc) => Column(children: [
          const Padding(padding: EdgeInsets.all(16),
              child: Text('Cola de reproducción',
                  style: TextStyle(color: AuraColors.text,
                      fontSize: 16, fontWeight: FontWeight.bold))),
          Expanded(child: ListView.builder(
            controller: sc,
            itemCount: ctrl.queue.length,
            itemBuilder: (_, i) {
              final s = ctrl.queue[i];
              final cur = i == ctrl.currentIndex;
              return ListTile(
                leading: cur
                  ? const Icon(Icons.equalizer, color: AuraColors.primary)
                  : Text('${i+1}', style: const TextStyle(color: AuraColors.textMuted)),
                title: Text(s.title, style: TextStyle(
                    color: cur ? AuraColors.primary : AuraColors.text,
                    fontWeight: cur ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
                subtitle: Text(s.artist,
                    style: const TextStyle(color: AuraColors.textMuted, fontSize: 11)),
              );
            }))
        ])));

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

extension on Duration {
  int get inMs => inMilliseconds;
}
