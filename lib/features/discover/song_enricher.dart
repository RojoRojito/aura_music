import 'package:flutter/foundation.dart';
import '../../data/models/song.dart';
import '../../data/models/song_features.dart';
import '../../data/repositories/song_features_repository.dart';
import 'genre_catalog.dart';
import 'lastfm_enricher.dart';

class ArtistExtractor {
  static const Map<String, String> _channelToArtist = {
    'nengoflowvevo': 'ñengo flow',
    'nengoflowtv': 'ñengo flow',
    'badgalriri': 'rihanna',
    'badbunyyvevo': 'bad bunny',
    'malumavevo': 'maluma',
    'jbalvinvevo': 'j balvin',
    'karolg': 'karol g',
    'ozunapr': 'ozuna',
    'anuelaaofficial': 'anuel aa',
    'rauwalejandromusic': 'rauw alejandro',
    'mykebtwrs': 'myke towers',
    'sebastianyatraofficial': 'sebastian yatra',
    'camilomusic': 'camilo',
  };

  static String? extractArtist(String rawArtist, String rawTitle) {
    if (rawArtist.trim().isEmpty || rawArtist == '<unknown>') {
      return _extractFromTitle(rawTitle);
    }

    final lower = rawArtist.toLowerCase().trim();

    if (lower.contains('www.') || lower.contains('.net') ||
        lower.contains('.com') || lower.contains('.org')) {
      return _extractFromTitle(rawTitle);
    }

    final noSpaces = lower.replaceAll(RegExp(r'\s+'), '');
    final mapped = _channelToArtist[noSpaces];
    if (mapped != null) return mapped;

    if (lower.endsWith('vevo')) {
      final withoutVevo = rawArtist.substring(0, rawArtist.length - 4).trim();
      if (withoutVevo.isNotEmpty) return withoutVevo;
      return _extractFromTitle(rawTitle);
    }

    if (!rawArtist.contains(' ') && rawArtist.length > 8 &&
        rawArtist != rawArtist.toLowerCase() &&
        rawArtist != rawArtist.toUpperCase()) {
      return _extractFromTitle(rawTitle);
    }

    return _extractPrimaryArtist(rawArtist);
  }

  static String _extractPrimaryArtist(String artist) {
    String result = artist;

    final patterns = [
      RegExp(r'\s+ft\.?\s+.*$', caseSensitive: false),
      RegExp(r'\s+feat\.?\s+.*$', caseSensitive: false),
      RegExp(r'\s+x\s+.*$', caseSensitive: false),
      RegExp(r'\s*&\s+.*$'),
      RegExp(r'\s*,\s+.*$'),
    ];

    for (final pattern in patterns) {
      result = result.replaceFirst(pattern, '').trim();
      if (result != artist) break;
    }

    return result.trim();
  }

  static String? _extractFromTitle(String title) {
    if (title.isEmpty || title == '<unknown>') return null;

    final cleaned = title
        .replaceAll(RegExp(r'^[\s]+'), '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FFFF}]', unicode: true), '')
        .trim();

    final dashIdx = cleaned.indexOf(' - ');
    if (dashIdx > 0 && dashIdx < 35) {
      final potentialArtist = cleaned.substring(0, dashIdx).trim();
      if (!potentialArtist.contains('/') &&
          !potentialArtist.contains('|') &&
          potentialArtist.length > 1) {
        return _extractPrimaryArtist(potentialArtist);
      }
    }

    return null;
  }

  static String? extractGenreFromTitle(String title) {
    final lower = title.toLowerCase();

    if (lower.contains('reggaeton') || lower.contains('regueton') ||
        lower.contains('dembow') || lower.contains('perreo')) {
      return 'urbano';
    }
    if (lower.contains('trap latino') || lower.contains('trap romántico') ||
        lower.contains('trap sensual') || lower.contains('latin trap')) {
      return 'urbano';
    }
    if (lower.contains('trap')) return 'urbano';

    if (lower.contains('salsa')) return 'tropical';
    if (lower.contains('bachata')) return 'tropical';
    if (lower.contains('cumbia')) return 'tropical';
    if (lower.contains('merengue')) return 'tropical';
    if (lower.contains('guaracha') || lower.contains('aleteo') ||
        lower.contains('zapateo')) return 'electronica';

    if (lower.contains('vallenato')) return 'vallenato';

    if (lower.contains('r&b') || lower.contains('rnb')) return 'r_and_b';
    if (lower.contains('hip hop') || lower.contains('hip-hop') ||
        lower.contains(' rap ') || lower.contains('freestyle')) return 'hip_hop';

    if (lower.contains(' rock ') || lower.contains('rock en')) return 'rock';

    if (lower.contains(' pop ')) return 'pop';

    if (lower.contains('llanera') || lower.contains('joropo') ||
        lower.contains('llanero')) return 'llanera';

    if (lower.contains('beat') || lower.contains('instrumental') ||
        lower.contains('pista')) {
      if (lower.contains('reggaeton') || lower.contains('urban')) return 'urbano';
      if (lower.contains('trap')) return 'urbano';
      if (lower.contains('r&b') || lower.contains('emotional')) return 'r_and_b';
    }

    return null;
  }
}

