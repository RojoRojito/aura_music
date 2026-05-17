import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens/tokens.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../services/audio_handler.dart';
import '../../services/dynamic_theme_service.dart';
import '../../services/equalizer_service.dart';
import 'player_controller.dart';
import '../equalizer/equalizer_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  bool _isSeeking = false;
  double _seekPosition = 0;
  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: AuraAnimation.ambient,
    )..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: AuraAnimation.ambientCurve),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final themeService = context.watch<DynamicThemeService>();
    final dominant = themeService.dominantColor;
    final accent = themeService.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AuraColors.background : AuraColors.lightBackground;

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 300) {
            ctrl.previous();
            HapticFeedback.lightImpact();
          } else if (details.primaryVelocity! < -300) {
            ctrl.next();
            HapticFeedback.lightImpact();
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 300) {
            Navigator.pop(context);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: _buildGradient(dominant, accent, bg),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _topBar(context, ctrl),
                const SizedBox(height: AuraSpacing.lg),
                _albumArt(ctrl, dominant),
                const SizedBox(height: AuraSpacing.xxl),
                _songInfo(ctrl),
                const SizedBox(height: AuraSpacing.md),
                _seekBar(ctrl),
                const SizedBox(height: AuraSpacing.lg),
                _controls(ctrl, dominant),
                const Spacer(),
                _extras(ctrl),
                _swipeUpHandle(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _buildGradient(Color dominant, Color accent, Color bg) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(dominant.withOpacity(0.3), bg, _bgAnimation.value)!,
        bg,
        Color.lerp(accent.withOpacity(0.15), bg, 1 - _bgAnimation.value)!,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  Widget _topBar(BuildContext ctx, PlayerController ctrl) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpacing.lg,
          vertical: AuraSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
              color: AuraColors.text,
              onPressed: () => Navigator.pop(ctx),
            ),
            Column(
              children: [
                Text(
                  'REPRODUCIENDO',
                  style: AuraTypography.overline.copyWith(
                    color: AuraColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ctrl.currentSong?.album ?? '',
                  style: AuraTypography.caption.copyWith(
                    color: AuraColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              color: AuraColors.textMuted,
              onPressed: () => _showOptions(ctx, ctrl),
            ),
          ],
        ),
      );

  Widget _albumArt(PlayerController ctrl, Color dominant) {
    return AnimatedScale(
      scale: ctrl.isPlaying ? 1.0 : 0.92,
      duration: AuraAnimation.slow,
      curve: AuraAnimation.easeOut,
      child: Container(
        height: 320,
        width: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AuraRadius.xl),
          boxShadow: [
            BoxShadow(
              color: dominant.withOpacity(0.4),
              blurRadius: 60,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AuraRadius.xl),
          child: QueryArtworkWidget(
            id: ctrl.currentSong?.albumId ?? 0,
            type: ArtworkType.ALBUM,
            quality: 100,
            size: 512,
            nullArtworkWidget: Container(
              color: AuraColors.surfaceHigh,
              child: const Icon(
                Icons.music_note,
                color: AuraColors.primary,
                size: 80,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _songInfo(PlayerController ctrl) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.xl),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctrl.currentSong?.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraTypography.display.copyWith(
                      color: AuraColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ctrl.currentSong?.artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraTypography.body.copyWith(
                      color: AuraColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Consumer<FavoritesRepository>(
              builder: (_, favRepo, __) {
                final songId = ctrl.currentSong?.id;
                if (songId == null) return const SizedBox.shrink();
                final isFav = favRepo.isFavorite(songId);
                return IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? AuraColors.accent : AuraColors.textMuted,
                  ),
                  onPressed: () => favRepo.toggleFavorite(songId),
                );
              },
            ),
          ],
        ),
      );

  Widget _seekBar(PlayerController ctrl) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.lg),
        child: StreamBuilder<PositionData>(
          stream: ctrl.pos,
          builder: (_, snap) {
            final pos = snap.data?.position ?? Duration.zero;
            final dur = snap.data?.duration ?? Duration.zero;
            final prog = dur.inMilliseconds > 0
                ? pos.inMilliseconds / dur.inMilliseconds
                : 0.0;
            return Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: AuraColors.primary,
                    inactiveTrackColor: AuraColors.divider,
                    thumbColor: AuraColors.primary,
                  ),
                  child: Slider(
                    value: _isSeeking ? _seekPosition : prog.clamp(0.0, 1.0),
                    onChangeStart: (v) {
                      setState(() {
                        _isSeeking = true;
                        _seekPosition = v;
                      });
                    },
                    onChanged: (v) {
                      setState(() => _seekPosition = v);
                    },
                    onChangeEnd: (v) {
                      setState(() => _isSeeking = false);
                      ctrl.seek(Duration(
                        milliseconds: (v * dur.inMilliseconds).round(),
                      ));
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(pos),
                        style: AuraTypography.caption.copyWith(
                          color: AuraColors.textMuted,
                        ),
                      ),
                      Text(
                        _fmt(dur),
                        style: AuraTypography.caption.copyWith(
                          color: AuraColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

  Widget _controls(PlayerController ctrl, Color dominant) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 40),
            color: AuraColors.text,
            onPressed: () {
              ctrl.previous();
              HapticFeedback.mediumImpact();
            },
          ),
          GestureDetector(
            onTap: () {
              ctrl.togglePlay();
              HapticFeedback.mediumImpact();
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuraColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: dominant.withOpacity(0.5),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                ctrl.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 40),
            color: AuraColors.text,
            onPressed: () {
              ctrl.next();
              HapticFeedback.mediumImpact();
            },
          ),
        ],
      );

  Widget _extras(PlayerController ctrl) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.xxl),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildExtraButton(
              icon: Icons.shuffle_rounded,
              active: ctrl.shuffleEnabled,
              onTap: () => ctrl.setShuffle(!ctrl.shuffleEnabled),
            ),
            _buildExtraButton(
              icon: Icons.queue_music_rounded,
              active: false,
              onTap: () => _showQueue(context, ctrl),
            ),
            _buildEqButton(),
            _buildRepeatButton(ctrl),
          ],
        ),
      );

  Widget _buildExtraButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: active
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AuraColors.primary.withOpacity(0.35),
                  blurRadius: 12,
                ),
              ],
            )
          : null,
      child: IconButton(
        icon: Icon(icon),
        color: active ? AuraColors.primary : AuraColors.textMuted,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildEqButton() {
    return Consumer<EqualizerService>(
      builder: (_, eqSvc, __) {
        final active = eqSvc.isEnabled;
        final available = eqSvc.isAvailable;
        return Container(
          decoration: active
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AuraColors.primary.withOpacity(0.35),
                      blurRadius: 12,
                    ),
                  ],
                )
              : null,
          child: IconButton(
            icon: const Icon(Icons.equalizer_rounded),
            color: !available
                ? AuraColors.textMuted.withOpacity(0.3)
                : active
                    ? AuraColors.primary
                    : AuraColors.textMuted,
            tooltip: !available ? 'Ecualizador no disponible' : 'Ecualizador',
            onPressed: !available
                ? null
                : () {
                    final song =
                        context.read<PlayerController>().currentSong;
                    if (song == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EqualizerScreen(song: song),
                      ),
                    );
                  },
          ),
        );
      },
    );
  }

  Widget _buildRepeatButton(PlayerController ctrl) {
    final icon = ctrl.loopMode == LoopMode.off
        ? Icons.repeat_rounded
        : ctrl.loopMode == LoopMode.all
            ? Icons.repeat_on_rounded
            : Icons.repeat_one_on_rounded;
    return _buildExtraButton(
      icon: icon,
      active: ctrl.loopMode != LoopMode.off,
      onTap: _cycleRepeat,
    );
  }

  Widget _swipeUpHandle() => Padding(
        padding: const EdgeInsets.only(bottom: AuraSpacing.md),
        child: GestureDetector(
          onTap: () => _showQueue(context, context.read<PlayerController>()),
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity! < -300) {
              _showQueue(context, context.read<PlayerController>());
            }
          },
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AuraColors.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  void _cycleRepeat() {
    final ctrl = context.read<PlayerController>();
    final current = ctrl.loopMode;
    final next = current == LoopMode.off
        ? LoopMode.all
        : current == LoopMode.all
            ? LoopMode.one
            : LoopMode.off;
    ctrl.setRepeat(next);
    HapticFeedback.lightImpact();
  }

  void _showOptions(BuildContext ctx, PlayerController ctrl) =>
      showModalBottomSheet(
        context: ctx,
        backgroundColor: AuraColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
        ),
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.queue_play_next_rounded),
              title: const Text('Reproducir siguiente'),
              onTap: () {
                Navigator.pop(ctx);
                _showPlayNextSongPicker(ctx, ctrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Información de la canción'),
              onTap: () {
                Navigator.pop(ctx);
                _showSongInfo(ctx, ctrl);
              },
            ),
          ],
        ),
      );

  void _showPlayNextSongPicker(BuildContext ctx, PlayerController ctrl) {
    final currentSong = ctrl.currentSong;
    if (currentSong == null) return;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AuraColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(AuraSpacing.lg),
            child: Text(
              'Selecciona una canción para reproducir después',
              style: AuraTypography.body,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: ctrl.queue.length,
              itemBuilder: (_, i) {
                final s = ctrl.queue[i];
                if (s.id == currentSong.id) return const SizedBox.shrink();
                return ListTile(
                  title: Text(
                    s.title,
                    style: AuraTypography.title,
                  ),
                  subtitle: Text(
                    s.artist,
                    style: AuraTypography.caption,
                  ),
                  onTap: () async {
                    await ctrl.playNext(s);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('${s.title} reproducirá después'),
                          backgroundColor: AuraColors.surfaceHigh,
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSongInfo(BuildContext ctx, PlayerController ctrl) {
    final s = ctrl.currentSong;
    if (s == null) return;
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AuraColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.lg),
        ),
        title: Text(s.title, style: AuraTypography.headline),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Artista', s.artist),
            _infoRow('Álbum', s.album),
            _infoRow('Duración', s.durationFormatted),
            if (s.year != null) _infoRow('Año', '${s.year}'),
            if (s.genre != null) _infoRow('Género', s.genre!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpacing.xs),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: AuraTypography.caption.copyWith(
                color: AuraColors.textMuted,
              ),
            ),
            Expanded(
              child: Text(
                val,
                style: AuraTypography.caption.copyWith(
                  color: AuraColors.text,
                ),
              ),
            ),
          ],
        ),
      );

  void _showQueue(BuildContext ctx, PlayerController ctrl) =>
      showModalBottomSheet(
        context: ctx,
        backgroundColor: AuraColors.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AuraRadius.lg),
          ),
        ),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (_, sc) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AuraSpacing.lg),
                child: Text(
                  'Cola de reproducción',
                  style: AuraTypography.headline,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: ctrl.queue.length,
                  itemBuilder: (_, i) {
                    final s = ctrl.queue[i];
                    final cur = i == ctrl.currentIndex;
                    return ListTile(
                      leading: cur
                          ? const Icon(Icons.equalizer, color: AuraColors.primary)
                          : Text(
                              '${i + 1}',
                              style: AuraTypography.caption.copyWith(
                                color: AuraColors.textMuted,
                              ),
                            ),
                      title: Text(
                        s.title,
                        style: AuraTypography.title.copyWith(
                          color: cur ? AuraColors.primary : AuraColors.text,
                          fontWeight: cur ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        s.artist,
                        style: AuraTypography.caption.copyWith(
                          color: AuraColors.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
