# AURA Music — Engram

> Project memory. Persistent across sessions. Update when architecture, conventions, or state change.

---

## Identity

- **Name:** AURA Music Player
- **Platform:** Android only (Flutter)
- **Version:** 1.1.0 → targeting premium reconstruction
- **Type:** Offline local music player
- **Package:** `com.daviddev.aura_music`
- **Repo:** `/root/termux_home/aura_music`

---

## Stack

| Layer | Tech | Version |
|---|---|---|
| Framework | Flutter SDK | >=3.0.0 <4.0.0 |
| Audio engine | just_audio | ^0.9.36 |
| Background service | audio_service | ^0.18.12 |
| Media query | on_audio_query | ^2.9.0 |
| State | Provider + ChangeNotifier | ^6.1.1 |
| DB | sqflite + path | ^2.3.0 / ^1.8.3 |
| Preferences | shared_preferences | ^2.2.2 |
| Streams | rxdart | ^0.27.7 |
| UI helpers | flutter_slidable | ^3.0.1 |
| Colors | palette_generator | ^0.3.3+3 |
| Permissions | permission_handler | ^11.1.0 |

---

## Architecture Map

```
lib/
├── main.dart                          # DI root. 13 providers. Init order critical.
├── app.dart                           # MaterialApp + _Shell (5-tab IndexedStack + MiniPlayer overlay)
│
├── core/theme/
│   └── app_theme.dart                 # AuraColors (dark + light palettes), AuraTheme (M3)
│
├── data/
│   ├── models/
│   │   ├── song.dart                  # Immutable. id/title/artist/album/uri/duration/albumArtUri. toJson/fromJson.
│   │   ├── playlist.dart              # id/name/songs/createdAt. toMap/fromMap/copyWith.
│   │   ├── artist.dart                # Wrapper for on_audio_query ArtistModel.
│   │   ├── eq_config.dart             # bandGains[12]/bassBoost/virtualizer/enabled/presetName.
│   │   └── song_stats.dart            # playCount/skipCount/totalListened/score.
│   ├── database/
│   │   └── app_database.dart          # Singleton. 6 tables: favorites, eq_configs, playlists, playlist_songs, play_events, song_stats. Version=1. No migrations.
│   └── repositories/
│       ├── playlist_repository.dart   # CRUD playlists. ChangeNotifier. loadPlaylists() NOT auto-called.
│       ├── favorites_repository.dart  # Set<int> _favoriteIds. toggleFavorite/addFavorite/removeFavorite.
│       ├── eq_repository.dart         # Per-song EQ config persistence.
│       └── stats_repository.dart      # Play events + song stats aggregation.
│
├── services/
│   ├── audio_handler.dart             # AuraAudioHandler extends BaseAudioHandler+QueueHandler+SeekHandler. Owns AudioPlayer. Queue management. Error stream.
│   ├── media_scanner.dart             # on_audio_query wrapper. scanSongs/Albums/Artists. Permission handling.
│   ├── state_persistence_service.dart # QueueState serialization to SharedPreferences. 24h staleness.
│   ├── dynamic_theme_service.dart     # Singleton. Extracts palette from album art. NOT ChangeNotifier.
│   ├── equalizer_service.dart         # MethodChannel to native. 12-band EQ + bass boost + virtualizer.
│   └── stats_tracker.dart             # Tracks play events. Flushes on song change.
│
├── features/
│   ├── library/                       # LibraryController + LibraryScreen. Search filter. Shuffle all.
│   ├── albums/                        # albums_screen.dart (grid) + album_detail_screen.dart (songs list).
│   ├── artists/                       # artists_screen.dart (list + detail).
│   ├── playlists/                     # playlists_screen.dart (CRUD) + playlist_detail_screen.dart.
│   ├── player/                        # PlayerController (wraps handler) + PlayerScreen (full UI).
│   ├── settings/                      # SettingsController (sleep timer, speed, theme) + SettingsScreen.
│   ├── equalizer/                     # equalizer_screen.dart.
│   ├── discover/                      # recommendation_engine.dart (score-based).
│   ├── smart_recommendations/         # api/ + models/ (external AI - not yet integrated).
│   └── home/                          # for_you_screen.dart + widgets/ (minimal content).
│
└── widgets/
    ├── mini_player.dart               # Glassmorphism. Dismissible for skip (UX issue). Circular progress.
    ├── song_tile.dart                 # Reusable tile with Slidable action.
    └── add_to_playlist_sheet.dart     # Bottom sheet for adding song to playlist.
```

---

## Data Flow

```
User tap → LibraryController.playSong() → PlayerController.playSong() → AuraAudioHandler.playSong()
  → _queue set → _loadCurrent() → AudioPlayer.setAudioSource() → AudioPlayer.play()
  → onSongChanged callback → StatsTracker + EqualizerService + DynamicThemeService
  → PlayerController notifyListeners() → UI rebuild
```

---

## Provider Tree (main.dart)

