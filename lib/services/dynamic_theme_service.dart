import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';

Future<Map<String, int>> _extractPaletteIsolate(Map<String, dynamic> params) async {
  final bytes = params['bytes'] as Uint8List;
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

int _hashString(String input) {
  var hash = 0;
  for (var i = 0; i < input.length; i++) {
    hash = input.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return hash;
}

Color _colorFromHash(String seed) {
  final hash = _hashString(seed);
  final r = (hash & 0xFF0000) >> 16;
  final g = (hash & 0x00FF00) >> 8;
  final b = hash & 0x0000FF;
  return Color.fromARGB(0xFF, r, g, b);
}

Color _desaturate(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withSaturation((hsl.saturation * (1 - amount)).clamp(0.0, 1.0)).toColor();
}

Color _darkenIfBright(Color color, double threshold) {
  final hsl = HSLColor.fromColor(color);
  if (hsl.lightness > threshold) {
    return hsl.withLightness(threshold).toColor();
  }
  return color;
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
  String _lastSeed = '';

  Color get dominantColor => _dominantColor;
  Color get accentColor => _accentColor;
  Color get surfaceTint => _dominantColor.withOpacity(0.08);

  Future<void> updateFromAlbumArt(int albumId, {String? songTitle, String? songArtist}) async {
    try {
      final art = await OnAudioQuery().queryArtwork(
        albumId,
        ArtworkType.ALBUM,
        format: ArtworkFormat.JPEG,
        size: 200,
      );
      if (art != null && art.isNotEmpty) {
        await _extractPalette(art);
      } else {
        _applyFallback(songTitle, songArtist);
      }
    } catch (e) {
      debugPrint('Error extracting palette: $e');
      _applyFallback(songTitle, songArtist);
    }
  }

  void _applyFallback(String? title, String? artist) {
    final seed = '${title ?? ''}${artist ?? ''}';
    if (seed.isEmpty || seed == _lastSeed) return;
    _lastSeed = seed;

    final base = _colorFromHash(seed);
    _dominantColor = _desaturate(base, 0.2);
    _accentColor = HSLColor.fromColor(base)
        .withHue((HSLColor.fromColor(base).hue + 30) % 360)
        .toColor();
    notifyListeners();
  }

  Future<void> _extractPalette(Uint8List bytes) async {
    try {
      final result = await compute(_extractPaletteIsolate, {'bytes': bytes});
      var dominant = Color(result['dominant']!);
      var accent = Color(result['accent']!);

      dominant = _desaturate(dominant, 0.2);
      dominant = _darkenIfBright(dominant, 0.65);
      accent = _darkenIfBright(accent, 0.7);

      _dominantColor = dominant;
      _accentColor = accent;
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating palette: $e');
    }
  }

  void reset() {
    _dominantColor = const Color(0xFF7C4DFF);
    _accentColor = const Color(0xFF00E5FF);
    _lastSeed = '';
    notifyListeners();
  }
}
