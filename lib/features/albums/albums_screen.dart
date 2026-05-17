import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../services/media_scanner.dart';
import 'album_detail_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});
  @override State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<AlbumModel> _albums = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final albums = await context.read<MediaScanner>().scanAlbums();
    setState(() { _albums = albums; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final bg = AuraColors.backgroundOf(context);
    final txt = AuraColors.textOf(context);
    final txtMuted = AuraColors.textMutedOf(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Albums', style: TextStyle(
            color: txt, fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: _loading
        ? const AuraLoadingIndicator()
        : _albums.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.album_outlined, color: txtMuted, size: 64),
              const SizedBox(height: 16),
              Text('No hay albums', style: TextStyle(color: txtMuted, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Escanea tu biblioteca para encontrar albums',
                  style: TextStyle(color: txtMuted, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Escaneear'),
                style: ElevatedButton.styleFrom(backgroundColor: AuraColors.primary),
              ),
            ]))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10,
                mainAxisSpacing: 10, childAspectRatio: 0.85),
              itemCount: _albums.length,
              itemBuilder: (_, i) => _AlbumCard(album: _albums[i])),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final AlbumModel album;
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final surface = AuraColors.surfaceOf(context);
    final surfaceHigh = AuraColors.surfaceHighOf(context);
    final txt = AuraColors.textOf(context);
    final txtMuted = AuraColors.textMutedOf(context);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(album: album))),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Expanded(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: QueryArtworkWidget(
              id: album.id, type: ArtworkType.ALBUM,
              nullArtworkWidget: Container(
                color: surfaceHigh,
                child: Icon(Icons.album, color: AuraColors.primary, size: 48))))),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(album.album, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: txt,
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text(album.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: txtMuted, fontSize: 11)),
            ])),
        ]),
      ),
    );
  }
}
