import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/audio_handler.dart';
import 'services/media_scanner.dart';
import 'services/stats_tracker.dart';
import 'data/repositories/playlist_repository.dart';
import 'data/repositories/favorites_repository.dart';
import 'data/database/app_database.dart';
import 'data/repositories/stats_repository.dart';
import 'data/repositories/song_features_repository.dart';
import 'features/player/player_controller.dart';
import 'features/library/library_controller.dart';
import 'features/settings/settings_controller.dart';
import 'data/repositories/eq_repository.dart';
import 'services/dynamic_theme_service.dart';
import 'services/equalizer_service.dart';
import 'services/native_equalizer_service.dart';
import 'services/equalizer_state.dart';
import 'features/equalizer/equalizer_controller.dart';
import 'features/discover/recommendation_engine.dart';
import 'features/discover/genre_catalog.dart';
import 'features/discover/song_enricher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A0F),
  ));

  final settingsController = SettingsController();
  await settingsController.init();

  await AppDatabase.instance.database;

  final eqRepository = EqRepository();
  final favoritesRepository = FavoritesRepository();
  await favoritesRepository.loadFavorites();

  late AuraAudioHandler audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => AuraAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.daviddev.aura_music.channel',
        androidNotificationChannelName: 'AURA Music',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    debugPrint('AudioService error: $e');
    audioHandler = AuraAudioHandler();
  }

  final nativeEqualizerService = NativeEqualizerService();
  final equalizerService = EqualizerService(eqRepository);
  final equalizerState = equalizerService.state;
  final equalizerController = equalizerService.controller;

  await equalizerService.loadGlobal();

  final playerController = PlayerController(audioHandler);
  await playerController.init(settingsController);

  final themeService = DynamicThemeService.instance;

  final statsRepository = StatsRepository.instance;
  await statsRepository.clearOldEvents(keepDays: 30);

  final featuresRepo = SongFeaturesRepository();
  final recommendationEngine =
      RecommendationEngine(statsRepository, featuresRepo);
  await recommendationEngine.compute();

  final statsTracker = StatsTracker(
    statsRepository: statsRepository,
    audioHandler: audioHandler,
  );
  await statsTracker.init(favoritesRepository);

  RecommendationEngine? recEngineRef;
  audioHandler.onSongChanged = (songId) {
    statsTracker.handleSongChanged(songId);
    if (settingsController.dynamicThemeEnabled) {
      final song = audioHandler.currentSong;
      themeService.updateFromAlbumArt(
        songId,
        songTitle: song?.title,
        songArtist: song?.artist,
      );
    }
    Future.delayed(const Duration(seconds: 5), () {
      recEngineRef?.refresh();
    });
  };

  audioHandler.onAudioSessionId = (sessionId) {
    debugPrint('[main] onAudioSessionId callback FIRED: sessionId=$sessionId');
    equalizerController.initSession(sessionId);
  };
  debugPrint('[main] onAudioSessionId callback SET on handler');

  runApp(MultiProvider(
    providers: [
      Provider<AuraAudioHandler>(create: (_) => audioHandler),
      Provider<MediaScanner>(create: (_) => MediaScanner()),
      Provider<StatsRepository>.value(value: statsRepository),
      Provider<SongFeaturesRepository>.value(value: featuresRepo),
      ChangeNotifierProvider.value(value: playerController),
      ChangeNotifierProvider(
          create: (c) => LibraryController(
              c.read<MediaScanner>(),
              c.read<PlayerController>(),
              c.read<StatsRepository>())),
      ChangeNotifierProvider(create: (c) {
        final repo = PlaylistRepository();
        repo.loadPlaylists();
        return repo;
      }),
      ChangeNotifierProvider.value(value: favoritesRepository),
      ChangeNotifierProvider<EqRepository>(create: (_) => eqRepository),
      ChangeNotifierProvider<EqualizerService>.value(value: equalizerService),
      Provider<NativeEqualizerService>.value(value: nativeEqualizerService),
      ChangeNotifierProvider<EqualizerState>.value(value: equalizerState),
      ChangeNotifierProvider<EqualizerController>.value(
          value: equalizerController),
      ChangeNotifierProvider.value(value: settingsController),
      ChangeNotifierProvider.value(value: themeService),
      ChangeNotifierProvider<RecommendationEngine>.value(
          value: recommendationEngine),
      Provider<StatsTracker>.value(value: statsTracker),
    ],
    child: Builder(builder: (context) {
      GenreCatalog.instance.load(context);

      MediaScanner().scanSongs().then((result) {
        if (result.status == ScanStatus.success) {
          SongEnricher.instance
              .enrichLibrary(
                songs: result.songs,
                featuresRepo: featuresRepo,
              )
              .catchError((_) {});
        }
      }).catchError((_) {});

      recEngineRef = context.read<RecommendationEngine>();
      recEngineRef?.compute();
      return const AuraApp();
    }),
  ));
}
