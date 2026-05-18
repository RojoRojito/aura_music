import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens/tokens.dart';
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
  bool _gridView = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final albums = await context.read<MediaScanner>().scanAlbums();
    if (mounted) setState(() { _albums = albums; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final txtMuted = AuraColors.textMutedOf(context);
    return _loading
        ? const AuraLoadingIndicator()
        : _albums.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.album_outlined, color: txtMuted, size: 64),
                const SizedBox(height: AuraSpacing.xl),
                Text('No hay albums', style: AuraTypography.headline.copyWith(color: txtMuted)),
                const SizedBox(height: AuraSpacing.sm),
                Text('Escanea tu biblioteca para encontrar albums',
                    style: AuraTypography.body.copyWith(color: txtMuted)),
                const SizedBox(height: AuraSpacing.xl),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Escaneear'),
                  style: ElevatedButton.styleFrom(backgroundColor: AuraColors.primary),
                ),
              ]))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpacing.lg,
                      vertical: AuraSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(_gridView ? Icons.grid_view : Icons.view_list),
                          color: AuraColors.textMuted,
                          onPressed: () => setState(() => _gridView = !_gridView),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _gridView ? _buildGrid() : _buildList(),
                  ),
                ],
              );
  }

  Widget _buildGrid() => GridView.builder(
        padding: const EdgeInsets.all(AuraSpacing.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AuraSpacing.md,
          mainAxisSpacing: AuraSpacing.md,
          childAspectRatio: 0.85,
        ),
        itemCount: _albums.length,
        itemBuilder: (_, i) => _AlbumCard(album: _albums[i]),
      );

  Widget _buildList() => ListView.builder(
        padding: const EdgeInsets.only(bottom: 160),
        itemCount: _albums.length,
        itemBuilder: (_, i) => _AlbumListTile(album: _albums[i]),
      );
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
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => AlbumDetailScreen(album: album),
          transitionDuration: AuraAnimation.normal,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AuraRadius.md),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AuraRadius.md),
                ),
                child: Hero(
                  tag: 'album_art_${album.id}',
                  child: QueryArtworkWidget(
                    id: album.id,
                    type: ArtworkType.ALBUM,
                    nullArtworkWidget: Container(
                      color: surfaceHigh,
                      child: Icon(Icons.album, color: AuraColors.primary, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AuraSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraTypography.label.copyWith(
                      color: txt,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    album.artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraTypography.caption.copyWith(color: txtMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumListTile extends StatelessWidget {
  final AlbumModel album;
  const _AlbumListTile({required this.album});

  @override
  Widget build(BuildContext context) {
    final surfaceHigh = AuraColors.surfaceHighOf(context);
    final txt = AuraColors.textOf(context);
    final txtMuted = AuraColors.textMutedOf(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.lg,
        vertical: AuraSpacing.xs,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AuraRadius.sm),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Hero(
            tag: 'album_art_${album.id}',
            child: QueryArtworkWidget(
              id: album.id,
              type: ArtworkType.ALBUM,
              nullArtworkWidget: Container(
                color: surfaceHigh,
                child: const Icon(Icons.album, color: AuraColors.primary),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        album.album,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AuraTypography.title.copyWith(color: txt),
      ),
      subtitle: Text(
        album.artist ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AuraTypography.caption.copyWith(color: txtMuted),
      ),
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => AlbumDetailScreen(album: album),
          transitionDuration: AuraAnimation.normal,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
        ),
      ),
    );
  }
}
