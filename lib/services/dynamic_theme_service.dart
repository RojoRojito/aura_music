import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';

class DynamicThemeService {
  static DynamicThemeService? _instance;
  DynamicThemeService._();

  static DynamicThemeService get instance {
    _instance ??= DynamicThemeService._();
    return _instance!;
  }

  Color _dominantColor = const Color(0xFF7C4DFF);
  Color _accentColor = const Color(0xFF00E5FF);

  Color get dominantColor => _dominantColor;
  Color get accentColor => _accentColor;

  Future<void> updateFromAlbumArt(int albumId) async {
    try {
      final art = await QueryArtworkPlugin().queryArtwork(
        albumId,
        ArtworkType.ALBUM,
        format: ArtworkFormat.JPEG,
        size: 200,
      );
      if (art != null && art.isNotEmpty) {
        await _extractPalette(art);
      }
    } catch (e) {
      debugPrint('Error extracting palette: $e');
    }
  }

  Future<void> _extractPalette(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final paletteGenerator = await PaletteGenerator.fromImage(image);
      if (paletteGenerator.dominantColor != null) {
        _dominantColor = paletteGenerator.dominantColor!.color;
      }
      if (paletteGenerator.vibrantColor != null) {
        _accentColor = paletteGenerator.vibrantColor!.color;
      } else if (paletteGenerator.mutedColor != null) {
        _accentColor = paletteGenerator.mutedColor!.color;
      }
    } catch (e) {
      debugPrint('Error creating palette: $e');
    }
  }

  void reset() {
    _dominantColor = const Color(0xFF7C4DFF);
    _accentColor = const Color(0xFF00E5FF);
  }
}