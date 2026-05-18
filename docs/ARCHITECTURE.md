# AURA Music — Architecture Documentation

> **Date:** 2026-05-17
> **Version:** 1.1.0
> **Status:** Current architecture — pre-reconstruction
> **Source:** Analysis of actual codebase in `lib/`

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Navigation Flow](#2-navigation-flow)
3. [Audio Architecture](#3-audio-architecture)
4. [State Management](#4-state-management)
5. [Database Layer](#5-database-layer)
6. [Theme System](#6-theme-system)
7. [Native Android Layer](#7-native-android-layer)
8. [Technical Debt](#8-technical-debt)

---

## 1. Project Structure

### Directory Map

```
lib/
├── main.dart                          # Entry point. DI root. 13 providers. Init sequencing.
├── app.dart                           # MaterialApp + _Shell (IndexedStack + MiniPlayer overlay)
│
├── core/
│   └── theme/
│       └── app_theme.dart             # AuraColors (dark + light), AuraTheme (M3 ThemeData)
│
├── data/
│   ├── models/
│   │   ├── song.dart                  # Immutable entity. toJson/fromJson. Equality by id.
│   │   ├── playlist.dart              # id/name/songs/createdAt. toMap/fromMap/copyWith.
│   │   ├── artist.dart                # Wrapper for on_audio_query ArtistModel.
│   │   ├── eq_config.dart             # 12-band EQ config. 8 presets. toMap/fromMap.
│   │   └── song_stats.dart            # Play/skip counts, scoring algorithm.
│   ├── database/
│   │   └── app_database.dart          # Singleton. 6 tables. Version=1. No migrations.
│   └── repositories/
│       ├── playlist_repository.dart   # Playlist CRUD. ChangeNotifier. NOT auto-loaded.
│       ├── favorites_repository.dart  # Set<int> favorites. toggle/add/remove.
│       ├── eq_repository.dart         # Per-song EQ persistence. ChangeNotifier.
│       └── stats_repository.dart      # Play events + song_stats aggregation. Singleton.
│
├── services/
│   ├── audio_handler.dart             # AuraAudioHandler. Owns AudioPlayer. Queue + playback.
│   ├── media_scanner.dart             # on_audio_query wrapper. Permission handling.
│   ├── state_persistence_service.dart # QueueState → SharedPreferences JSON.
│   ├── dynamic_theme_service.dart     # Singleton. Palette extraction from album art.
│   ├── equalizer_service.dart         # MethodChannel → native EQ. 12 bands + bass + virtualizer.
│   └── stats_tracker.dart             # Tracks play events. Flushes on song change.
│
├── features/
│   ├── library/
│   │   ├── library_controller.dart    # Scan, search, filter, shuffle.
│   │   └── library_screen.dart        # Song list + search + RecommendationSection + Slidable.
│   ├── albums/
│   │   ├── albums_screen.dart         # 2-column album grid.
│   │   └── album_detail_screen.dart   # SliverAppBar + song list + play/shuffle.
│   ├── artists/
│   │   └── artists_screen.dart        # Artist list + detail with songs + albums.
│   ├── playlists/
│   │   ├── playlists_screen.dart      # CRUD: create/delete. No detail integration.
│   │   └── playlist_detail_screen.dart# Shows playlist songs. Play/shuffle.
│   ├── player/
│   │   ├── player_controller.dart     # Wraps AuraAudioHandler. Adds persistence + sleep timer.
│   │   └── player_screen.dart         # Full-screen player. Artwork + controls + queue sheet.
│   ├── settings/
│   │   ├── settings_controller.dart   # Sleep timer, speed, theme mode, dynamic theme.
│   │   └── settings_screen.dart       # Speed picker, sleep timer picker, theme toggles.
│   ├── equalizer/
│   │   └── equalizer_screen.dart      # 12-band EQ UI. Presets. Bass/virtualizer sliders.
│   ├── discover/
│   │   └── recommendation_engine.dart # Score-based recommendations from song_stats.
│   ├── smart_recommendations/         # api/ + models/ — external AI. NOT integrated.
│   └── home/
│       ├── for_you_screen.dart        # Recommendation display. NOT in navigation.
│       └── widgets/
│           └── recommendation_section.dart  # Embedded recommendations in library.
│
└── widgets/
    ├── mini_player.dart               # Glassmorphism bar. Dismissible skip. Circular progress.
    ├── song_tile.dart                 # Reusable tile with Slidable → AddToPlaylist.
    └── add_to_playlist_sheet.dart     # Bottom sheet: pick playlist or create new.
```

### Module Responsibilities

| Module | Responsibility | Files |
|---|---|---|
| **core/theme** | Color constants, ThemeData construction | `app_theme.dart` |
| **data/models** | Pure data entities, serialization | 5 model files |
| **data/database** | SQLite initialization, schema | `app_database.dart` |
| **data/repositories** | DB CRUD operations, ChangeNotifier state | 4 repository files |
| **services/audio_handler** | Audio playback, queue, system notification | `audio_handler.dart` |
| **services/media_scanner** | Device media scanning, permission requests | `media_scanner.dart` |
| **services/state_persistence** | Queue save/restore via SharedPreferences | `state_persistence_service.dart` |
| **services/dynamic_theme** | Album art color extraction | `dynamic_theme_service.dart` |
| **services/equalizer** | Native EQ control via MethodChannel | `equalizer_service.dart` |
| **services/stats_tracker** | Play event tracking, flush on song change | `stats_tracker.dart` |
| **features/library** | Song list UI, search, scan | controller + screen |
| **features/albums** | Album grid + detail | 2 screens |
| **features/artists** | Artist list + detail | 1 screen (inline detail) |
| **features/playlists** | Playlist CRUD + detail | 2 screens |
| **features/player** | Playback control UI + controller | controller + screen |
| **features/settings** | App configuration UI + controller | controller + screen |
| **features/equalizer** | EQ adjustment UI | 1 screen |
| **features/discover** | Recommendation scoring algorithm | 1 engine |
| **features/home** | "For You" recommendations | 1 screen + widget |
| **widgets** | Reusable UI components | 3 widgets |

---

## 2. Navigation Flow

### Current Navigation Structure

```
AuraApp (MaterialApp)
  └── _Shell (StatefulWidget)
       ├── IndexedStack (5 screens)
       │    ├── [0] LibraryScreen      — "Canciones"
       │    ├── [1] AlbumsScreen        — "Álbumes"
       │    ├── [2] ArtistsScreen       — "Artistas"
       │    ├── [3] PlaylistsScreen     — "Listas"
       │    └── [4] SettingsScreen      — "Ajustes"
       │
       ├── MiniPlayer (Positioned, bottom: 70)
       │    └── onTap → PageRouteBuilder → PlayerScreen(song)
       │
       └── NavigationBar (5 destinations)
            └── onDestinationSelected → setState(_idx)
```

### Navigation Pushes

| From | To | Method | Notes |
|---|---|---|---|
| MiniPlayer | PlayerScreen | `PageRouteBuilder` (SlideTransition) | Passes `song` param (redundant) |
| PlayerScreen | EqualizerScreen | `MaterialPageRoute` | Pushes on top of player |
| LibraryScreen → album tap | AlbumDetailScreen | `Navigator.push` | From albums grid |
| LibraryScreen → artist tap | ArtistDetailScreen | `Navigator.push` | Inline in artists_screen |
| Any screen → AddToPlaylist | `AddToPlaylistSheet.show()` | `showModalBottomSheet` | Static method |
| PlayerScreen → queue view | `showModalBottomSheet` | DraggableScrollableSheet | Inline method |
| PlayerScreen → options | `showModalBottomSheet` | Column with ListTiles | Inline method |
| Settings → speed picker | `showModalBottomSheet` | Speed options list | Inline method |
| Settings → sleep timer | `showModalBottomSheet` | Duration options list | Inline method |

### Navigation Issues

| Issue | Severity | Description |
|---|---|---|
| **ForYouScreen not in navigation** | High | `ForYouScreen` exists but is not a tab destination. Only accessible via `RecommendationSection` widget embedded in LibraryScreen. |
| **5-tab NavigationBar crowded** | Medium | 5 tabs with text labels. No visual hierarchy. |
| **PlayerScreen takes Song param** | Medium | `PlayerScreen(song: song)` but reads from `PlayerController.currentSong`. Param is redundant. |
| **No named routes** | Low | All navigation uses imperative `Navigator.push`. No route table. |
| **No deep linking** | Low | Cannot link to specific song/album/playlist. |

---

## 3. Audio Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────┐
│                     main.dart                        │
│                                                      │
│  AudioService.init() → AuraAudioHandler              │
│  PlayerController(handler)                           │
│  EqualizerService(eqRepository)                      │
│  StatsTracker(statsRepository, handler)              │
│                                                      │
│  handler.onSongChanged = (songId) {                  │
│    statsTracker.handleSongChanged(songId)            │
│    equalizerService.loadForSong(songId)              │
│    DynamicThemeService.updateFromAlbumArt(songId)    │
│  }                                                   │
│                                                      │
│  handler.onAudioSessionId = (sessionId) {            │
│    equalizerService.initSession(sessionId)           │
│  }                                                   │
└─────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ AuraAudioHandler │ │ PlayerController │ │ EqualizerService │
│                  │ │                  │ │                  │
│ AudioPlayer      │ │ StatePersistence │ │ MethodChannel    │
│ _queue: Song[]   │ │ _persistence     │ │ "setBandGain"    │
│ _currentIndex    │ │ _sleepTimerSub   │ │ "setBassBoost"   │
│ _errorController │ │ _queueChangeSub  │ │ "setVirtualizer" │
│ _isSkipping      │ │ _playingSub      │ │ "setEnabled"     │
│ _sessionIdSent   │ │                  │ │                  │
└────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ just_audio       │ │ SharedPreferences│ │ Android Native   │
│ (AudioPlayer)    │ │ (queue state)    │ │ (AudioEffect API)│
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

### Audio Flow

```
1. User taps song in LibraryScreen
2. LibraryController.playSong(song) → PlayerController.playSong(song, queue: allSongs)
3. PlayerController delegates → AuraAudioHandler.playSong(song, queue: allSongs)
4. AuraAudioHandler:
   a. Sets _queue = allSongs
   b. Sets _currentIndex = index of song in queue
   c. Calls _queueChangeController.add(null) → triggers queue persistence
   d. Calls _loadCurrent()
5. _loadCurrent():
   a. Resets _sessionIdSent = false
   b. Creates MediaItem (for system notification)
   c. AudioPlayer.setAudioSource(AudioSource.uri(song.uri))
   d. AudioPlayer.play()
   e. onSongChanged?.call(song.id) → triggers stats + EQ + theme
6. AudioPlayer.processingStateStream → ready → _checkAudioSessionId()
7. _checkAudioSessionId(): polls androidAudioSessionId up to 10×500ms
8. When sessionId obtained → onAudioSessionId?.call(sessionId)
9. EqualizerService.initSession(sessionId) → native channel "initSession"
10. If EQ config loaded, _applyFullConfig() → native channel setBandGain/setBassBoost/setVirtualizer
```

### Playback Streams

| Stream | Source | Consumers | Purpose |
|---|---|---|---|
| `playbackState` | `audio_service` (via `BaseAudioHandler`) | System notification | Controls, processing state, position |
| `positionDataStream` | RxDart `combineLatest3` of position/buffered/duration | PlayerScreen seek bar, MiniPlayer progress | Real-time playback position |
| `playingStream` | `just_audio` `_player.playingStream` | PlayerController `_isPlaying` | Play/pause UI state |
| `errorStream` | `AuraAudioHandler._errorController` | Not consumed by UI | Audio errors (file not found, etc.) |
| `onQueueChanged` | `AuraAudioHandler._queueChangeController` | PlayerController (persistence) | Save queue on every change |
| `onSleepTimerExpired` | `SettingsController._sleepTimerController` | PlayerController (pause) | Pause on timer expiry |
| `processingStateStream` | `just_audio` `_player.processingStateStream` | Auto-skip on complete, session ID check | Lifecycle events |

### Queue System

| Operation | Method | Behavior |
|---|---|---|
| Play song with queue | `playSong(song, queue, index)` | Replaces queue, sets index, loads |
| Add to end | `addToQueue(song)` | Appends to `_queue` |
| Play next | `playNext(song)` | Inserts at `_currentIndex + 1` |
| Remove from queue | `removeFromQueue(index)` | Skips if index == current |
| Restore queue | `restoreQueue(songs, index, notify)` | Replaces queue, loads current |
| Skip next | `skipToNext()` | Handles loop modes (off/one/all) |
| Skip previous | `skipToPrevious()` | Seeks to 0 if >3s, else goes to prev |

### Audio Session Handling

**Current approach:** Polling loop in `_checkAudioSessionId()`.

```dart
// audio_handler.dart:74-91
for (int attempt = 0; attempt < 10; attempt++) {
  await Future.delayed(const Duration(milliseconds: 500));
  final sessionId = _player.androidAudioSessionId;
  if (sessionId != null && sessionId != 0) {
    _sessionIdSent = true;
    onAudioSessionId?.call(sessionId);
    return;
  }
}
```

**Problem:** `just_audio` provides `androidAudioSessionId` as a `ValueStream`. Polling is fragile — may fail on slow devices or succeed on attempt 1 but waste 5s on fast devices.

**Correct approach:** Listen to `_player.androidAudioSessionId` stream directly.

### Architectural Problems

| Problem | Location | Severity | Impact |
|---|---|---|---|
| **State duplication** | PlayerController getters proxy AudioHandler | High | Two state layers can diverge |
| **Polling for session ID** | `_checkAudioSessionId()` | High | Fragile, timing-dependent |
| **errorStream not consumed** | No UI listens to errors | Medium | Silent audio failures |
| **_isSkipping flag** | Race condition guard in skipToNext/skipToPrevious | Medium | May block legitimate skips if flag not reset |
| **No preload** | Next track loads only on skip | Medium | Gap between songs on slow storage |
| **Queue persistence in Controller** | PlayerController owns persistence, not Handler | Low | Persistence logic split across layers |
| **Song param redundancy** | PlayerScreen takes Song but reads from Controller | Low | Confusing API, potential for stale data |

---

## 4. State Management

### Provider Tree

Registered in `main.dart` via `MultiProvider`:

| # | Provider | Type | Value/Creation | Purpose |
|---|---|---|---|---|
| 1 | `AuraAudioHandler` | `Provider` | Pre-created singleton | Audio playback, queue |
| 2 | `MediaScanner` | `Provider` | `create: (_) => MediaScanner()` | Media scanning |
| 3 | `PlayerController` | `ChangeNotifierProvider.value` | Pre-created, wraps handler | Player state + persistence |
| 4 | `LibraryController` | `ChangeNotifierProvider` | `create` with scanner + player | Library scan + search |
| 5 | `PlaylistRepository` | `ChangeNotifierProvider` | `create: (_) => PlaylistRepository()` | Playlist CRUD |
| 6 | `FavoritesRepository` | `ChangeNotifierProvider.value` | Pre-created, loaded in main | Favorites |
| 7 | `EqRepository` | `ChangeNotifierProvider` | `create: (_) => EqRepository()` | EQ config persistence |
| 8 | `EqualizerService` | `ChangeNotifierProvider.value` | Pre-created, wraps eqRepository | EQ control |
| 9 | `SettingsController` | `ChangeNotifierProvider.value` | Pre-created, init in main | App settings |
| 10 | `StatsRepository` | `Provider.value` | Singleton instance | Stats data access |
| 11 | `RecommendationEngine` | `ChangeNotifierProvider.value` | Pre-created, computed in main | Recommendations |
| 12 | `StatsTracker` | `Provider.value` | Pre-created | Play event tracking |

**Not in provider tree:**
- `DynamicThemeService` — singleton, accessed directly via `DynamicThemeService.instance`
- `StatePersistenceService` — instantiated inside `PlayerController`
- `AppDatabase` — singleton, accessed directly

### Controllers

| Controller | Extends | Owns State | Delegates To | Issues |
|---|---|---|---|---|
| `PlayerController` | `ChangeNotifier` | `_isPlaying` (bool), subscriptions | `AuraAudioHandler` for all audio ops | Duplicates handler state via getters |
| `LibraryController` | `ChangeNotifier` | `_all`, `_filtered`, `_query`, `_status` | `MediaScanner` for scanning, `PlayerController` for playback | `_all` + `_filtered` = double memory |
| `SettingsController` | `ChangeNotifier` | `_sleepTimerMinutes`, `_playbackSpeed`, `_dynamicThemeEnabled`, `_themeMode`, `_sleepTimerEnd`, `_sleepTimerCountdown` | `SharedPreferences` for persistence | Sleep timer logic + settings mixed |
| `PlaylistRepository` | `ChangeNotifier` | `_playlists` list | `AppDatabase` for CRUD | `loadPlaylists()` never auto-called |
| `FavoritesRepository` | `ChangeNotifier` | `_favoriteIds` Set | `AppDatabase` for CRUD | Loaded in main before providers ready |
| `EqRepository` | `ChangeNotifier` | `_currentConfig` | `AppDatabase` for CRUD | `_currentConfig` only tracks last loaded |
| `RecommendationEngine` | `ChangeNotifier` | `_topPicks`, `_mostPlayed`, `_allStats`, `_isLoading` | `StatsRepository` for data | `statsToSongs` does sequential queries (slow) |

### Services

| Service | Pattern | State | Issues |
|---|---|---|---|
| `AuraAudioHandler` | Extends `BaseAudioHandler` | `_queue`, `_currentIndex`, `_player`, streams | Core audio — well-structured |
| `MediaScanner` | Stateless wrapper | None | `getSongById` queries ALL songs (O(n)) |
| `DynamicThemeService` | Singleton | `_dominantColor`, `_accentColor` | Not ChangeNotifier → UI can't react |
| `EqualizerService` | ChangeNotifier | `_currentConfig`, `_currentSongId` | Depends on MethodChannel availability |
| `StatePersistenceService` | Stateless service | `_prefs` (lazy init) | Instantiated inside PlayerController |
| `StatsTracker` | Stateless tracker | `_currentSongId`, `_listenedSeconds`, subscriptions | Not ChangeNotifier, not in DI |

### Repositories

| Repository | Pattern | DB Tables | Issues |
|---|---|---|---|
| `PlaylistRepository` | ChangeNotifier + sqflite | `playlists`, `playlist_songs` | Denormalized song data in playlist_songs |
| `FavoritesRepository` | ChangeNotifier + sqflite | `favorites` | Clean — single responsibility |
| `EqRepository` | ChangeNotifier + sqflite | `eq_configs` | `_currentConfig` only tracks last loaded song |
| `StatsRepository` | Singleton + ChangeNotifier + sqflite | `play_events`, `song_stats` | Factory constructor + singleton = confusing API |

### Responsibilities Mixed

| Location | Mixed Concerns | Should Be |
|---|---|---|---|
| `PlayerController` | Audio state + persistence + sleep timer listening | Split: PlayerController (state) + QueuePersistenceService + SleepTimerListener |
| `SettingsController` | Settings values + sleep timer countdown + persistence | Split: SettingsStore (values) + SleepTimerManager (countdown) |
| `AuraAudioHandler` | Audio playback + queue management + session ID polling + system notification sync | Session ID polling should be separate |
| `main.dart` | DI + initialization + event wiring + app bootstrap | Extract initialization to `AppInitializer` class |

### State Duplications

| Duplicated State | Location A | Location B | Risk |
|---|---|---|---|
| `isPlaying` | `AudioHandler._player.playing` | `PlayerController._isPlaying` | Can diverge if handler state changes without controller notification |
| `currentSong` | `AudioHandler.currentSong` | `PlayerController.currentSong` (getter) | Low risk — getter delegates, but adds indirection |
| `queue` | `AudioHandler.songQueue` | `PlayerController.queue` (getter) | Low risk — getter delegates |
| `currentIndex` | `AudioHandler.currentIndex` | `PlayerController.currentIndex` (getter) | Low risk — getter delegates |
| `accentColor` | `DynamicThemeService._accentColor` | `PlayerController.accentColor` (getter) | Medium risk — DynamicThemeService not reactive |
| `sleep timer state` | `SettingsController._sleepTimerEnd` | `PlayerController` listens via stream | Low risk — stream-based, but timer logic in wrong layer |

### Dangerous Dependencies

| Dependency | From | To | Risk |
|---|---|---|---|
| `PlayerController` → `StatePersistenceService` | Direct instantiation | Tightly coupled, not injectable, not testable | High |
| `PlayerController` → `DynamicThemeService` | Direct singleton access | Hidden dependency, not mockable | Medium |
| `main.dart` → all services | Direct references | 110-line init block, hard to test | Medium |
| `RecommendationEngine.statsToSongs` | Sequential `MediaScanner.getSongById` calls | O(n) queries, blocks UI | High |
| `StatsRepository` | Factory + singleton pattern | `StatsRepository()` constructor exists but `instance` is singleton | Medium |

### Singleton Problems

| Singleton | Issue | Impact |
|---|---|---|
| `DynamicThemeService` | Mutable state, not in DI tree, not ChangeNotifier | Cannot test, cannot react to changes |
| `AppDatabase` | Mutable `_db` field, no close method | Cannot reset for testing, connection never released |
| `StatsRepository` | Factory constructor + private singleton constructor | Confusing API — `StatsRepository()` creates different instance than `StatsRepository.instance` |
| `audioHandler` (global) | `late AuraAudioHandler audioHandler` in main.dart | Global mutable variable, not injectable |
| `equalizerService` (global) | `late EqualizerService equalizerService` in main.dart | Global mutable variable |

---

## 5. Database Layer

### Schema

```sql
-- Table: favorites
CREATE TABLE favorites (
  song_id INTEGER PRIMARY KEY
);

-- Table: eq_configs
CREATE TABLE eq_configs (
  song_id INTEGER PRIMARY KEY,
  band_gains TEXT NOT NULL,        -- JSON array of 12 doubles
  bass_boost REAL DEFAULT 0.0,
  virtualizer REAL DEFAULT 0.0,
  enabled INTEGER DEFAULT 1,
  preset_name TEXT
);

-- Table: playlists
CREATE TABLE playlists (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL          -- ISO 8601
);

-- Table: playlist_songs
CREATE TABLE playlist_songs (
  playlist_id INTEGER,
  song_id INTEGER,
  song_title TEXT,                  -- DENORMALIZED
  song_artist TEXT,                 -- DENORMALIZED
  song_uri TEXT,                    -- DENORMALIZED
  song_duration INTEGER,            -- DENORMALIZED
  album_id INTEGER,                 -- DENORMALIZED
  position INTEGER,
  PRIMARY KEY (playlist_id, song_id)
);

-- Table: play_events
CREATE TABLE play_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id INTEGER NOT NULL,
  title TEXT NOT NULL,              -- DENORMALIZED
  artist TEXT NOT NULL,             -- DENORMALIZED
  duration_seconds REAL NOT NULL,
  listened_seconds REAL NOT NULL,
  was_skipped INTEGER NOT NULL DEFAULT 0,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  played_at TEXT NOT NULL           -- ISO 8601
);

-- Table: song_stats
CREATE TABLE song_stats (
  song_id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,              -- DENORMALIZED
  artist TEXT NOT NULL,             -- DENORMALIZED
  play_count INTEGER NOT NULL DEFAULT 0,
  skip_count INTEGER NOT NULL DEFAULT 0,
  total_listened_seconds REAL NOT NULL DEFAULT 0.0,
  total_duration_seconds REAL NOT NULL DEFAULT 0.0,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  last_played TEXT                  -- ISO 8601
);
```

### Table Analysis

| Table | Purpose | Rows | Growth | Issues |
|---|---|---|---|---|
| `favorites` | User's favorite songs | ≤ library size | Stable | Clean design |
| `eq_configs` | Per-song EQ settings | ≤ library size | Stable | `band_gains` as JSON string — no validation |
| `playlists` | Playlist metadata | User-defined | Slow growth | Clean design |
| `playlist_songs` | Playlist membership | playlists × songs | Medium | Denormalized song data; no FK constraint; no index on playlist_id |
| `play_events` | Every play event | Unbounded | **Fast growth** | No cleanup mechanism; will grow indefinitely |
| `song_stats` | Aggregated song stats | ≤ library size | Stable | Denormalized title/artist; stale if song metadata changes |

### Migration Status

| Aspect | Status | Risk |
|---|---|---|
| Database version | Always `1` | Cannot track schema evolution |
| `onUpgrade` | Re-runs `CREATE TABLE IF NOT EXISTS` | Cannot add columns or change types |
| `onOpen` | Re-runs `CREATE TABLE IF NOT EXISTS` | Unnecessary overhead on every launch |
| Foreign keys | Not enabled | Orphaned records possible |
| Indexes | Only PRIMARY KEY | Slow queries on `playlist_songs` by `playlist_id` |

### Persistence Patterns

| Data | Storage Method | Serialization | Issues |
|---|---|---|---|
| Queue state | SharedPreferences → JSON | `Song.toJson()` / `Song.fromJson()` | Breaks if Song model changes |
| Settings | SharedPreferences | Typed (int/double/bool) | Scattered across SettingsController |
| Favorites | SQLite `favorites` table | Direct int storage | Clean |
| EQ configs | SQLite `eq_configs` table | JSON for band_gains | Clean but JSON-in-SQL |
| Playlists | SQLite `playlists` + `playlist_songs` | Direct + denormalized | Denormalization causes staleness |
| Stats | SQLite `play_events` + `song_stats` | Direct | play_events grows unbounded |

### Structural Problems

| Problem | Severity | Description |
|---|---|---|
| **No migrations** | High | Adding any column requires manual DB wipe or custom migration code |
| **Denormalized playlist_songs** | Medium | Song title/artist/uri stored directly. If file is moved, playlist data is stale |
| **Unbounded play_events** | Medium | No automatic cleanup. `clearOldEvents()` exists but is never called |
| **No FK enforcement** | Medium | `playlist_songs` can reference deleted playlists. `play_events` can reference deleted songs |
| **No indexes** | Low | `playlist_songs` queries by `playlist_id` have no index beyond composite PK |
| **JSON in SQL column** | Low | `band_gains` stored as JSON string. No schema validation at DB level |
| **Stale song_stats metadata** | Low | title/artist in song_stats don't update if on_audio_query returns different metadata |

---

## 6. Theme System

### Current Architecture

```
AuraColors (static constants)
  ├── Dark palette: background, surface, surfaceHigh, primary, secondary, accent, text, textMuted, divider
  └── Light palette: lightBackground, lightSurface, lightSurfaceHigh, lightText, lightTextMuted, lightDivider

AuraTheme (static methods)
  ├── dark() → ThemeData (M3, dark ColorScheme, custom nav bar + slider themes)
  └── light() → ThemeData (M3, light ColorScheme, custom nav bar + slider themes)

DynamicThemeService (singleton)
  ├── _dominantColor: Color (default: #7C4DFF)
  ├── _accentColor: Color (default: #00E5FF)
  └── updateFromAlbumArt(albumId) → extracts palette via PaletteGenerator
```

### Color Extraction Flow

```
1. onSongChanged(songId) fires in main.dart
2. If settings.dynamicThemeEnabled:
3.   DynamicThemeService.instance.updateFromAlbumArt(songId)
4.     OnAudioQuery.queryArtwork(albumId, ArtworkType.ALBUM)
5.     If art bytes available:
6.       ui.instantiateImageCodec(bytes)
7.       codec.getNextFrame() → image
8.       PaletteGenerator.fromImage(image)
9.       _dominantColor = palette.dominantColor
10.      _accentColor = palette.vibrantColor (fallback: mutedColor)
```

### Theme Application

| Location | How Theme Applied | Reactive? |
|---|---|---|
| `AuraApp` | `settings.themeMode` → `themeMode` on MaterialApp | Yes — `context.watch<SettingsController>()` |
| `PlayerScreen` | `ctrl.accentColor` → gradient background | No — DynamicThemeService not ChangeNotifier |
| `_Shell` | `settings.themeMode` → background/nav colors | Yes — watches SettingsController |
| `SettingsScreen` | `settings.themeMode` → all colors | Yes — watches SettingsController |
| All other screens | Static `AuraColors` constants | No — only change on theme mode toggle |

### Theme Problems

| Problem | Severity | Description |
|---|---|---|
| **DynamicThemeService not ChangeNotifier** | High | Colors change but UI doesn't rebuild. PlayerScreen gradient stays stale. |
| **Palette extraction on main thread** | Medium | `ui.instantiateImageCodec` + `PaletteGenerator.fromImage` block UI. Can cause jank. |
| **No fallback for missing art** | Medium | If album art is null, colors stay at defaults. No hash-based fallback. |
| **No desaturation for readability** | Low | Extracted colors used directly. May have poor contrast with text. |
| **Light theme incomplete** | Medium | `AuraTheme.light()` exists but many screens hardcode dark `AuraColors` values |
| **No theme transition animation** | Low | Theme mode switch is instant — no crossfade |

---

## 7. Native Android Layer

### MethodChannel: Equalizer

**Channel name:** `com.daviddev.aura/equalizer`

**Methods invoked from Flutter:**

| Method | Parameters | Purpose |
|---|---|---|
| `initSession` | `{sessionId: int}` | Initialize Android AudioEffect session |
| `setEnabled` | `{enabled: bool}` | Toggle EQ on/off |
| `setBandGain` | `{bandIndex: int, gainDb: double}` | Set individual band (-12 to +12 dB) |
| `setBassBoost` | `{gainDb: double}` | Set bass boost strength (0 to 15) |
| `setVirtualizer` | `{strength: double}` | Set virtualizer strength (0 to 1) |

**Band frequencies:** 31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 12000, 16000, 20000 Hz (12 bands)

### Native Integration Status

| Component | Status | Notes |
|---|---|---|
| MethodChannel | Defined in Dart | Native Kotlin implementation expected in `android/` |
| EqualizerEngine | MethodChannel calls | No capability detection — assumes native code exists |
| Error handling | try/catch in Dart | Errors logged via `debugPrint`, no user feedback |
| Session lifecycle | initSession on audio ready | No cleanup/dispose call on session end |

### Native Layer Problems

| Problem | Severity | Description |
|---|---|---|
| **No capability detection** | High | EQ silently fails on devices without native support. No UI indicator. |
| **No error recovery** | Medium | MethodChannel errors caught and logged, but EQ state becomes inconsistent |
| **No session cleanup** | Medium | No `dispose` or `release` call when app backgrounds or song changes |
| **Android folder regenerated on CI** | Low | Native code must be preserved across CI rebuilds |

---

## 8. Technical Debt

### Debt Register

| ID | Debt | Category | Severity | Effort | Description |
|---|---|---|---|---|---|
| TD-01 | PlayerController state duplication | Architecture | High | 2 days | Getters proxy AudioHandler. `_isPlaying` duplicates `_player.playing`. Split or eliminate. |
| TD-02 | DynamicThemeService singleton | Architecture | High | 1 day | Convert to ChangeNotifier, add to DI tree, expose color streams. |
| TD-03 | No DB migrations | Database | High | 2 days | Implement versioned migrations. Add ALTER TABLE paths. |
| TD-04 | main.dart 110-line init block | Architecture | High | 3 days | Extract to `AppInitializer` class. Separate DI from initialization logic. |
| TD-05 | Polling for audio session ID | Audio | High | 1 day | Replace with stream listener on `androidAudioSessionId`. |
| TD-06 | PlaylistRepository not auto-loaded | State | Medium | 0.5 days | Call `loadPlaylists()` at startup or lazy-load on first access. |
| TD-07 | Favorites loaded before providers | State | Medium | 0.5 days | Move `loadFavorites()` into provider creation or lazy-load. |
| TD-08 | errorStream not consumed | Audio | Medium | 1 day | Wire errorStream to UI. Show non-intrusive error banners. |
| TD-09 | StatsRepository factory + singleton | Architecture | Medium | 0.5 days | Remove factory constructor. Use singleton only. |
| TD-10 | Denormalized playlist_songs | Database | Medium | 1 day | Store only song_id. Resolve from MediaScanner at read time. |
| TD-11 | Unbounded play_events growth | Database | Medium | 0.5 days | Call `clearOldEvents()` periodically. Add auto-cleanup. |
| TD-12 | Palette extraction on main thread | Performance | Medium | 1 day | Move to `compute()` or isolate. |
| TD-13 | MediaScanner.getSongById O(n) | Performance | Medium | 1 day | Query single song by ID instead of scanning all songs. |
| TD-14 | StatePersistenceService direct instantiation | Architecture | Low | 0.5 days | Inject via DI instead of `PlayerController` creating its own instance. |
| TD-15 | No named routes | Navigation | Low | 1 day | Implement route table with named routes or GoRouter. |
| TD-16 | ForYouScreen not in navigation | Navigation | Low | 0.5 days | Add as tab or integrate into existing navigation. |
| TD-17 | Global mutable variables | Architecture | Low | 1 day | `audioHandler` and `equalizerService` as `late` globals. Move to DI. |
| TD-18 | No FK constraints | Database | Low | 0.5 days | Enable `PRAGMA foreign_keys = ON`. Add ON DELETE CASCADE. |
| TD-19 | Hardcoded Spanish strings | i18n | Low | 2 days | Extract to arb files. Implement localization. |
| TD-20 | No empty state screens | UX | Low | 1 day | Design and implement empty states for all screens. |

### Priority Matrix

```
High Severity          Medium Severity         Low Severity
┌─────────────────┐   ┌───────────────────┐   ┌───────────────────┐
│ TD-01  2 days   │   │ TD-06  0.5 days   │   │ TD-14  0.5 days   │
│ TD-02  1 day    │   │ TD-07  0.5 days   │   │ TD-15  1 day      │
│ TD-03  2 days   │   │ TD-08  1 day      │   │ TD-16  0.5 days   │
│ TD-04  3 days   │   │ TD-09  0.5 days   │   │ TD-17  1 day      │
│ TD-05  1 day    │   │ TD-10  1 day      │   │ TD-18  0.5 days   │
│                 │   │ TD-11  0.5 days   │   │ TD-19  2 days     │
│                 │   │ TD-12  1 day      │   │ TD-20  1 day      │
│                 │   │ TD-13  1 day      │   │                   │
├─────────────────┤   ├───────────────────┤   ├───────────────────┤
│ Total: 9 days   │   │ Total: 7 days     │   │ Total: 7 days     │
└─────────────────┘   └───────────────────┘   └───────────────────┘
```

**Total estimated debt payoff:** 23 developer-days

### Architectural Refactor Priorities

1. **Eliminate state duplication** (TD-01) — Foundation for all other work
2. **Make theme reactive** (TD-02) — Required for Phase 2 design system
3. **Fix audio session handling** (TD-05) — Required for reliable EQ
4. **Database migrations** (TD-03) — Required before any schema change
5. **Extract AppInitializer** (TD-04) — Improves testability and clarity
6. **Wire error feedback** (TD-08) — User-facing quality improvement
7. **Fix state loading order** (TD-06, TD-07) — Prevents empty states on launch
8. **Performance fixes** (TD-12, TD-13) — Eliminates jank sources

---

> **Note:** This document reflects the architecture as of 2026-05-17. Update when any structural change is made.
