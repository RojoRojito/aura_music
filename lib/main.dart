import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/audio_handler.dart';
import 'services/media_scanner.dart';
import 'data/repositories/playlist_repository.dart';
import 'data/repositories/favorites_repository.dart';
import 'data/database/app_database.dart';
import 'features/player/player_controller.dart';
import 'features/library/library_controller.dart';
import 'features/settings/settings_controller.dart';
import 'data/repositories/eq_repository.dart';
import 'services/dynamic_theme_service.dart';
import 'services/equalizer_service.dart';

late AuraAudioHandler audioHandler;
late EqualizerService equalizerService;

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

  equalizerService = EqualizerService(eqRepository);

  audioHandler.onSongChanged = (songId) {
    equalizerService.loadForSong(songId);
    if (settingsController.dynamicThemeEnabled) {
      DynamicThemeService.instance.updateFromAlbumArt(songId);
    }
  };

  final playerController = PlayerController(audioHandler);
  await playerController.init(settingsController);

  runApp(MultiProvider(
    providers: [
      Provider<AuraAudioHandler>(create: (_) => audioHandler),
      Provider<MediaScanner>(create: (_) => MediaScanner()),
      ChangeNotifierProvider.value(value: playerController),
      ChangeNotifierProvider(
          create: (c) => LibraryController(
              c.read<MediaScanner>(), c.read<PlayerController>())),
      ChangeNotifierProvider(create: (_) => PlaylistRepository()),
      ChangeNotifierProvider.value(value: favoritesRepository),
      ChangeNotifierProvider<EqRepository>(create: (_) => eqRepository),
      ChangeNotifierProvider<EqualizerService>.value(value: equalizerService),
      ChangeNotifierProvider.value(value: settingsController),
    ],
    child: const AuraApp(),
  ));
}