1. `Provider<AuraAudioHandler>` — global audio handler
2. `Provider<MediaScanner>` — media scanning
3. `ChangeNotifierProvider.value(PlayerController)` — player state
4. `ChangeNotifierProvider(LibraryController)` — library state
5. `ChangeNotifierProvider(PlaylistRepository)` — playlists (NOT auto-loaded)
6. `ChangeNotifierProvider.value(FavoritesRepository)` — favorites
7. `ChangeNotifierProvider<EqRepository>` — EQ configs
8. `ChangeNotifierProvider.value(EqualizerService)` — EQ control
9. `ChangeNotifierProvider.value(SettingsController)` — settings
10. `Provider.value(StatsRepository)` — stats data
11. `ChangeNotifierProvider.value(RecommendationEngine)` — recommendations
12. `Provider.value(StatsTracker)` — play tracking
13. (implicit) DynamicThemeService — singleton, NOT in provider tree

---

## Database Schema (aura.db, v1)

```sql
favorites          — song_id PK
eq_configs         — song_id PK, band_gains TEXT, bass_boost, virtualizer, enabled, preset_name
playlists          — id PK AUTOINCREMENT, name, created_at
playlist_songs     — (playlist_id, song_id) PK, song_title, song_artist, song_uri, song_duration, album_id, position
play_events        — id PK AUTOINCREMENT, song_id, title, artist, duration_seconds, listened_seconds, was_skipped, is_favorite, played_at
song_stats         — song_id PK, title, artist, play_count, skip_count, total_listened_seconds, total_duration_seconds, is_favorite, last_played
```

**Issues:** No migrations. No foreign keys. No indexes beyond PK. Denormalized playlist_songs.

---

## Build Commands

```
flutter pub get
flutter analyze --no-fatal-infos
flutter build apk --release
```

CI: `.github/workflows/build.yml` — runs on push to master. Regenerates android/ from scratch.

---

## Known Bugs & Pitfalls

| Issue | Location | Status |
|---|---|---|
| String interpolation `\$` → literal `$` | Fixed (6 instances) | ✅ |
| `MaterialStateProperty` deprecated | Use `WidgetStateProperty` | ✅ |
| `background` in ColorScheme deprecated | Use `surface` | ✅ |
| Artist `?? 0` dead expression | numberOfTracks non-nullable | ✅ |
| PlayerController duplicates AudioHandler state | `player_controller.dart` getters | ⚠️ Open |
| DynamicThemeService not ChangeNotifier | `dynamic_theme_service.dart` | ⚠️ Open |
| PlaylistRepository.loadPlaylists() never called | `main.dart:97` | ⚠️ Open |
| Favorites loaded before providers registered | `main.dart:41` | ⚠️ Open |
| No DB migration strategy | `app_database.dart` | ⚠️ Open |
| EQ session ID retry loop (10×500ms) | `audio_handler.dart:74-91` | ⚠️ Open |
| MiniPlayer Dismissible skips tracks (unintuitive) | `mini_player.dart` | ⚠️ Open |
| PlayerScreen takes redundant Song param | `player_screen.dart:13` | ⚠️ Open |
| Palette extraction on main thread | `dynamic_theme_service.dart` | ⚠️ Open |
| Seek bar onChange fires continuously | `player_screen.dart` slider | ⚠️ Open |
| Scattered SharedPreferences usage | SettingsController + StatePersistenceService | ⚠️ Open |
| Defensive CREATE TABLE in onOpen | `app_database.dart:78-84` | ⚠️ Open |
| No empty state screens | Playlists/Albums/Artists | ⚠️ Open |
| No global error handling | App-wide | ⚠️ Open |

---

## Conventions

- **Files:** snake_case.dart
- **Classes:** PascalCase
- **Variables/fns:** camelCase
- **Constants:** static const in AuraColors
- **UI language:** Spanish (LatAm/ES)
- **State:** notifyListeners() after async ops in controllers
- **Dispose:** All ChangeNotifiers + StreamSubscriptions must dispose
- **Imports:** Minimal — unused = warning = CI fail
- **No custom fonts** — system default only (APK size)
- **Dark mode default** — light mode alternative

---

## Roadmap Status

**Phase 1 (Core Stabilization)** — NOT STARTED
- 29 checklist items. P0: state sync, queue persistence, favorites load, theme service, playlist auto-load.

**Phase 2 (Design System)** — NOT STARTED
- Token system, glassmorphism, 6 screen redesigns.

**Phase 3 (Premium Experience)** — NOT STARTED
- Gestures, queue reorder, lyrics, crossfade, recommendations.

**Phase 4 (Branding)** — NOT STARTED
- Logo, app icon, splash, brand identity.

**Phase 5 (Optimization & Release)** — NOT STARTED
- Performance, QA, release prep.

Full roadmap: `docs/ROADMAP.md`

---

## Active Decisions

- Keep Provider (no Riverpod/Bloc migration planned)
- Keep "AURA" name (branding exploration in Phase 4)
- Spanish UI language (no i18n planned yet)
- Android only (no iOS target)
- No custom fonts (APK size constraint)
- sqflite for local DB (no migration to drift/isar planned)

---

## Session Notes

- 2026-05-17: Created `docs/ROADMAP.md` — 1043 lines, 8 sections, 5 phases, 106 total checklist items. Strategic doc only. No code changes.
- Caveman mode: active (full intensity).
