import 'dart:convert';
import 'package:http/http.dart' as http;
import 'genre_catalog.dart';

const String kLastFmApiKey = 'TU_API_KEY_AQUI';
const String kLastFmBaseUrl = 'https://ws.audioscrobbler.com/2.0/';

class LastFmEnricher {
  static LastFmEnricher? _instance;
  static LastFmEnricher get instance => _instance ??= LastFmEnricher._();
  LastFmEnricher._();

  final _client = http.Client();

  Future<Map<String, dynamic>?> fetchArtistData(String artistName) async {
    try {
      final uri = Uri.parse(kLastFmBaseUrl).replace(queryParameters: {
        'method': 'artist.gettoptags',
        'artist': artistName,
        'api_key': kLastFmApiKey,
        'format': 'json',
        'limit': '10',
      });

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data.containsKey('error')) return null;

      final tagsData = data['toptags']?['tag'];
      if (tagsData == null) return null;

      final tags = (tagsData as List<dynamic>)
          .map((t) => (t['name'] as String).toLowerCase().trim())
          .toList();

      final genre = _resolveGenreFromTags(tags);
      final moods = _resolveMoodsFromTags(tags, genre);

      if (genre == null) return null;

      return {
        'genre': genre,
        'subgenre': null,
        'moods': moods,
        'source': 'lastfm',
      };
    } catch (_) {
      return null;
    }
  }

  String? _resolveGenreFromTags(List<String> tags) {
    for (final tag in tags.take(5)) {
      final normalized = GenreCatalog.instance.normalizeId3Genre(tag);
      if (normalized != null) return normalized;
    }

    final specialMap = {
      'latin': 'pop_latino',
      'latin music': 'pop_latino',
      'latinoamerica': 'pop_latino',
      'electronic': 'electronica',
      'electronica': 'electronica',
      'soul': 'r_and_b',
      'funk': 'r_and_b',
      'country': 'pop',
      'jazz': 'r_and_b',
    };

    for (final tag in tags.take(5)) {
      final mapped = specialMap[tag];
      if (mapped != null) return mapped;
    }

    return null;
  }

  List<String> _resolveMoodsFromTags(List<String> tags, String? genre) {
    final moodMap = {
      'sad': 'melancólico',
      'melancholic': 'melancólico',
      'melancholy': 'melancólico',
      'romantic': 'romántico',
      'love': 'romántico',
      'happy': 'alegre',
      'party': 'fiesta',
      'dance': 'energético',
      'energetic': 'energético',
      'aggressive': 'agresivo',
      'chill': 'tranquilo',
      'relax': 'tranquilo',
      'sexy': 'sensual',
      'sensual': 'sensual',
      'nostalgic': 'nostálgico',
    };

    final moods = <String>{};
    for (final tag in tags) {
      final mood = moodMap[tag];
      if (mood != null) moods.add(mood);
    }

    if (moods.isEmpty && genre != null) {
      return GenreCatalog.instance.defaultMoodsForGenre(genre);
    }

    return moods.toList();
  }
}
