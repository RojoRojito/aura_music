import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../data/models/song.dart';
import '../../data/models/song_stats.dart';
import '../../services/media_scanner.dart';
import '../../widgets/song_tile.dart';
import '../discover/recommendation_engine.dart';
import '../player/player_controller.dart';

class ForYouScreen extends StatelessWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<RecommendationEngine>();
    final picks = engine.topPicks;

    return Scaffold(
      backgroundColor: AuraColors.background,
      appBar: AppBar(
        backgroundColor: AuraColors.background,
        elevation: 0,
        title: const Text('Para Ti',
            style: TextStyle(
                color: AuraColors.text,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
      ),
      body: picks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.music_note, color: AuraColors.textMuted, size: 64),
                  SizedBox(height: 16),
                  Text('Escucha más canciones para recibir recomendaciones',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AuraColors.textMuted, fontSize: 16)),
                ],
              ),
            )
          : _SongList(picks: picks),
      floatingActionButton: picks.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _playAll(context),
              backgroundColor: AuraColors.primary,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Reproducir todo'),
            )
          : null,
    );
  }

  Future<void> _playAll(BuildContext context) async {
    final engine = context.read<RecommendationEngine>();
    final scanner = context.read<MediaScanner>();
    final ctrl = context.read<PlayerController>();
    final songs = await engine.statsToSongs(engine.topPicks, scanner);
    if (songs.isNotEmpty) {
      ctrl.playSong(songs.first, queue: songs);
    }
  }
}

class _SongList extends StatefulWidget {
  final List<SongStats> picks;
  const _SongList({required this.picks});

  @override
  State<_SongList> createState() => _SongListState();
}

class _SongListState extends State<_SongList> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final scanner = context.read<MediaScanner>();
    final engine = context.read<RecommendationEngine>();
    final songs = await engine.statsToSongs(engine.topPicks, scanner);
    if (mounted) setState(() { _songs = songs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AuraLoadingIndicator();
    }
    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.music_note, color: AuraColors.textMuted, size: 64),
            SizedBox(height: 16),
            Text('Escucha más canciones para recibir recomendaciones',
                textAlign: TextAlign.center,
                style: TextStyle(color: AuraColors.textMuted, fontSize: 16)),
          ],
        ),
      );
    }
    final ctrl = context.watch<PlayerController>();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 160),
      itemCount: _songs.length,
      itemBuilder: (_, i) {
        final song = _songs[i];
        return SongTile(
          song: song,
          onTap: () => ctrl.playSong(song, queue: _songs),
        );
      },
    );
  }
}
