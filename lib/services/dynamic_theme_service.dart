import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';

Future<Map<String, int>> _extractPaletteIsolate(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final paletteGenerator = await PaletteGenerator.fromImage(image);
  final dominant = paletteGenerator.dominantColor?.color.value ?? 0xFF7C4DFF;
  final vibrant = paletteGenerator.vibrantColor?.color.value
      ?? paletteGenerator.mutedColor?.color.value
      ?? 0xFF00E5FF;
  return {'dominant': dominant, 'accent': vibrant};
}

class DynamicThemeService extends ChangeNotifier {
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
      final art = await OnAudioQuery().queryArtwork(
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
      final result = await compute(_extractPaletteIsolate, bytes);
      _dominantColor = Color(result['dominant']!);
      _accentColor = Color(result['accent']!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating palette: $e');
    }
  }

  void reset() {
    _dominantColor = const Color(0xFF7C4DFF);
    _accentColor = const Color(0xFF00E5FF);
  }
}