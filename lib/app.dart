import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/library/library_screen.dart';
import 'features/albums/albums_screen.dart';
import 'features/artists/artists_screen.dart';
import 'features/playlists/playlists_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/player/player_controller.dart';
import 'features/settings/settings_controller.dart';
import 'widgets/mini_player.dart';

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return MaterialApp(
      title: 'AURA Music',
      debugShowCheckedModeBanner: false,
      theme: AuraTheme.light(),
      darkTheme: AuraTheme.dark(),
      themeMode: settings.themeMode,
      home: const _Shell(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();
  @override State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _idx = 0;
  final _screens = const [
    LibraryScreen(), AlbumsScreen(), ArtistsScreen(), PlaylistsScreen(), SettingsScreen()
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final settings = context.watch<SettingsController>();
    final bgColor = settings.themeMode == ThemeMode.light
        ? AuraColors.lightBackground
        : AuraColors.background;
    final navColor = settings.themeMode == ThemeMode.light
        ? AuraColors.lightSurface
        : AuraColors.surface;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(children: [
        IndexedStack(index: _idx, children: _screens),
        if (ctrl.currentSong != null)
          Positioned(
            bottom: 70, left: 8, right: 8,
            child: const MiniPlayer()),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: navColor,
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.music_note_outlined),
              selectedIcon: Icon(Icons.music_note), label: 'Canciones'),
          NavigationDestination(icon: Icon(Icons.album_outlined),
              selectedIcon: Icon(Icons.album), label: 'Álbumes'),
          NavigationDestination(icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person), label: 'Artistas'),
          NavigationDestination(icon: Icon(Icons.queue_music_outlined),
              selectedIcon: Icon(Icons.queue_music), label: 'Listas'),
          NavigationDestination(icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}