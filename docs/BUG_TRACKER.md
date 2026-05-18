# AURA Music — Bug Tracker

> **Date:** 2026-05-17
> **Source:** Code analysis of actual project files
> **Status:** Active — bugs identified from code review, not runtime testing

---

## Table of Contents

1. [Bug Summary Table](#1-bug-summary-table)
2. [Critical Bugs](#2-critical-bugs)
3. [High Severity Bugs](#3-high-severity-bugs)
4. [Medium Severity Bugs](#4-medium-severity-bugs)
5. [Low Severity Bugs](#5-low-severity-bugs)
6. [Architecture Bugs](#6-architecture-bugs)
7. [UX Bugs](#7-ux-bugs)
8. [Performance Bugs](#8-performance-bugs)
9. [Persistence Bugs](#9-persistence-bugs)

---

## 1. Bug Summary Table

| ID | Bug | Severity | Status | Affected Area | Probable Cause | Files Involved |
|---|---|---|---|---|---|---|
| BUG-01 | Dynamic theme doesn't update UI | Critical | Open | Theme | DynamicThemeService not ChangeNotifier | `dynamic_theme_service.dart`, `player_screen.dart` |
| BUG-02 | Playlists empty on launch | Critical | Open | Playlists | `loadPlaylists()` never called | `main.dart`, `playlists_screen.dart` |
| BUG-03 | Favorites race condition on init | Critical | Open | Favorites | Loaded before providers registered | `main.dart`, `favorites_repository.dart` |
| BUG-04 | EQ silently fails on unsupported devices | Critical | Open | Equalizer | No capability detection | `equalizer_service.dart` |
| BUG-05 | Audio session ID polling is fragile | High | Open | Audio | Polling loop instead of stream listener | `audio_handler.dart` |
| BUG-06 | errorStream not consumed by UI | High | Open | Audio | No listener registered | `audio_handler.dart`, `player_screen.dart` |
| BUG-07 | seek bar fires continuously during drag | High | Open | Player UI | `onChanged` vs `onChangeEnd` | `player_screen.dart` |
| BUG-08 | PlayerController._isPlaying can diverge | High | Open | State | Duplicate state from handler | `player_controller.dart` |
| BUG-09 | Shuffle doesn't reorder visible queue | High | Open | Queue | Uses just_audio internal shuffle only | `audio_handler.dart` |
| BUG-10 | Queue restore may load invalid URIs | High | Open | Persistence | No URI validation on restore | `state_persistence_service.dart`, `player_controller.dart` |
| BUG-11 | StatsRepository factory vs singleton conflict | Medium | Open | Architecture | Two ways to create instance | `stats_repository.dart` |
| BUG-12 | play_events table grows unbounded | Medium | Open | Database | `clearOldEvents()` never called | `stats_repository.dart` |
| BUG-13 | Playlist songs denormalized and stale | Medium | Open | Playlists | Stores title/artist/uri directly | `playlist_repository.dart`, `app_database.dart` |
| BUG-14 | Palette extraction blocks main thread | Medium | Open | Performance | Codec + PaletteGenerator on UI thread | `dynamic_theme_service.dart` |
| BUG-15 | MediaScanner.getSongById scans all songs | Medium | Open | Performance | O(n) query for single song | `media_scanner.dart` |
| BUG-16 | EQ preset name not persisted correctly | Medium | Open | Equalizer | applyPreset doesn't save preset_name | `equalizer_service.dart` |
| BUG-17 | Song.isFavorite field always false | Medium | Open | Favorites | Never populated from repository | `song.dart`, `favorites_repository.dart` |
| BUG-18 | No database migration strategy | Medium | Open | Database | Version always 1, no ALTER TABLE | `app_database.dart` |
| BUG-19 | PlayerScreen redundant Song parameter | Low | Open | Navigation | Param unused, reads from controller | `player_screen.dart` |
| BUG-20 | MiniPlayer Dismissible skips tracks | Low | Open | UX | Dismissible direction = skip, not close | `mini_player.dart` |
| BUG-21 | Defensive CREATE TABLE in onOpen | Low | Open | Performance | Re-runs all CREATE on every launch | `app_database.dart` |
| BUG-22 | No foreign key enforcement | Low | Open | Database | PRAGMA foreign_keys not enabled | `app_database.dart` |
| BUG-23 | Light theme screens hardcoded dark colors | Low | Open | Theme | Screens use AuraColors directly | `library_screen.dart`, `albums_screen.dart` |
| BUG-24 | No empty state for albums/artists | Low | Open | UX | Blank screen when no data | `albums_screen.dart`, `artists_screen.dart` |
| BUG-25 | ForYouScreen not accessible from nav | Low | Open | Navigation | Screen exists but not a tab | `for_you_screen.dart`, `app.dart` |
| BUG-26 | Global mutable variables in main.dart | Low | Open | Architecture | `late audioHandler`, `late equalizerService` | `main.dart` |
| BUG-27 | Settings typo: "sueno" missing tilde | Low | Open | UI | Missing ñ in "sueño" | `settings_screen.dart` |
| BUG-28 | Settings typo: "Reproduccion" missing accent | Low | Open | UI | Missing ó in "Reproducción" | `settings_screen.dart` |

---

## 2. Critical Bugs

### BUG-01: Dynamic theme doesn't update UI

**Description:**
`DynamicThemeService` extracts colors from album art but is a plain singleton, not a `ChangeNotifier`. When `updateFromAlbumArt()` changes `_dominantColor` and `_accentColor`, no `notifyListeners()` is called. UI screens that read these colors do not rebuild.

**Steps to Reproduce:**
1. Play a song with colorful album art
2. Observe PlayerScreen gradient background
3. Skip to a song with different colored album art
4. Gradient background does not change

**Expected Behavior:**
PlayerScreen gradient updates to match new song's album art colors.

**Actual Behavior:**
Gradient stays at colors from first song (or defaults). Only changes if screen is rebuilt for unrelated reason.

**Probable Root Cause:**
`DynamicThemeService` is not a `ChangeNotifier`. No mechanism exists to notify listeners of color changes. `PlayerController.accentColor` is a getter to `DynamicThemeService.instance._accentColor` but does not trigger rebuilds.

**Files Affected:**
- `lib/services/dynamic_theme_service.dart` — not ChangeNotifier
- `lib/features/player/player_controller.dart:76` — getter doesn't trigger rebuild
- `lib/features/player/player_screen.dart:22` — reads accentColor but won't rebuild on change
- `lib/main.dart:77-79` — calls updateFromAlbumArt but no one listens

**Suggested Fix Direction:**
Convert `DynamicThemeService` to `ChangeNotifier`. Call `notifyListeners()` after color extraction. Expose as `ChangeNotifierProvider` in DI tree. PlayerScreen uses `context.watch` or `Consumer` to react.

**Priority:** P0 — Core visual feature broken

---

### BUG-02: Playlists empty on launch

**Description:**
`PlaylistRepository` is registered as a `ChangeNotifierProvider` in `main.dart`, but `loadPlaylists()` is never called. The repository starts with an empty `_playlists` list. Users see empty playlist screen until they manually trigger a load (if such trigger exists).

**Steps to Reproduce:**
1. Create a playlist
2. Kill and restart the app
3. Navigate to Playlists tab
4. Screen shows empty or no playlists

**Expected Behavior:**
Saved playlists load automatically on app start.

**Actual Behavior:**
`_playlists` remains empty. `loadPlaylists()` must be called manually.

**Probable Root Cause:**
`main.dart:97` — `ChangeNotifierProvider(create: (_) => PlaylistRepository())` creates the repository but never calls `loadPlaylists()`. No other code calls it at startup.

**Files Affected:**
- `lib/main.dart:97` — provider creation without load
- `lib/data/repositories/playlist_repository.dart:13-22` — loadPlaylists() exists but unused at startup
- `lib/features/playlists/playlists_screen.dart` — displays empty list

**Suggested Fix Direction:**
Call `loadPlaylists()` in the provider's `create` callback as an async init, or add an `init()` method to `PlaylistRepository` called during app bootstrap.

**Priority:** P0 — Core feature non-functional

---

### BUG-03: Favorites race condition on init

**Description:**
`FavoritesRepository.loadFavorites()` is called in `main.dart:41` before the `MultiProvider` tree is built. If any widget tries to access favorites during its build (before providers are ready), it will see an empty set.

**Steps to Reproduce:**
1. Add songs to favorites
2. Restart app
3. Navigate to a screen that checks `favRepo.isFavorite(songId)` during build
4. Favorites may appear empty briefly

**Expected Behavior:**
Favorites are available immediately when screens render.

**Actual Behavior:**
Race between favorites load and widget build. Screens may render with empty favorites.

**Probable Root Cause:**
`main.dart:40-41` — `loadFavorites()` called before `runApp(MultiProvider(...))`. The repository instance used for loading may differ from the one provided if any async gap exists.

**Files Affected:**
- `lib/main.dart:40-41` — load before providers
- `lib/data/repositories/favorites_repository.dart:14-22` — loadFavorites implementation
- `lib/features/player/player_screen.dart:102-115` — Consumer<FavoritesRepository>

**Suggested Fix Direction:**
Move `loadFavorites()` into `FavoritesRepository` constructor or into a provider `create` callback with async initialization. Ensure the same instance is used for both loading and providing.

**Priority:** P0 — Core feature unreliable

---

### BUG-04: EQ silently fails on unsupported devices

**Description:**
`EqualizerService` invokes `MethodChannel` calls without checking if the native channel is available. If the native code is missing, misconfigured, or the device doesn't support AudioEffect, all EQ calls fail silently (caught in try/catch, logged via debugPrint).

**Steps to Reproduce:**
1. Run app on device without native EQ implementation
2. Open equalizer screen
3. Adjust bands or toggle EQ
4. No error shown, EQ appears to work but audio is unchanged

**Expected Behavior:**
App detects EQ unavailability and shows UI indicator (disabled state, error message, or hidden EQ option).

**Actual Behavior:**
EQ UI is fully interactive. Changes appear to save. Audio is unaffected. No user feedback.

**Probable Root Cause:**
`equalizer_service.dart` — all MethodChannel calls wrapped in try/catch that only `debugPrint`. No capability detection. No error state exposed to UI.

**Files Affected:**
- `lib/services/equalizer_service.dart` — all MethodChannel invocations
- `lib/features/equalizer/equalizer_screen.dart` — no error state
- `lib/features/player/player_screen.dart:178-204` — EQ button always visible

**Suggested Fix Direction:**
Add `isAvailable` flag to `EqualizerService`. Test channel availability on init. Expose as stream/value. UI checks availability before showing EQ controls.

**Priority:** P0 — Feature appears functional but does nothing

---

## 3. High Severity Bugs

### BUG-05: Audio session ID polling is fragile

**Description:**
`_checkAudioSessionId()` polls `androidAudioSessionId` up to 10 times with 500ms delays. This is a workaround for delayed session ID availability. On fast devices, it wastes up to 5s. On slow devices, it may fail entirely.

**Steps to Reproduce:**
1. Play a song on a slow device
2. EQ may not initialize if session ID takes >5s to become available
3. Or on fast device, EQ init is delayed by unnecessary polling

**Expected Behavior:**
Session ID obtained as soon as available, without arbitrary timeout.

**Actual Behavior:**
Fixed polling loop: either succeeds early with wasted cycles or fails after 5s.

**Probable Root Cause:**
`audio_handler.dart:74-91` — polling loop instead of listening to `androidAudioSessionId` stream.

**Files Affected:**
- `lib/services/audio_handler.dart:66-91` — processingStateStream listener + polling

**Suggested Fix Direction:**
Listen to `_player.androidAudioSessionId` as a stream. When non-null and non-zero, call `onAudioSessionId`. Remove polling loop entirely.

**Priority:** P1 — Affects EQ reliability

---

### BUG-06: errorStream not consumed by UI

**Description:**
`AuraAudioHandler` has an `errorStream` that emits `AudioError` objects when playback fails. No UI component listens to this stream. Errors are silently handled by auto-skipping to next track.

**Steps to Reproduce:**
1. Have a corrupted or missing audio file in library
2. Try to play it
3. App silently skips to next track
4. No indication to user that anything went wrong

**Expected Behavior:**
User sees non-intrusive notification that a file failed to play.

**Actual Behavior:**
Silent skip. User may not notice a song was skipped.

**Probable Root Cause:**
`audio_handler.dart:29` — errorStream exists. `audio_handler.dart:200-208` — errors caught and auto-skip. No code subscribes to errorStream.

**Files Affected:**
- `lib/services/audio_handler.dart:29, 200-208` — error stream + silent handling
- `lib/main.dart` — no errorStream subscription
- `lib/features/player/player_screen.dart` — no error display

**Suggested Fix Direction:**
Subscribe to errorStream in `PlayerController` or `main.dart`. Show `SnackBar` or banner on error. Include recoverable flag in display logic.

**Priority:** P1 — User confusion on playback failures

---

### BUG-07: Seek bar fires continuously during drag

**Description:**
PlayerScreen seek bar uses `Slider(onChanged:)` which fires on every pixel of drag. Each fire calls `ctrl.seek()`, sending seek commands to the audio player dozens of times per second.

**Steps to Reproduce:**
1. Play a song
2. Drag the seek bar from start to end
3. Observe audio stuttering or lag during drag

**Expected Behavior:**
Seek only fires when user releases the slider thumb.

**Actual Behavior:**
Seek fires continuously during drag, causing audio stutter.

**Probable Root Cause:**
`player_screen.dart:128-131` — `Slider(onChanged: (v) => ctrl.seek(...))` seeks on every change event.

**Files Affected:**
- `lib/features/player/player_screen.dart:128-131` — Slider onChanged seeks

**Suggested Fix Direction:**
Use `onChangeStart` to track drag start, `onChangeEnd` to seek on release. During drag, only update UI position visually.

**Priority:** P1 — Audio quality degradation

---

### BUG-08: PlayerController._isPlaying can diverge

**Description:**
`PlayerController` maintains its own `_isPlaying` boolean, set by listening to `AudioHandler.playingStream`. If the stream emits a value and `notifyListeners()` is called before `_isPlaying` is updated, or if the stream misses an event, the controller's state diverges from the actual player state.

**Steps to Reproduce:**
1. Play a song
2. Rapidly toggle play/pause
3. UI may show wrong state momentarily

**Expected Behavior:**
UI play/pause state always matches actual audio state.

**Actual Behavior:**
Brief state mismatch possible during rapid toggling.

**Probable Root Cause:**
`player_controller.dart:16` — `_isPlaying` is separate state. `player_controller.dart:52-58` — listener updates it asynchronously.

**Files Affected:**
- `lib/features/player/player_controller.dart:16, 52-58, 69` — duplicate isPlaying state

**Suggested Fix Direction:**
Remove `_isPlaying`. Expose `isPlaying` as a getter to `AudioHandler.player.playing` or listen to playingStream and expose as a `ValueNotifier`. Better: expose the stream directly and let UI use `StreamBuilder`.

**Priority:** P1 — State inconsistency

---

### BUG-09: Shuffle doesn't reorder visible queue

**Description:**
`setShuffleEnabled(true)` enables just_audio's internal shuffle mode, which shuffles playback order internally. However, the visible queue (`AuraAudioHandler.songQueue`) remains in original order. User sees songs in original order but they play in shuffled order.

**Steps to Reproduce:**
1. Play a queue of songs
2. Enable shuffle
3. Open queue view
4. Queue shows original order but songs play in different order

**Expected Behavior:**
Queue display reflects actual playback order when shuffle is enabled.

**Actual Behavior:**
Queue display shows original order. Playback order is shuffled internally by just_audio.

**Probable Root Cause:**
`audio_handler.dart:131-134` — `setShuffleMode` only calls `just_audio.setShuffleModeEnabled()`. Does not reorder `_queue` array.

**Files Affected:**
- `lib/services/audio_handler.dart:131-136` — shuffle mode setting
- `lib/features/player/player_screen.dart:314-343` — queue display shows `_queue` directly

**Suggested Fix Direction:**
Maintain both original and shuffled queue indices. When shuffle enabled, create shuffled index mapping. Display queue using shuffled order. When shuffle disabled, restore original order.

**Priority:** P1 — Confusing user experience

---

### BUG-10: Queue restore may load invalid URIs

**Description:**
`StatePersistenceService` saves queue as JSON with song URIs. On restore, it deserializes and calls `restoreQueue()`. If any file was deleted or moved since saving, the URI is invalid but no validation occurs.

**Steps to Reproduce:**
1. Play songs, close app (queue saved)
2. Delete one of the played audio files from device
3. Reopen app
4. App tries to play deleted file, fails silently

**Expected Behavior:**
Invalid entries skipped during restore. User notified of missing files.

**Actual Behavior:**
App attempts to play invalid URI. Playback fails. No user feedback.

**Probable Root Cause:**
`state_persistence_service.dart:58-75` — restores queue without validating URIs. `audio_handler.dart:196-209` — catches error and auto-skips, but no notification.

**Files Affected:**
- `lib/services/state_persistence_service.dart:58-75` — restore without validation
- `lib/services/audio_handler.dart:196-209` — silent error handling

**Suggested Fix Direction:**
Validate URI existence before restoring. Use `File(uri).existsSync()` for file:// URIs. Skip invalid entries. Show summary of skipped files.

**Priority:** P1 — Playback failure on restore

---

## 4. Medium Severity Bugs

### BUG-11: StatsRepository factory vs singleton conflict

**Description:**
`StatsRepository` has both a factory constructor `StatsRepository()` and a singleton `StatsRepository.instance`. The factory creates a new instance each time, while `instance` returns the singleton. `main.dart` uses `StatsRepository.instance` but the factory constructor is accessible.

**Steps to Reproduce:**
1. Call `StatsRepository()` (factory) — creates new instance
2. Call `StatsRepository.instance` — returns singleton
3. Two different instances with separate state

**Expected Behavior:**
Only one way to access StatsRepository (singleton).

**Actual Behavior:**
Two constructors create confusion. Accidentally using factory creates orphaned instance.

**Probable Root Cause:**
`stats_repository.dart:6-9` — both factory and singleton defined.

**Files Affected:**
- `lib/data/repositories/stats_repository.dart:6-9`

**Suggested Fix Direction:**
Remove factory constructor. Keep only singleton pattern. Make constructor private.

**Priority:** P2 — Confusing API, potential for bugs

---

### BUG-12: play_events table grows unbounded

**Description:**
Every song play creates a row in `play_events`. `clearOldEvents(keepDays: 30)` exists but is never called. Table grows indefinitely.

**Steps to Reproduce:**
1. Use app daily for months
2. Check database size
3. `play_events` table has thousands of rows

**Expected Behavior:**
Old events cleaned up automatically.

**Actual Behavior:**
Table grows without limit. Database file size increases over time.

**Probable Root Cause:**
`stats_repository.dart:94-98` — `clearOldEvents()` exists but never called.

**Files Affected:**
- `lib/data/repositories/stats_repository.dart:94-98`

**Suggested Fix Direction:**
Call `clearOldEvents()` periodically (on app start, or after each play event if table exceeds threshold).

**Priority:** P2 — Long-term performance degradation

---

### BUG-13: Playlist songs denormalized and stale

**Description:**
`playlist_songs` table stores `song_title`, `song_artist`, `song_uri`, `song_duration`, `album_id` directly. If the source file is moved or metadata changes, playlist data becomes stale.

**Steps to Reproduce:**
1. Add song to playlist
2. Rename the audio file on device
3. Open playlist
4. Song shows old title/artist or fails to play

**Expected Behavior:**
Playlist resolves current metadata from device at display time.

**Actual Behavior:**
Playlist shows stale metadata stored at add time.

**Probable Root Cause:**
`playlist_repository.dart:53-64` — `addSong` stores denormalized fields. `_getSongs` reads them directly.

**Files Affected:**
- `lib/data/repositories/playlist_repository.dart:24-36, 53-64`
- `lib/data/database/app_database.dart:23-32` — schema with denormalized columns

**Suggested Fix Direction:**
Store only `song_id` and `position` in `playlist_songs`. Resolve full Song from MediaScanner when reading. Handle missing songs gracefully.

**Priority:** P2 — Data staleness

---

### BUG-14: Palette extraction blocks main thread

**Description:**
`DynamicThemeService._extractPalette()` runs `ui.instantiateImageCodec()` and `PaletteGenerator.fromImage()` on the main thread. These are CPU-intensive operations that can cause frame drops.

**Steps to Reproduce:**
1. Play song with high-resolution album art
2. Observe frame rate during color extraction
3. Jank/stutter visible

**Expected Behavior:**
Color extraction runs off main thread. No visible jank.

**Actual Behavior:**
Frame drops during extraction. UI stutters for 100-500ms.

**Probable Root Cause:**
`dynamic_theme_service.dart:38-55` — all operations on main thread.

**Files Affected:**
- `lib/services/dynamic_theme_service.dart:38-55`

**Suggested Fix Direction:**
Use `compute()` to run palette extraction in isolate. Pass bytes to isolate, return extracted colors.

**Priority:** P2 — Visible jank

---

### BUG-15: MediaScanner.getSongById scans all songs

**Description:**
`getSongById(songId)` queries ALL songs from device, then filters by ID. O(n) operation for a single song lookup.

**Steps to Reproduce:**
1. Have library with 2000+ songs
2. RecommendationEngine calls `statsToSongs()` which calls `getSongById()` for each stat
3. 30 stats × O(2000) = 60,000 comparisons

**Expected Behavior:**
Single song lookup is O(1) or O(log n).

**Actual Behavior:**
O(n) full scan for each lookup. Recommendation loading is very slow for large libraries.

**Probable Root Cause:**
`media_scanner.dart:68-76` — `querySongs()` returns all songs, then `where((s) => s.id == songId)` filters.

**Files Affected:**
- `lib/services/media_scanner.dart:68-76`
- `lib/features/discover/recommendation_engine.dart:48-55` — calls getSongById in loop

**Suggested Fix Direction:**
Cache all songs in memory after initial scan. Use Map<int, Song> for O(1) lookup. Or use on_audio_query's query with filter if supported.

**Priority:** P2 — Slow recommendations for large libraries

---

### BUG-16: EQ preset name not persisted correctly

**Description:**
When `applyPreset(name)` is called, it sets `presetName` in the in-memory config and applies band gains. But `presetName` is only saved if `saveForSong` is called, which happens through `_eqRepository.saveForSong(_currentConfig!)`. The preset IS saved, but if the user then manually adjusts a band, the `presetName` is set to `null` (custom), yet the old preset name may still be displayed.

**Steps to Reproduce:**
1. Apply "Rock" preset
2. Manually adjust one band
3. presetName becomes null in memory
4. UI may still show "Rock" if it reads from stale state

**Expected Behavior:**
Preset name clears when user makes custom adjustments.

**Actual Behavior:**
presetName handling is inconsistent between in-memory config and saved state.

**Probable Root Cause:**
`equalizer_service.dart:75` — `setBandGain` sets `presetName: null`. `equalizer_service.dart:88` — saves to repo. But `_currentConfig` in `EqRepository` may be stale.

**Files Affected:**
- `lib/services/equalizer_service.dart:75, 88`
- `lib/data/repositories/eq_repository.dart:7` — `_currentConfig` tracks last loaded, not last saved

**Suggested Fix Direction:**
Ensure EqRepository._currentConfig is updated on every save. Or remove _currentConfig from repository and use EqualizerService as single source of truth.

**Priority:** P2 — UI state inconsistency

---

### BUG-17: Song.isFavorite field always false

**Description:**
`Song` model has an `isFavorite` field (default `false`). `FavoritesRepository` maintains a `Set<int>` of favorite IDs. But no code ever populates `Song.isFavorite` from the repository. The field is always `false`.

**Steps to Reproduce:**
1. Add song to favorites
2. Access `song.isFavorite` anywhere
3. Always returns `false`

**Expected Behavior:**
`song.isFavorite` reflects actual favorite status.

**Actual Behavior:**
Always `false`. Favorite status must be checked via `FavoritesRepository.isFavorite(songId)`.

**Probable Root Cause:**
`song.dart:29` — `isFavorite` defaults to `false`. `song.dart:54-67` — `fromJson` doesn't set it. No code bridges `FavoritesRepository` to `Song` objects.

**Files Affected:**
- `lib/data/models/song.dart:14, 29, 54-67`
- `lib/data/repositories/favorites_repository.dart` — separate from Song

**Suggested Fix Direction:**
Don't mutate immutable Song model. Create a `FavoriteStatusResolver` or computed layer that combines Song + FavoritesRepository. Or use `Consumer<FavoritesRepository>` in UI to check status.

**Priority:** P2 — Misleading API

---

### BUG-18: No database migration strategy

**Description:**
Database version is always `1`. `onUpgrade` re-runs `CREATE TABLE IF NOT EXISTS`. Adding any new column or changing any type requires manual intervention or database wipe.

**Steps to Reproduce:**
1. Release app with current schema
2. Add new column to a table in next version
3. Users upgrading get crash or silent failure

**Expected Behavior:**
Schema evolves via ALTER TABLE migrations.

**Actual Behavior:**
No migration path. Schema changes require wiping database.

**Probable Root Cause:**
`app_database.dart:64` — `version: 1`. `app_database.dart:70-77` — onUpgrade only runs CREATE IF NOT EXISTS.

**Files Affected:**
- `lib/data/database/app_database.dart:64, 70-77`

**Suggested Fix Direction:**
Implement versioned migrations. Increment version with each schema change. Add ALTER TABLE statements in onUpgrade for each version step.

**Priority:** P2 — Blocks future schema evolution

---

## 5. Low Severity Bugs

### BUG-19: PlayerScreen redundant Song parameter

**Description:**
`PlayerScreen` constructor requires `Song song` parameter but the screen reads from `PlayerController.currentSong` for all data. The parameter is only used as fallback in `_showSongInfo`.

**Files Affected:** `player_screen.dart:13, 289`
**Fix:** Remove Song parameter. Read exclusively from controller.
**Priority:** P3

### BUG-20: MiniPlayer Dismissible skips tracks

**Description:**
MiniPlayer uses `Dismissible` with horizontal swipe to skip tracks. Dismissible pattern is conventionally used to remove/close items, not navigate. Users may accidentally skip songs.

**Files Affected:** `mini_player.dart:19-29`
**Fix:** Replace Dismissible with GestureDetector for horizontal swipe. Reserve Dismissible for remove actions.
**Priority:** P3

### BUG-21: Defensive CREATE TABLE in onOpen

**Description:**
`onOpen` callback re-runs all CREATE TABLE statements on every database open. Unnecessary overhead after tables already exist.

**Files Affected:** `app_database.dart:78-84`
**Fix:** Remove onOpen defensive CREATE. Rely on proper onCreate/onUpgrade.
**Priority:** P3

### BUG-22: No foreign key enforcement

**Description:**
SQLite foreign keys are not enabled. `playlist_songs` can reference deleted playlists. `play_events` can reference deleted songs.

**Files Affected:** `app_database.dart`
**Fix:** Add `await db.execute('PRAGMA foreign_keys = ON')` in onOpen. Add FOREIGN KEY constraints to schema.
**Priority:** P3

### BUG-23: Light theme screens hardcoded dark colors

**Description:**
Many screens use `AuraColors.background`, `AuraColors.text` directly (dark palette). When light theme is active, these screens still show dark colors. Only `SettingsScreen` and `_Shell` properly switch between light/dark palettes.

**Files Affected:** `library_screen.dart`, `albums_screen.dart`, `artists_screen.dart`, `playlists_screen.dart`, `for_you_screen.dart`
**Fix:** Create theme-aware color accessor or use `Theme.of(context).colorScheme` instead of direct AuraColors.
**Priority:** P3

### BUG-24: No empty state for albums/artists

**Description:**
When device has no albums or artists, screens show blank content instead of helpful empty state messages.

**Files Affected:** `albums_screen.dart`, `artists_screen.dart`
**Fix:** Add empty state widgets with icon, message, and refresh button.
**Priority:** P3

### BUG-25: ForYouScreen not accessible from nav

**Description:**
`ForYouScreen` exists with full implementation but is not a tab destination. Only accessible via `RecommendationSection` widget embedded in LibraryScreen.

**Files Affected:** `for_you_screen.dart`, `app.dart`
**Fix:** Add as dedicated tab or integrate into home/discover section.
**Priority:** P3

### BUG-26: Global mutable variables in main.dart

**Description:**
`late AuraAudioHandler audioHandler` and `late EqualizerService equalizerService` are top-level mutable globals. Not injectable, not testable.

**Files Affected:** `main.dart:21-22`
**Fix:** Move into DI tree. Access via Provider.of or context.read.
**Priority:** P3

### BUG-27: Settings typo "sueno"

**Description:**
"Temporizador de sueno" should be "Temporizador de sueño" (missing ñ).

**Files Affected:** `settings_screen.dart:72, 149`
**Fix:** Correct spelling.
**Priority:** P4

### BUG-28: Settings typo "Reproduccion"

**Description:**
"Reproduccion" should be "Reproducción" (missing accent).

**Files Affected:** `settings_screen.dart:30`
**Fix:** Correct spelling.
**Priority:** P4

---

## 6. Architecture Bugs

| ID | Bug | Severity | Description |
|---|---|---|---|
| BUG-01 | Dynamic theme not reactive | Critical | Singleton not ChangeNotifier |
| BUG-03 | Favorites race condition | Critical | Load before providers ready |
| BUG-05 | Session ID polling | High | Fragile timing-dependent approach |
| BUG-08 | State duplication | High | PlayerController duplicates handler state |
| BUG-11 | StatsRepository dual constructors | Medium | Factory + singleton conflict |
| BUG-18 | No DB migrations | Medium | Cannot evolve schema |
| BUG-26 | Global mutable variables | Low | late globals in main.dart |

---

## 7. UX Bugs

| ID | Bug | Severity | Description |
|---|---|---|---|
| BUG-04 | EQ silent failure | Critical | No feedback on unsupported devices |
| BUG-06 | No error feedback | High | Playback errors invisible to user |
| BUG-09 | Shuffle queue mismatch | High | Display doesn't match playback order |
| BUG-10 | Invalid URI on restore | High | No feedback on missing files |
| BUG-17 | isFavorite always false | Medium | Misleading API surface |
| BUG-20 | Dismissible skips tracks | Low | Unintuitive gesture mapping |
| BUG-23 | Light theme broken | Low | Screens hardcoded dark colors |
| BUG-24 | No empty states | Low | Blank screens on empty data |
| BUG-27 | Typo "sueno" | Low | Missing ñ |
| BUG-28 | Typo "Reproduccion" | Low | Missing accent |

---

## 8. Performance Bugs

| ID | Bug | Severity | Description |
|---|---|---|---|
| BUG-07 | Seek bar continuous fire | High | Dozens of seek calls per drag |
| BUG-14 | Palette on main thread | Medium | Codec + palette blocks UI |
| BUG-15 | getSongById O(n) | Medium | Full scan for single lookup |
| BUG-21 | Defensive CREATE in onOpen | Low | Unnecessary SQL on every launch |

---

## 9. Persistence Bugs

| ID | Bug | Severity | Description |
|---|---|---|---|
| BUG-02 | Playlists not loaded | Critical | loadPlaylists() never called |
| BUG-10 | Invalid URI restore | High | No validation on queue restore |
| BUG-12 | Unbounded play_events | Medium | Table grows indefinitely |
| BUG-13 | Denormalized playlist data | Medium | Stale metadata in playlists |
| BUG-16 | EQ preset name inconsistency | Medium | UI may show wrong preset |
| BUG-18 | No DB migrations | Medium | Schema cannot evolve |
| BUG-22 | No FK enforcement | Low | Orphaned records possible |

---

## Severity Distribution

| Severity | Count | Percentage |
|---|---|---|
| Critical | 4 | 14% |
| High | 6 | 21% |
| Medium | 8 | 29% |
| Low | 10 | 36% |
| **Total** | **28** | **100%** |

## Fix Priority Order (Recommended)

1. **BUG-01** — Dynamic theme reactive (enables Phase 2)
2. **BUG-02** — Playlists auto-load (core feature)
3. **BUG-03** — Favorites race condition (core feature)
4. **BUG-04** — EQ capability detection (core feature)
5. **BUG-05** — Session ID stream listener (audio reliability)
6. **BUG-06** — Error feedback (user experience)
7. **BUG-07** — Seek bar debounce (audio quality)
8. **BUG-08** — State duplication elimination (architecture)
9. **BUG-09** — Shuffle queue reorder (user experience)
10. **BUG-10** — URI validation on restore (reliability)
11. **BUG-14** — Palette in isolate (performance)
12. **BUG-15** — Song cache for O(1) lookup (performance)
13. Remaining medium/low bugs per capacity

---

> **Note:** All bugs identified from static code analysis. Runtime testing may reveal additional issues. Update this document as bugs are fixed or new ones are discovered.
