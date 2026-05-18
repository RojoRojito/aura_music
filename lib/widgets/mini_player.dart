import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens/tokens.dart';
import '../data/repositories/favorites_repository.dart';
import '../features/player/player_controller.dart';
import '../features/player/player_screen.dart';
import '../services/audio_handler.dart';
import '../services/dynamic_theme_service.dart';
import 'aura_glass.dart';
import 'aura_animations.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final song = ctrl.currentSong;
    if (song == null) return const SizedBox.shrink();

    final themeService = context.watch<DynamicThemeService>();
    final borderColor = themeService.dominantColor.withOpacity(0.3);

    return GestureDetector(
      onTap: () => _navigateToPlayer(context),
      onLongPress: () => _showQuickActions(context, ctrl, song),
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          ctrl.previous();
        } else if (details.primaryVelocity! < 0) {
          ctrl.next();
        }
      },
      child: AuraGlass(
        blurSigma: 20,
        opacity: AuraTranslucency.strong,
        radius: AuraRadius.none,
        borderColor: borderColor,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AuraAnimation.fast,
              curve: AuraAnimation.easeOut,
              height: ctrl.isPlaying ? 64 : 56,
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpacing.lg,
                vertical: AuraSpacing.sm,
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      _buildArtwork(context, song),
                      if (ctrl.isPlaying)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AuraColors.background.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const AuraPlayingBars(
                              height: 10,
                              barWidth: 2,
                              spacing: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AuraSpacing.md),
                  Expanded(child: _buildInfo(context, song)),
                  const SizedBox(width: AuraSpacing.sm),
                  _buildPlayPause(context, ctrl),
                  const SizedBox(width: AuraSpacing.xs),
                  _buildSkipNext(context, ctrl),
                ],
              ),
            ),
            _buildLinearProgress(context, ctrl),
          ],
        ),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context, dynamic song) {
    final themeService = context.watch<DynamicThemeService>();
    final border = Border.all(
      color: themeService.dominantColor.withOpacity(0.4),
      width: 1,
    );

    return Hero(
      tag: 'artwork_${song.id ?? song.albumId ?? 0}',
      flightShuttleBuilder: (_, anim, __, from, to) {
        return AnimatedBuilder(
          animation: anim,
          builder: (ctx, child) {
            return Material(
              color: Colors.transparent,
              child: child,
            );
          },
          child: to.widget,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuraRadius.sm),
        child: Container(
          decoration: BoxDecoration(border: border),
          child: SizedBox(
            width: 40,
            height: 40,
            child: QueryArtworkWidget(
              id: song.albumId ?? 0,
              type: ArtworkType.ALBUM,
              nullArtworkWidget: Container(
                color: AuraColors.surfaceHigh,
                child: const Icon(
                  Icons.music_note,
                  color: AuraColors.primary,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, dynamic song) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MarqueeText(
          text: song.title ?? '',
          style: AuraTypography.label.copyWith(
            color: AuraColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          song.artist ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AuraTypography.caption.copyWith(
            color: AuraColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayPause(BuildContext context, PlayerController ctrl) {
    return IconButton(
      icon: Icon(
        ctrl.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: AuraColors.text,
        size: 28,
      ),
      onPressed: ctrl.togglePlay,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildSkipNext(BuildContext context, PlayerController ctrl) {
    return IconButton(
      icon: const Icon(
        Icons.skip_next_rounded,
        color: AuraColors.textMuted,
        size: 22,
      ),
      onPressed: ctrl.next,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildLinearProgress(BuildContext context, PlayerController ctrl) {
    return StreamBuilder<PositionData>(
      stream: ctrl.pos,
      builder: (_, snap) {
        final pos = snap.data?.position.inMilliseconds ?? 0;
        final dur = snap.data?.duration.inMilliseconds ?? 1;
        final progress = (pos / dur).clamp(0.0, 1.0);

        return LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation(
            Theme.of(context).colorScheme.primary.withOpacity(0.6),
          ),
          minHeight: 2,
        );
      },
    );
  }

  void _navigateToPlayer(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const PlayerScreen(),
        transitionDuration: AuraAnimation.normal,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _showQuickActions(
    BuildContext context,
    PlayerController ctrl,
    dynamic song,
  ) {
    HapticFeedback.mediumImpact();
    final songId = song.id ?? song.albumId ?? 0;
    final favRepo = context.read<FavoritesRepository>();
    final isFav = favRepo.isFavorite(songId);

    showAuraBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? AuraColors.accent : AuraColors.textMuted,
              ),
              title: Text(isFav ? 'Remove from favorites' : 'Add to favorites'),
              onTap: () {
                favRepo.toggleFavorite(songId);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: AuraColors.textMuted),
              title: const Text('Add to queue'),
              onTap: () {
                ctrl.addToQueue(song);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AuraColors.textMuted),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddToPlaylist(context, song);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylist(BuildContext context, dynamic song) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add to playlist — coming in Sprint 8'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _shouldScroll = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(_MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _controller.reset();
      _checkScroll();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _shouldScroll) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _controller.forward(from: 0);
      });
    }
  }

  void _checkScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tp = context.findRenderObject() as RenderBox?;
      if (tp == null) return;
      final textPainter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (textPainter.width > tp.size.width) {
        setState(() => _shouldScroll = true);
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldScroll) {
      return Text(
        widget.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: widget.style,
      );
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (ctx, child) {
        return Transform.translate(
          offset: Offset(-_animation.value * 80, 0),
          child: child,
        );
      },
      child: Text(
        widget.text,
        maxLines: 1,
        style: widget.style,
      ),
    );
  }
}
