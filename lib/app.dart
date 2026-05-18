import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens/tokens.dart';
import 'features/home/for_you_screen.dart';
import 'features/library/library_screen.dart';
import 'features/library/library_controller.dart';
import 'features/albums/albums_screen.dart';
import 'features/artists/artists_screen.dart';
import 'features/playlists/playlists_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/player/player_controller.dart';
import 'features/settings/settings_controller.dart';
import 'services/dynamic_theme_service.dart';
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

class _ShellState extends State<_Shell> with TickerProviderStateMixin {
  int _idx = 0;
  late AnimationController _indicatorAnim;

  final List<Widget> _screens = [
    const ForYouScreen(key: ValueKey(0)),
    const _LibraryShell(key: ValueKey(1)),
    const PlaylistsScreen(key: ValueKey(2)),
    const SettingsScreen(key: ValueKey(3)),
  ];

  static const _tabIcons = [
    (outlined: Icons.home_outlined, filled: Icons.home),
    (outlined: Icons.library_music_outlined, filled: Icons.library_music),
    (outlined: Icons.queue_music_outlined, filled: Icons.queue_music),
    (outlined: Icons.settings_outlined, filled: Icons.settings),
  ];

  static const _tabLabels = ['Home', 'Library', 'Playlists', 'Settings'];

  @override
  void initState() {
    super.initState();
    _indicatorAnim = AnimationController(
      vsync: this,
      duration: AuraAnimation.fast,
    );
    _setupErrorListener();
  }

  @override
  void dispose() {
    _indicatorAnim.dispose();
    super.dispose();
  }

  void _setupErrorListener() {
    final ctrl = context.read<PlayerController>();
    ctrl.errorStream.listen((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AuraColors.surfaceHigh,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _onTabSelected(int i) {
    HapticFeedback.selectionClick();
    _indicatorAnim.forward(from: 0);
    setState(() => _idx = i);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PlayerController>();
    final settings = context.watch<SettingsController>();
    final themeService = context.watch<DynamicThemeService>();
    final isDark = settings.themeMode == ThemeMode.dark ||
        (settings.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final bgColor = isDark ? AuraColors.background : AuraColors.lightBackground;
    final navColor = isDark ? AuraColors.surface : AuraColors.lightSurface;
    final navIndicator = themeService.dominantColor.withOpacity(isDark ? 0.2 : 0.15);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(children: [
        AnimatedSwitcher(
          duration: AuraAnimation.normal,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _screens[_idx],
        ),
        if (ctrl.currentSong != null)
          Positioned(
            left: 0, right: 0,
            bottom: 56,
            child: const MiniPlayer()),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: navColor,
        indicatorColor: navIndicator,
        selectedIndex: _idx,
        onDestinationSelected: _onTabSelected,
        destinations: List.generate(_tabIcons.length, (i) {
          final icons = _tabIcons[i];
          return NavigationDestination(
            icon: Icon(icons.outlined),
            selectedIcon: Icon(icons.filled),
            label: _tabLabels[i],
          );
        }),
      ),
    );
  }
}

class _LibraryShell extends StatefulWidget {
  const _LibraryShell();
  @override State<_LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends State<_LibraryShell> {
  int _tab = 0;

  static const _subTabs = [
    (icon: Icons.music_note, label: 'Songs'),
    (icon: Icons.album, label: 'Albums'),
    (icon: Icons.person, label: 'Artists'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AuraColors.background : AuraColors.lightBackground;
    final txt = isDark ? AuraColors.text : AuraColors.lightText;
    final txtMuted = isDark ? AuraColors.textMuted : AuraColors.lightTextMuted;

    final screens = const [
      LibraryScreen(key: ValueKey(0)),
      AlbumsScreen(key: ValueKey(1)),
      ArtistsScreen(key: ValueKey(2)),
    ];

    return Consumer<LibraryController>(
      builder: (_, ctrl, __) => Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: const Text('Library', style: AuraTypography.headline),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Material(
              color: Colors.transparent,
              child: Row(
                children: List.generate(_subTabs.length, (i) {
                  final isActive = _tab == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: AuraSpacing.md),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _subTabs[i].icon,
                              size: 18,
                              color: isActive ? txt : txtMuted,
                            ),
                            const SizedBox(width: AuraSpacing.xs),
                            Text(
                              _subTabs[i].label,
                              style: AuraTypography.label.copyWith(
                                color: isActive ? txt : txtMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: AuraAnimation.fast,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: screens[_tab],
        ),
        floatingActionButton: _tab == 0 && ctrl.songs.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: ctrl.shuffleAll,
                backgroundColor: AuraColors.primary,
                icon: const Icon(Icons.shuffle),
                label: const Text('Aleatorio'),
              )
            : null,
      ),
    );
  }
}
