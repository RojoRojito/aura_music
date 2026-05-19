import '../../data/models/song.dart';
import '../../data/models/song_features.dart';
import '../../data/repositories/song_features_repository.dart';
import 'genre_catalog.dart';
import 'lastfm_enricher.dart';

class SongEnricher {
  static SongEnricher? _instance;
  static SongEnricher get instance => _instance ??= SongEnricher._();
  SongEnricher._();

  bool _isRunning = false;

  Future<SongFeatures> enrichSong(Song song) async {
    final artistName = song.artist;
    final rawId3Genre = song.genre;

    final lastfmData = await LastFmEnricher.instance.fetchArtistData(artistName);
    if (lastfmData != null) {
      return SongFeatures(
        songId: song.id,
        normalizedGenre: lastfmData['genre'] as String?,
        subGenre: lastfmData['subgenre'] as String?,
        moodTags: List<String>.from(lastfmData['moods'] ?? []),
        source: 'lastfm',
        enrichedAt: DateTime.now(),
      );
    }

    final catalogData = GenreCatalog.instance.lookupArtist(artistName);
    if (catalogData != null) {
      final genre = catalogData['genre'] as String?;
      return SongFeatures(
        songId: song.id,
        normalizedGenre: genre,
        subGenre: catalogData['subgenre'] as String?,
        moodTags: List<String>.from(catalogData['moods'] ?? []),
        source: 'catalog',
        enrichedAt: DateTime.now(),
      );
    }

    final normalizedGenre = GenreCatalog.instance.normalizeId3Genre(rawId3Genre);
    if (normalizedGenre != null) {
      return SongFeatures(
        songId: song.id,
        normalizedGenre: normalizedGenre,
        subGenre: null,
        moodTags: GenreCatalog.instance.defaultMoodsForGenre(normalizedGenre),
        source: 'id3',
        enrichedAt: DateTime.now(),
      );
    }

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

      for (var i = 0; i < unenriched.length; i++) {
        final features = await enrichSong(unenriched[i]);
        await featuresRepo.saveFeatures(features);
        onProgress?.call(i + 1, unenriched.length);

        if (features.source == 'lastfm') {
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }
    } finally {
      _isRunning = false;
    }
  }
}
