import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class GenreCatalog {
  static GenreCatalog? _instance;
  static GenreCatalog get instance => _instance ??= GenreCatalog._();
  GenreCatalog._();

  Map<String, dynamic> _catalog = {};
  bool _loaded = false;

  static const Map<String, String> _genreNormalizer = {
    'reggaeton': 'urbano',
    'reggeaton': 'urbano',
    'regueton': 'urbano',
    'latin urban': 'urbano',
    'urban latin': 'urbano',
    'trap latino': 'urbano',
    'latin trap': 'urbano',
    'urbano': 'urbano',
    'dembow': 'urbano',
    'vallenato': 'vallenato',
    'salsa': 'tropical',
    'cumbia': 'tropical',
    'bachata': 'tropical',
    'merengue': 'tropical',
    'tropical': 'tropical',
    'pop': 'pop',
    'pop latino': 'pop_latino',
    'latin pop': 'pop_latino',
    'pop latinoamericano': 'pop_latino',
    'rock': 'rock',
    'rock en espanol': 'rock_espanol',
    'rock en español': 'rock_espanol',
    'rock alternativo': 'rock_espanol',
    'alternative rock': 'rock',
    'hip-hop': 'hip_hop',
    'hip hop': 'hip_hop',
    'rap': 'hip_hop',
    'r&b': 'r_and_b',
    'rnb': 'r_and_b',
    'soul': 'r_and_b',
    'regional mexicano': 'regional_mexicano',
    'banda': 'regional_mexicano',
    'norteño': 'regional_mexicano',
    'grupero': 'regional_mexicano',
    'balada': 'balada',
    'ballad': 'balada',
    'electronic': 'electronica',
    'electronica': 'electronica',
    'edm': 'electronica',
    'dance': 'electronica',
    'llanera': 'llanera',
    'joropo': 'llanera',
  };

  static const Map<String, List<String>> _genreDefaultMoods = {
    'urbano': ['energético', 'fiesta', 'agresivo'],
    'vallenato': ['nostálgico', 'festivo', 'romántico'],
    'tropical': ['alegre', 'festivo', 'romántico'],
    'pop_latino': ['alegre', 'romántico', 'energético'],
    'pop': ['alegre', 'energético', 'tranquilo'],
    'rock': ['agresivo', 'energético', 'melancólico'],
    'rock_espanol': ['energético', 'melancólico', 'nostálgico'],
    'hip_hop': ['agresivo', 'energético', 'melancólico'],
    'r_and_b': ['romántico', 'sensual', 'tranquilo'],
    'electronica': ['energético', 'festivo', 'alegre'],
    'llanera': ['nostálgico', 'festivo', 'romántico'],
    'regional_mexicano': ['festivo', 'romántico', 'melancólico'],
    'balada': ['romántico', 'melancólico', 'tranquilo'],
  };

  Future<void> load(BuildContext context) async {
    if (_loaded) return;
    try {
      final json =
          await rootBundle.loadString('assets/data/artist_catalog.json');
      final data = jsonDecode(json) as Map<String, dynamic>;
      _catalog = data['artists'] as Map<String, dynamic>;
      _loaded = true;
    } catch (e) {
      debugPrint('[GenreCatalog] Failed to load catalog: $e');
    }
  }

  Map<String, dynamic>? lookupArtist(String artistName) {
    final key = artistName.toLowerCase().trim();
    return _catalog[key] as Map<String, dynamic>?;
  }

  String? normalizeId3Genre(String? rawGenre) {
    if (rawGenre == null || rawGenre.isEmpty) return null;
    final key = rawGenre.toLowerCase().trim();
    return _genreNormalizer[key];
  }

  List<String> defaultMoodsForGenre(String? genre) {
    if (genre == null) return [];
    return List<String>.from(_genreDefaultMoods[genre] ?? []);
  }

  bool get isLoaded => _loaded;
}
