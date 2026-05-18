# AURA Music — Feature Matrix

> **Date:** 2026-05-17
> **Source:** Static analysis of actual project code
> **Method:** Each feature verified against existing code in `lib/`

---

## Table of Contents

1. [Feature Status Table](#1-feature-status-table)
2. [Feature Details](#2-feature-details)
3. [Feature Dependencies](#3-feature-dependencies)
4. [Hidden / Unused Features](#4-hidden--unused-features)
5. [Dead Code](#5-dead-code)
6. [Stabilization Priority](#6-stabilization-priority)

---

## 1. Feature Status Table

| Feature | Exists | Functional | Partial | Broken | Placeholder | Notes |
|---|---|---|---|---|---|---|
| **Audio Playback** | Yes | Yes | — | — | No | just_audio + audio_service. Plays local files. |
| **Background Playback** | Yes | Yes | — | — | No | audio_service notification. Controls work. |
| **System Notification** | Yes | Yes | — | — | No | Play/pause/prev/next. MediaItem sync. |
| **Queue Management** | Yes | Yes | — | — | No | Add, remove, play next, restore. Shuffle display broken (BUG-09). |
| **Play/Pause** | Yes | Yes | — | — | No | Working via AudioHandler. |
| **Skip Next/Previous** | Yes | Yes | — | — | No | Working. Previous seeks to 0 if >3s. |
| **Seek** | Yes | Yes | — | — | No | Working but fires continuously during drag (BUG-07). |
| **Repeat Mode** | Yes | Yes | — | — | No | off → all → one cycle. Works. |
| **Shuffle** | Yes | Partial | Yes | — | No | Playback shuffles but queue display doesn't (BUG-09). |
| **Playback Speed** | Yes | Yes | — | — | No | 0.5x–2.0x. Settings picker works. Persists. |
| **Mini Player** | Yes | Yes | — | — | No | Glassmorphism, progress, controls. Dismissible skip (BUG-20). |
| **Full Player Screen** | Yes | Yes | — | — | No | Artwork, controls, queue sheet, EQ nav. Redundant Song param (BUG-19). |
| **Library Scan** | Yes | Yes | — | — | No | on_audio_query. Filters <30s. Permission handling. |
| **Library Search** | Yes | Yes | — | — | No | Filters by title/artist/album. Real-time. Only in LibraryScreen. |
| **Albums Grid** | Yes | Yes | — | — | No | 2-column grid with artwork. |
| **Album Detail** | Yes | Yes | — | — | No | SliverAppBar + song list + play/shuffle. |
| **Artists List** | Yes | Yes | — | — | No | List with song count. Detail screen inline. |
| **Artist Detail** | Yes | Yes | — | — | No | Songs + albums by artist. |
| **Playlist CRUD** | Yes | Partial | Yes | — | No | Create/delete works. Edit name missing. |
| **Playlist Detail** | Yes | Yes | — | — | No | Shows songs. Play/shuffle. No reorder. |
| **Add to Playlist** | Yes | Yes | — | — | No | Bottom sheet from song tile. Creates new or adds to existing. |
| **Favorites** | Yes | Partial | Yes | — | No | Toggle works. But isFavorite field always false (BUG-17). |
| **Equalizer** | Yes | Partial | Yes | — | No | 12-band + bass + virtualizer + presets. No capability detection (BUG-04). |
| **EQ Presets** | Yes | Yes | — | — | No | 8 presets: Plano, Rock, Pop, Jazz, Clásica, Hip-Hop, Electrónica, Latino. |
| **Per-Song EQ** | Yes | Yes | — | — | No | Config saved/loaded per song. |
| **Dynamic Theme** | Yes | Broken | — | Yes | No | Extracts colors but UI doesn't update (BUG-01). |
| **Light Theme** | Yes | Partial | Yes | — | No | ThemeData exists. Most screens hardcoded dark (BUG-23). |
| **Sleep Timer** | Yes | Yes | — | — | No | Timer + countdown + pause on expiry. Settings picker works. |
| **Settings Screen** | Yes | Yes | — | — | No | Speed, sleep timer, theme toggle, dynamic theme toggle. Typos (BUG-27, 28). |
| **Queue Persistence** | Yes | Partial | Yes | — | No | Saves to SharedPreferences. Restore may load invalid URIs (BUG-10). |
| **Settings Persistence** | Yes | Yes | — | — | No | SharedPreferences. Speed, theme, dynamic theme persist. |
| **Play Statistics** | Yes | Partial | Yes | — | No | Tracks plays/skips/listened. No UI to display stats. |
| **Recommendations** | Yes | Partial | Yes | — | No | Scoring algorithm works. ForYouScreen not in nav (BUG-25). Slow for large libs (BUG-15). |
| **Media Permissions** | Yes | Yes | — | — | No | READ_MEDIA_AUDIO (Android 13+) + READ_EXTERNAL_STORAGE fallback. |
| **Hardware Controls** | Yes | Yes | — | — | No | Media buttons via audio_service. |
| **Lock Screen Controls** | Yes | Yes | — | — | No | Via audio_service MediaItem. |
| **Gestures** | Partial | Partial | Yes | — | No | MiniPlayer swipe skip. Song tile swipe to playlist. No player gestures. |
| **Animations** | Partial | Partial | Yes | — | No | Album art scale on play/pause. Slide transition to player. No ambient animations. |
| **Audio Focus** | Yes | Yes | — | — | No | Handled by audio_service + just_audio automatically. |
| **Error Handling** | Partial | Partial | Yes | — | No | Errors caught in handler but not shown to UI (BUG-06). |
| **Empty States** | Partial | Partial | Yes | — | No | Library has empty state. Playlists/albums/artists don't (BUG-24). |
| **Loading States** | Partial | Partial | Yes | — | No | Library shows loading. Other screens inconsistent. |
| **Lyrics** | No | — | — | — | No | Not implemented. |
| **Crossfade** | No | — | — | — | No | Not implemented. |
| **Gapless Playback** | No | — | — | — | No | Not explicitly configured. just_audio may support. |
| **Visualizer** | No | — | — | — | No | Not implemented. |
| **Global Search** | No | — | — | — | No | Search only in LibraryScreen. |
| **Smart Shuffle** | No | — | — | — | No | Standard shuffle only. |
| **Queue Reorder** | No | — | — | — | No | Queue view is read-only. |
| **Playlist Reorder** | No | — | — | — | No | No drag-and-drop in playlists. |
| **Playlist Export** | No | — | — | — | No | No M3U/JSON export. |
| **Folder Browsing** | No | — | — | — | No | Not implemented. |
| **Onboarding** | No | — | — | — | No | Not implemented. |
| **Widgets** | No | — | — | — | No | No home screen widgets. |
| **Chromecast** | No | — | — | — | No | Not implemented. |
| **Tag Editor** | No | — | — | — | No | Not implemented. |
| **Ringtone Cutter** | No | — | — | — | No | Not implemented. |

---

## 2. Feature Details

### Audio Playback

| Aspect | Status | Details |
|---|---|---|
| Engine | just_audio ^0.9.36 | Full-featured audio player |
| Format support | MP3, FLAC, OGG, WAV, AAC | Via just_audio's native decoders |
| Local files | Yes | file:// URIs from on_audio_query |
| Streaming | No | Not designed for streaming |
| Background | Yes | audio_service with persistent notification |
| Audio focus | Yes | Automatic via audio_service |

### Queue System

| Operation | Status | Notes |
|---|---|---|
| Play song with queue | Functional | `playSong(song, queue, index)` |
| Add to end | Functional | `addToQueue(song)` |
| Play next | Functional | `playNext(song)` — inserts at currentIndex+1 |
| Remove from queue | Functional | `removeFromQueue(index)` — skips if current |
| Restore from persistence | Partial | Works but no URI validation (BUG-10) |
| Reorder | Missing | No drag-and-drop |
| Clear queue | Missing | No clear all function |
| Save as playlist | Missing | No export function |
| Shuffle display | Broken | Display doesn't reflect shuffled order (BUG-09) |
| History (back) | Missing | No recently played in queue view |

### Equalizer

| Aspect | Status | Details |
|---|---|---|
| Bands | 12 | 31Hz to 20kHz |
| Bass Boost | Yes | 0–15 dB range |
| Virtualizer | Yes | 0–1 strength |
| Presets | 8 | Plano, Rock, Pop, Jazz, Clásica, Hip-Hop, Electrónica, Latino |
| Per-song config | Yes | Saved in SQLite |
| Custom presets | Missing | User cannot save named custom configs |
| Capability detection | Missing | No check for native support (BUG-04) |
| Enable/disable toggle | Functional | Works via MethodChannel |
| UI | Functional | EqualizerScreen with sliders + preset picker |
| Error recovery | Missing | Silent failure on channel errors |

### Playlists

| Aspect | Status | Details |
|---|---|---|
| Create | Functional | Name input via dialog |
| Delete | Functional | With confirmation |
| Edit name | Missing | No rename function |
| Add songs | Functional | Bottom sheet from song tile |
| Remove songs | Functional | Via repository |
| Reorder songs | Missing | No drag-and-drop |
| Play all | Functional | Plays from first song |
| Shuffle | Functional | Shuffles playlist songs |
| Cover art | Missing | No playlist cover (uses first song's art implicitly) |
| Export/import | Missing | No M3U/JSON support |
| Auto-load on start | Broken | loadPlaylists() never called (BUG-02) |

### Favorites

| Aspect | Status | Details |
|---|---|---|
| Toggle favorite | Functional | toggleFavorite(songId) in repository |
| Add favorite | Functional | addFavorite(songId) |
| Remove favorite | Functional | removeFavorite(songId) |
| isFavorite check | Functional | isFavorite(songId) via Set lookup |
| Song.isFavorite field | Broken | Always false (BUG-17) |
| Favorites list/screen | Missing | No dedicated favorites screen |
| Persistence | Functional | SQLite favorites table |
| Auto-load on start | Broken | Race condition (BUG-03) |

### Search

| Aspect | Status | Details |
|---|---|---|
| Search songs | Functional | Filters by title/artist/album |
| Search albums | Missing | No album search |
| Search artists | Missing | No artist search |
| Search playlists | Missing | No playlist search |
| Recent searches | Missing | No history |
| Suggestions | Missing | No autocomplete |
| Global search | Missing | Only in LibraryScreen |

### Themes

| Aspect | Status | Details |
|---|---|---|
| Dark theme | Functional | Full dark palette in AuraColors |
| Light theme | Partial | ThemeData exists, screens hardcoded dark (BUG-23) |
| System theme | Functional | ThemeMode.system supported |
| Theme toggle | Functional | Settings switch works |
| Dynamic theme | Broken | Extracts colors but UI doesn't update (BUG-01) |
| Dynamic theme toggle | Functional | Settings switch works |
| Theme persistence | Functional | SharedPreferences |
| Artwork color extraction | Functional | PaletteGenerator from album art |
| Fallback colors | Functional | Default purple/cyan when no art |

### Statistics & Recommendations

| Aspect | Status | Details |
|---|---|---|
| Play tracking | Functional | StatsTracker records on song change |
| Skip tracking | Functional | was_skipped flag in play_events |
| Play count | Functional | Aggregated in song_stats |
| Skip count | Functional | Aggregated in song_stats |
| Total listened | Functional | Accumulated seconds |
| Completion rate | Functional | Computed from listened/duration |
| Skip rate | Functional | Computed from skip/(play+skip) |
| Scoring algorithm | Functional | playCount×3 + completion×5 + favorite×10 - skipRate×4 + recency |
| Top picks | Functional | Top 30 by score |
| Most played | Functional | Top 10 by play count |
| Recommendations UI | Partial | ForYouScreen exists but not in nav (BUG-25) |
| Embedded recommendations | Functional | RecommendationSection in LibraryScreen |
| Stats display UI | Missing | No screen to view personal stats |
| Smart shuffle | Missing | Standard shuffle only |
| Artist variety filter | Missing | No prevention of repeat artist |

---

## 3. Feature Dependencies

### Dependency Graph

```
Audio Playback (core)
  ├── Background Playback [depends on: Audio Playback]
  ├── System Notification [depends on: Background Playback]
  ├── Hardware Controls [depends on: Background Playback]
  ├── Lock Screen Controls [depends on: System Notification]
  ├── Queue Management [depends on: Audio Playback]
  │   ├── Queue Persistence [depends on: Queue Management]
  │   └── Queue Reorder [depends on: Queue Management]
  ├── Play/Pause [depends on: Audio Playback]
  ├── Skip Next/Previous [depends on: Queue Management]
  ├── Seek [depends on: Audio Playback]
  ├── Repeat Mode [depends on: Audio Playback]
  ├── Shuffle [depends on: Queue Management]
  ├── Playback Speed [depends on: Audio Playback]
  └── Audio Focus [depends on: Audio Playback]

Library Scan [depends on: Permissions]
  ├── Library Search [depends on: Library Scan]
  ├── Albums Grid [depends on: Library Scan]
  │   └── Album Detail [depends on: Albums Grid]
  ├── Artists List [depends on: Library Scan]
  │   └── Artist Detail [depends on: Artists List]
  └── Global Search [depends on: Library Scan, Albums, Artists, Playlists]

Playlists [depends on: Database]
  ├── Playlist CRUD [depends on: Playlists]
  ├── Playlist Detail [depends on: Playlist CRUD]
  ├── Add to Playlist [depends on: Playlists, Library Scan]
  ├── Playlist Reorder [depends on: Playlist Detail]
  └── Playlist Export [depends on: Playlist Detail]

Favorites [depends on: Database]
  ├── Toggle Favorite [depends on: Favorites]
  └── Favorites Screen [depends on: Favorites]

Equalizer [depends on: Audio Playback, Native Android]
  ├── EQ Presets [depends on: Equalizer]
  ├── Per-Song EQ [depends on: Equalizer, Database]
  └── Capability Detection [depends on: Equalizer]

Statistics [depends on: Audio Playback]
  ├── Play Tracking [depends on: Statistics]
  ├── Scoring Algorithm [depends on: Statistics]
  ├── Recommendations [depends on: Scoring Algorithm]
  │   └── ForYouScreen [depends on: Recommendations]
  └── Stats Display UI [depends on: Statistics]

Dynamic Theme [depends on: Library Scan, Audio Playback]
  ├── Color Extraction [depends on: Dynamic Theme]
  └── Reactive UI [depends on: Color Extraction]

Mini Player [depends on: Audio Playback, Queue Management]
Full Player [depends on: Audio Playback, Queue Management, Equalizer, Dynamic Theme]
Settings [depends on: Audio Playback, Dynamic Theme]
Sleep Timer [depends on: Audio Playback, Settings]

Gestures [depends on: Mini Player, Full Player, Library]
Animations [depends on: Full Player, Mini Player, Navigation]
Lyrics [depends on: Audio Playback]
Crossfade [depends on: Audio Playback]
Gapless Playback [depends on: Audio Playback]
Visualizer [depends on: Audio Playback]
```

### Stabilization Order (What must be fixed first)

| Order | Feature | Reason |
|---|---|---|
| 1 | Audio Playback | Foundation for everything |
| 2 | Queue Management | Required for shuffle, persistence, mini player |
| 3 | Library Scan | Required for all content display |
| 4 | Favorites | Core user feature, race condition blocks it |
| 5 | Playlists | Core user feature, auto-load broken |
| 6 | Dynamic Theme | Required for Phase 2 design system |
| 7 | Equalizer | Capability detection needed for reliability |
| 8 | Statistics | Foundation for recommendations |
| 9 | Recommendations | Depends on statistics being reliable |
| 10 | Settings | Sleep timer + speed already work, needs polish |
| 11 | Search | Works in library, needs global expansion |
| 12 | Gestures/Animations | Polish layer, depends on stable core |

---

## 4. Hidden / Unused Features

### Features That Exist But Are Not Accessible

| Feature | Location | Why Hidden | Impact |
|---|---|---|---|
| **ForYouScreen** | `lib/features/home/for_you_screen.dart` | Not a tab destination. Only accessible via embedded widget. | Recommendations exist but users can't browse them directly. |
| **RecommendationSection** | `lib/features/home/widgets/recommendation_section.dart` | Embedded in LibraryScreen. May not be visible if library is small. | Users with few plays see no recommendations. |
| **smart_recommendations/** | `lib/features/smart_recommendations/api/` + `models/` | External AI integration. No code connects it to the app. | Dead code. No API calls made. |
| **Artist Detail** | `lib/features/artists/artists_screen.dart` (inline) | Exists but navigation to it may not be connected from all entry points. | Artists screen works but detail may not be reachable from library. |
| **Album Detail** | `lib/features/albums/album_detail_screen.dart` | Exists and is reachable from albums grid. Not reachable from library song tiles. | Users can't go to album detail from a song in library. |
| **SongTile widget** | `lib/widgets/song_tile.dart` | Reusable widget exists but LibraryScreen uses its own `_SongTile` inline. | Code duplication — two song tile implementations. |
| **AddToPlaylistSheet** | `lib/widgets/add_to_playlist_sheet.dart` | Used from LibraryScreen Slidable. Not available from PlayerScreen or queue. | Add to playlist only works from library, not from player. |
| **EqRepository.getAllConfigs()** | `lib/data/repositories/eq_repository.dart:63-67` | Method exists but never called. | No way to view all saved EQ configs. |
| **EqRepository.clearUnusedConfigs()** | `lib/data/repositories/eq_repository.dart:69-76` | Method exists but never called. | Orphaned EQ configs accumulate. |
| **StatsRepository.clearOldEvents()** | `lib/data/repositories/stats_repository.dart:94-98` | Method exists but never called. | play_events table grows unbounded. |
| **StatsRepository.updateFavoriteStatus()** | `lib/data/repositories/stats_repository.dart:83-92` | Method exists but never called. | song_stats.is_favorite never synced with favorites table. |
| **LibraryController.isEmpty** | `lib/features/library/library_controller.dart:19` | Getter exists but not used in UI. | Empty state uses status check instead. |
| **LibraryController.isLoading** | `lib/features/library/library_controller.dart:20` | Getter exists but not used in UI. | Loading state uses status check instead. |
| **LibraryController.errorMessage** | `lib/features/library/library_controller.dart:21-25` | Getter exists but not used in UI. | Error message hardcoded in screen. |
| **Song.isFavorite** | `lib/data/models/song.dart:14` | Field exists but never populated. | Always false. Misleading API. |
| **SongStats.completionRate** | `lib/data/models/song_stats.dart:56-59` | Computed but not displayed in UI. | Available for scoring but not user-facing. |
| **SongStats.skipRate** | `lib/data/models/song_stats.dart:61-65` | Computed but not displayed in UI. | Available for scoring but not user-facing. |
| **Playlist.totalDuration** | `lib/data/models/playlist.dart:17-20` | Computed but not displayed in playlist screens. | Available but unused. |
| **Playlist.songCount** | `lib/data/models/playlist.dart:15` | Computed but not displayed in playlist list. | Available but unused. |
| **ScanResult.errorMessage** | `lib/services/media_scanner.dart:10` | Field exists but not surfaced to UI. | Error details lost. |

### Code Paths That Are Defined But Not Triggered

| Code Path | Location | Trigger Condition | Status |
|---|---|---|---|
| Auto-skip on audio error | `audio_handler.dart:206-208` | Playback fails | Works but silent |
| Queue restore on init | `player_controller.dart:60-66` | App starts with saved queue | Works but no URI validation |
| Sleep timer pause | `player_controller.dart:37-41` | Timer expires | Works |
| Dynamic theme update | `main.dart:77-79` | Song changes | Extracts colors but UI doesn't update |
| EQ load on song change | `main.dart:76` | Song changes | Works but may race with session init |
| Stats flush on song change | `main.dart:75` | Song changes | Works |
| Recommendation refresh | `main.dart:80-82` | 5s after song change | Works but recEngineRef may be null |
| Error stream emission | `audio_handler.dart:201` | Playback fails | Stream exists but no consumer |

---

## 5. Dead Code

### Unused Imports

Files should be audited with `flutter analyze`. Known suspects:

| File | Suspect Import | Reason |
|---|---|---|
| `player_screen.dart` | `on_audio_query` | Used only for QueryArtworkWidget, but could be replaced |
| Various | `cupertino_icons` | Material Icons used throughout |

### Unused Methods

| Method | Location | Called By |
|---|---|---|
| `EqRepository.getOrCreate()` | `eq_repository.dart:49-52` | Nobody — same as `loadForSong()` |
| `EqRepository.getAllConfigs()` | `eq_repository.dart:63-67` | Nobody |
| `EqRepository.clearUnusedConfigs()` | `eq_repository.dart:69-76` | Nobody |
| `StatsRepository.clearOldEvents()` | `stats_repository.dart:94-98` | Nobody |
| `StatsRepository.updateFavoriteStatus()` | `stats_repository.dart:83-92` | Nobody |
| `PlaylistRepository.loadPlaylists()` at startup | `playlist_repository.dart:13-22` | Not called at startup |
| `DynamicThemeService.reset()` | `dynamic_theme_service.dart:57-60` | Nobody |
| `MediaScanner.albumsByArtist()` | `media_scanner.dart:58-61` | Not called from any screen |
| `MediaScanner.getSongById()` | `media_scanner.dart:68-76` | Only called by RecommendationEngine (slow) |
| `LibraryController.isEmpty` | `library_controller.dart:19` | Nobody — screen uses status directly |
| `LibraryController.isLoading` | `library_controller.dart:20` | Nobody — screen uses status directly |
| `LibraryController.errorMessage` | `library_controller.dart:21-25` | Nobody — screen uses status directly |
| `SongTile` widget | `widgets/song_tile.dart` | Only used in ForYouScreen, not in LibraryScreen |
| `AuraTheme.light()` | `app_theme.dart:51-77` | Used by MaterialApp but screens don't respect it |

### Unused Models

| Model | Location | Used By |
|---|---|---|
| `Artist` model | `data/models/artist.dart` | Only as wrapper. on_audio_query ArtistModel used directly in screens |
| `smart_recommendations/` | `features/smart_recommendations/` | Entire directory — no integration |

---

## 6. Stabilization Priority

### Tier 1 — Must Fix Before Anything Else

| Feature | Issue | Impact |
|---|---|---|
| Audio Playback | errorStream not consumed | Silent failures |
| Queue Management | Shuffle display broken | Confusing UX |
| Queue Management | No URI validation on restore | Playback errors |
| Favorites | Race condition on init | Feature unreliable |
| Playlists | Not auto-loaded | Feature appears broken |
| Dynamic Theme | Not reactive | Visual feature broken |

### Tier 2 — Fix for Core Stability

| Feature | Issue | Impact |
|---|---|---|
| Equalizer | No capability detection | Silent failure on some devices |
| Seek | Continuous fire during drag | Audio stutter |
| State | PlayerController duplication | Potential state divergence |
| Performance | Palette on main thread | Jank on song change |
| Performance | getSongById O(n) | Slow recommendations |
| Database | No migrations | Cannot evolve schema |

### Tier 3 — Fix for Quality

| Feature | Issue | Impact |
|---|---|---|
| Database | Unbounded play_events | Growing DB size |
| Database | Denormalized playlists | Stale data |
| Theme | Light theme broken | Light mode unusable |
| Favorites | isFavorite always false | Misleading API |
| Navigation | ForYouScreen hidden | Feature inaccessible |
| UX | No empty states | Confusing blank screens |
| UX | Dismissible skip tracks | Unintuitive gestures |

### Tier 4 — Polish

| Feature | Issue | Impact |
|---|---|---|
| Typos | "sueno", "Reproduccion" | Unprofessional |
| Dead code | Unused methods | Maintenance burden |
| Globals | late variables in main | Not testable |
| FK constraints | Not enforced | Data integrity risk |

---

> **Note:** Feature status based on static code analysis. Runtime behavior may differ. Update as features are implemented, fixed, or removed.
