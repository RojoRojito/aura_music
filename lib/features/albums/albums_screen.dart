import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/media_scanner.dart';
import 'album_detail_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});
  @override State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<AlbumModel> _albums = [];
  List<AlbumModel> _filtered = [];
  bool _loading = true;
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final albums = await context.read<MediaScanner>().scanAlbums();
    setState(() { _albums = albums; _filtered = albums; _loading = false; });
  }

  void _search(String q) {
    setState(() {
      _searching = q.isNotEmpty;
      _filtered = q.isEmpty
          ? _albums
          : _albums.where((a) =>
              a.album.toLowerCase().contains(q.toLowerCase()) ||
              (a.artist?.toLowerCase().contains(q.toLowerCase()) ?? false)
          ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = settings.themeMode == ThemeMode.dark;
    final bgColor = isDark ? AuraColors.background : AuraColors.lightBackground;
    final textColor = isDark ? AuraColors.text : AuraColors.lightText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: _searching
          ? TextField(
              controller: _searchCtrl, autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Buscar albums...',
                hintStyle: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted),
                border: InputBorder.none),
              onChanged: _search)
          : Text('Albums', style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search,
                color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) { _searchCtrl.clear(); _filtered = _albums; }
              });
            }),
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted),
            onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AuraColors.primary))
        : _filtered.isEmpty
          ? Center(child: Text('No hay albums',
              style: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted)))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10,
                mainAxisSpacing: 10, childAspectRatio: 0.85),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _AlbumCard(album: _filtered[i])),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final AlbumModel album;
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = settings.themeMode == ThemeMode.dark;
    final surfaceColor = isDark ? AuraColors.surface : AuraColors.lightSurface;
    final surfaceHighColor = isDark ? AuraColors.surfaceHigh : AuraColors.lightSurfaceHigh;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(album: album))),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Expanded(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: QueryArtworkWidget(
              id: album.id, type: ArtworkType.ALBUM,
              nullArtworkWidget: Container(
                color: surfaceHighColor,
                child: const Icon(Icons.album, color: AuraColors.primary, size: 48))))),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(album.album, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: isDark ? AuraColors.text : AuraColors.lightText,
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text(album.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: isDark ? AuraColors.textMuted : AuraColors.lightTextMuted, fontSize: 11)),
            ])),
        ]),
      ),
    );
  }
}