class SongEnricher {
  static SongEnricher? _instance;
  static SongEnricher get instance => _instance ??= SongEnricher._();
  SongEnricher._();

  bool _isRunning = false;

  Future<SongFeatures> enrichSong(Song song) async {
    final rawArtist = song.artist;
    final rawTitle = song.title;
    final rawId3Genre = song.genre;

    debugPrint('[Enricher] Procesando: $rawArtist - $rawTitle');

    final cleanArtist = ArtistExtractor.extractArtist(rawArtist, rawTitle);

    if (cleanArtist != null && cleanArtist != rawArtist) {
      debugPrint('[Enricher] 🔧 Artista limpiado: "$rawArtist" → "$cleanArtist"');
    }

    if (cleanArtist != null && cleanArtist.isNotEmpty) {
      final lastfmData = await LastFmEnricher.instance.fetchArtistData(cleanArtist);
      if (lastfmData != null) {
        debugPrint('[Enricher] ✅ LastFM: $cleanArtist → ${lastfmData["genre"]}');
        return SongFeatures(
          songId: song.id,
          normalizedGenre: lastfmData['genre'] as String?,
          subGenre: lastfmData['subgenre'] as String?,
          moodTags: List<String>.from(lastfmData['moods'] ?? []),
          source: 'lastfm',
          enrichedAt: DateTime.now(),
        );
      }
    }

    if (cleanArtist != null) {
      final catalogData = GenreCatalog.instance.lookupArtist(cleanArtist);
      if (catalogData != null) {
        final genre = catalogData['genre'] as String?;
        debugPrint('[Enricher] 📖 Catálogo: $cleanArtist → $genre');
        return SongFeatures(
          songId: song.id,
          normalizedGenre: genre,
          subGenre: catalogData['subgenre'] as String?,
          moodTags: List<String>.from(catalogData['moods'] ?? []),
          source: 'catalog',
          enrichedAt: DateTime.now(),
        );
      }
    }

    final genreFromId3 = GenreCatalog.instance.normalizeId3Genre(rawId3Genre);
    if (genreFromId3 != null) {
      debugPrint('[Enricher] 🏷️ ID3: $rawArtist → $genreFromId3');
      return SongFeatures(
        songId: song.id,
        normalizedGenre: genreFromId3,
        subGenre: null,
        moodTags: GenreCatalog.instance.defaultMoodsForGenre(genreFromId3),
        source: 'id3',
        enrichedAt: DateTime.now(),
      );
    }

    final genreFromTitle = ArtistExtractor.extractGenreFromTitle(rawTitle);
    if (genreFromTitle != null) {
      debugPrint('[Enricher] 📝 Título: "$rawTitle" → $genreFromTitle');
      return SongFeatures(
        songId: song.id,
        normalizedGenre: genreFromTitle,
        subGenre: null,
        moodTags: GenreCatalog.instance.defaultMoodsForGenre(genreFromTitle),
        source: 'id3',
        enrichedAt: DateTime.now(),
      );
    }

    debugPrint('[Enricher] ❓ Sin datos: $rawArtist - $rawTitle');
    return SongFeatures.unknown(song.id);
  }

  Future<void> enrichLibrary({
    required List<Song> songs,
    required SongFeaturesRepository featuresRepo,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      final unenriched = <Song>[];
      for (final song in songs) {
        final existing = await featuresRepo.getFeatures(song.id);
        if (existing == null || !existing.isEnriched) {
          unenriched.add(song);
        }
      }

      debugPrint('[Enricher] Iniciando: ${unenriched.length} canciones sin enriquecer');

      for (var i = 0; i < unenriched.length; i++) {
        final features = await enrichSong(unenriched[i]);
        await featuresRepo.saveFeatures(features);
        onProgress?.call(i + 1, unenriched.length);

        if (features.source == 'lastfm') {
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }

      debugPrint('[Enricher] 🎉 Enriquecimiento completado');
    } finally {
      _isRunning = false;
    }
  }
}
