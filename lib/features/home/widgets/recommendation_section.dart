import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/song_stats.dart';
import '../../../services/media_scanner.dart';
import '../../discover/recommendation_engine.dart';
import '../../player/player_controller.dart';
import '../for_you_screen.dart';

class RecommendationSection extends StatefulWidget {
  const RecommendationSection({super.key});

  @override
  State<RecommendationSection> createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<RecommendationSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<RecommendationEngine>();

    if (engine.isLoading) return _buildShimmer();
    if (!engine.hasData) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopPicks(engine),
        const SizedBox(height: 24),
        _buildMostPlayed(engine),
      ],
    );
  }

  Widget _buildShimmer() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (_, __) => AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, child) => Opacity(
            opacity: 0.4 + _shimmerCtrl.value * 0.6,
            child: child,
          ),
          child: Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AuraColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopPicks(RecommendationEngine engine) {
    final picks = engine.topPicks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('PARA TI',
                  style: TextStyle(
                      color: AuraColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ForYouScreen())),
                child: const Text('Ver todo',
                    style: TextStyle(color: AuraColors.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: picks.length,
            itemBuilder: (_, i) => _TopPickCard(
              stats: picks[i],
              onTap: () => _playFromPicks(picks, picks[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMostPlayed(RecommendationEngine engine) {
    final played = engine.mostPlayed;
    if (played.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('MÁS ESCUCHADAS',
                  style: TextStyle(
                      color: AuraColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              Text('Top ${played.length}',
                  style: const TextStyle(
                      color: AuraColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: played.length,
          itemBuilder: (_, i) => _MostPlayedTile(
            stats: played[i],
            rank: i + 1,
            onTap: () => _playFromPicks(played, played[i]),
          ),
        ),
      ],
    );
  }

  Future<void> _playFromPicks(
      List<SongStats> statsList, SongStats target) async {
    final scanner = context.read<MediaScanner>();
    final engine = context.read<RecommendationEngine>();
    final ctrl = context.read<PlayerController>();
    final songs = await engine.statsToSongs(statsList, scanner);
    final match = songs.where((s) => s.id == target.songId);
    if (match.isNotEmpty) {
      ctrl.playSong(match.first, queue: songs);
    }
  }
}

class _TopPickCard extends StatelessWidget {
  final SongStats stats;
  final VoidCallback onTap;

  const _TopPickCard({required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: QueryArtworkWidget(
                  id: stats.songId,
                  type: ArtworkType.ALBUM,
                  nullArtworkWidget: Container(
                    color: AuraColors.surface,
                    child: const Center(
                      child: Icon(Icons.music_note,
                          color: AuraColors.primary, size: 48),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(stats.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Text(stats.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AuraColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MostPlayedTile extends StatelessWidget {
  final SongStats stats;
  final int rank;
  final VoidCallback onTap;

  const _MostPlayedTile({
    required this.stats,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: QueryArtworkWidget(
                id: stats.songId,
                type: ArtworkType.ALBUM,
                nullArtworkWidget: Container(
                  color: AuraColors.surface,
                  child: const Icon(Icons.music_note,
                      color: AuraColors.textMuted),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AuraColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text('$rank',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10)),
            ),
          ),
        ],
      ),
      title: Text(stats.title,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AuraColors.text, fontSize: 14)),
      subtitle: Text(stats.artist,
          maxLines: 1,
          style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${stats.playCount} plays',
              style: const TextStyle(
                  color: AuraColors.primary, fontSize: 12)),
          Text(_formatDuration(stats.totalListenedSeconds),
              style: const TextStyle(
                  color: AuraColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  String _formatDuration(double totalSeconds) {
    final d = Duration(seconds: totalSeconds.round());
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
