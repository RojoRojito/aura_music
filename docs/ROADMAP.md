# AURA Music — Product Reconstruction Roadmap

> **Created:** 2026-05-17
> **Current Version:** 1.1.0
> **Status:** Strategic Planning — Pre-Implementation
> **Scope:** Full product reconstruction from "functional app with features" → "premium musical product with its own identity"

---

## Table of Contents

1. [Product Vision](#1-product-vision)
2. [Phase 1 — Core Stabilization](#2-phase-1--core-stabilization)
3. [Phase 2 — Design System & Identity](#3-phase-2--design-system--identity)
4. [Phase 3 — Premium Experience](#4-phase-3--premium-experience)
5. [Phase 4 — Branding](#5-phase-4--branding)
6. [Phase 5 — Optimization & Release](#6-phase-5--optimization--release)
7. [Current Findings](#7-current-findings)
8. [Product Philosophy](#8-product-philosophy)

---

## 1. Product Vision

### 1.1 What Is AURA Music

AURA Music is an **offline music player for Android**, built with Flutter. It scans local audio files, plays them back with background service support, manages playlists, and offers equalizer controls. The app already works — it has features, it plays music, it persists state.

But it is not yet a **product**.

### 1.2 Direction

The goal of this reconstruction is to transform AURA Music from:

> *"A functional Flutter app that plays local music files"*

Into:

> *"A premium, emotionally resonant music experience with its own visual identity, fluid interactions, and a sense of craftsmanship."*

### 1.3 Target Experience

When a user opens AURA Music, they should feel:

- **Calm** — the interface breathes, nothing fights for attention
- **Connected** — the UI reacts to the music being played (colors, motion, depth)
- **In control** — every gesture, every tap feels intentional and responsive
- **Delighted** — small moments of polish that make the experience memorable

### 1.4 Identity Sought

AURA Music should feel like a **boutique product**, not a generic template. Key differentiators:

| Generic Player | AURA Music |
|---|---|
| Static UI | Reactive, artwork-driven backgrounds |
| Standard Material components | Custom design language with glassmorphism and depth |
| Functional interactions | Intentional motion and micro-interactions |
| One-size-fits-all | Personalized through dynamic theming and smart features |
| Invisible brand | Distinct visual personality from splash to player |

### 1.5 What Makes It Different

1. **Artwork-Reactive UI** — The entire interface subtly shifts based on the current album art's color palette
2. **Ambient Depth** — Glassmorphism, selective blur, and layered translucency create spatial hierarchy
3. **Intentional Motion** — Every transition, every state change has purpose and personality
4. **Smart, Not Complex** — Features like recommendations, EQ presets, and queue management work quietly in the background

---

## 2. Phase 1 — Core Stabilization

**Objective:** Convert the current app into a stable, consistent, and reliable foundation.

**Estimated Duration:** 2–3 weeks
**Priority:** P0 — Critical

### 2.1 Audio Core

| Item | Current Problem | Impact | Technical Goal | Priority |
|---|---|---|---|---|
| **Playback state sync** | `PlayerController` maintains `_isPlaying` separately from `AuraAudioHandler._player.playing`. State can diverge. | UI shows wrong play/pause state after errors or background transitions. | Single source of truth: `AuraAudioHandler` owns state; `PlayerController` mirrors via streams only. | P0 |
| **Current song sync** | `PlayerController.currentSong` is a getter to `_h.currentSong`, but `onSongChanged` callback in `main.dart` fires independently. | Race conditions on song change; theme/EQ may apply to wrong song. | Unified song-change event stream that all listeners subscribe to. | P0 |
| **Error handling** | Errors are caught in `_loadCurrent()` and auto-skip, but no user-facing feedback. | User sees no indication when a file fails to play. | Expose `errorStream` to UI; show non-intrusive error banners in mini-player. | P1 |
| **Audio session ID** | Retry loop (10 attempts × 500ms) is a workaround for delayed session ID. Fragile. | EQ may fail to initialize on some devices. | Replace with proper `androidAudioSessionId` stream listener from `just_audio`. | P1 |

### 2.2 Queue Management

| Item | Current Problem | Impact | Technical Goal | Priority |
|---|---|---|---|---|
| **Queue persistence** | `StatePersistenceService` exists but `PlayerController` creates its own instance. `AuraAudioHandler` doesn't use it. | Queue state may not persist correctly across sessions. | Centralize persistence: `AuraAudioHandler` owns save/restore; `StatePersistenceService` is injected. | P0 |
| **Queue mutation** | `addToQueue`, `playNext`, `removeFromQueue` modify `_queue` directly but don't handle shuffle state. | Queue order becomes inconsistent when shuffle is toggled. | Maintain both original and shuffled indices; sync mutations across both. | P1 |
| **Stale queue restoration** | Queue restored from SharedPreferences uses 24h staleness check, but URIs may be invalid if files were deleted. | App tries to play non-existent files on restore. | Validate URIs before restoring; skip invalid entries with fallback. | P1 |

### 2.3 Playback Controls

| Item | Current Problem | Impact | Technical Goal | Priority |
|---|---|---|---|---|
| **Repeat mode** | `PlayerScreen` uses local `_cycleRepeat()` that reads from controller then writes back. Three-state cycle (off → all → one) works but is UI-layer logic. | Repeat state could be lost if screen is rebuilt. | Move cycle logic into `AuraAudioHandler`; expose `cycleRepeat()` method. | P2 |
| **Shuffle sync** | Shuffle state lives in `just_audio`'s `shuffleModeEnabled`. No explicit queue reordering is performed. | Shuffle doesn't actually reorder the visible queue. | Implement explicit queue shuffle on toggle; preserve original order for unshuffle. | P1 |
| **Seek bar** | Slider uses `onChanged` which fires continuously during drag. No debouncing. | Excessive seek calls during drag; potential audio stutter. | Use `onChangeStart`/`onChangeEnd` pattern; only seek on release. | P1 |

### 2.4 Equalizer

| Item | Current Problem | Impact | Technical Goal | Priority |
|---|---|---|---|---|
| **EQ integration** | `EqualizerService` uses `MethodChannel` to native code. Channel setup is implicit; no error recovery. | EQ silently fails on devices without native support. | Add capability detection; graceful fallback with UI indicator. | P1 |
| **Per-song configs** | EQ configs are saved per-song in SQLite, but loading happens on `onSongChanged` which may fire before session is ready. | EQ settings may not apply to first song after app launch. | Defer EQ load until audio session is confirmed; queue pending configs. | P1 |
| **Preset application** | `applyPreset()` replaces band gains but doesn't update `presetName` in DB if song had a custom config. | Preset name shown in UI may not match actual settings. | Persist preset name alongside band gains; distinguish custom vs preset. | P2 |

### 2.5 Favorites

| Item | Current Problem | Impact | Technical Goal | Priority |
|---|---|---|---|---|
| **Favorites loading** | `loadFavorites()` is called in `main.dart` before providers are set up. Race condition possible. | Favorites may not be available when first screen renders. | Move load into `FavoritesRepository` constructor or lazy-load on first access. | P0 |
| **Song.isFavorite field** | `Song` model has `isFavorite` field but it's never populated from `FavoritesRepository`. | Favorite status is always `false` in Song objects. | Create a computed favorite status layer; don't mutate immutable Song model. | P1 |

### 2.6 Playlists

| Item | Current Problem | Impact | Technical Goal | Priority |
|---|---|---|---|---|
| **PlaylistRepository not loaded** | `PlaylistRepository` is provided but `loadPlaylists()` is never called at startup. | Playlists screen shows empty until manual refresh. | Auto-load playlists on app start; expose loading state. | P0 |
| **Playlist song data** | Songs in playlists are stored with denormalized fields (title, artist, uri). If file is moved, data becomes stale. | Playlist songs may point to invalid URIs. | Store only `song_id`; resolve full Song from MediaScanner at read time. | P1 |
| **No reorder support** | `position` column exists in `playlist_songs` but no reorder logic is implemented. | Users cannot customize playlist order. | Implement drag-and-drop reorder; update position values atomically. | P2 |

### 2.7 Theme State

| Item | Current Problem | Impact | Technical Goal | Priority |
|---|---|---|---|---|
| **DynamicThemeService is singleton** | Singleton with mutable state. Not a `ChangeNotifier`, so UI cannot react to color changes. | PlayerScreen gradient doesn't update when song changes unless rebuilt. | Convert to `ChangeNotifier`; expose color streams; UI listens reactively. | P0 |
| **Theme extraction is blocking** | `updateFromAlbumArt()` runs on main thread; palette extraction can cause jank. | Frame drops when song changes. | Run palette extraction in isolate or with `compute()`. | P1 |
| **No fallback for missing art** | If album art is null, palette extraction fails silently and colors stay at defaults. | UI looks inconsistent for songs without artwork. | Define fallback color generation based on song metadata hash. | P2 |

### 2.8 Database

| Item | Current Problem | Impact | Technical Goal | Priority |
|---|---|---|---|---|
| **No migration strategy** | `onUpgrade` re-runs `CREATE TABLE IF NOT EXISTS`. No ALTER TABLE for schema changes. | Adding columns in future versions will fail silently or crash. | Implement proper versioned migrations with ALTER TABLE statements. | P1 |
| **Defensive onOpen** | `onOpen` re-runs all CREATE statements on every database open. Unnecessary overhead. | Minor performance hit on every app launch. | Remove defensive CREATE from onOpen; rely on proper migrations. | P2 |
| **No database versioning** | Database is always version 1. | Cannot track schema evolution. | Increment version with each schema change; add migration paths. | P1 |

### 2.9 State Duplication

| Item | Current Problem | Impact | Technical Goal | Priority |
|---|---|---|---|---|
| **PlayerController ↔ AudioHandler** | `PlayerController` wraps `AuraAudioHandler` but duplicates getters (`currentSong`, `isPlaying`, `queue`, `currentIndex`). | Two layers of state that can diverge; confusing data flow. | `PlayerController` should only add behavior (persistence, sleep timer), not duplicate state. | P0 |
| **Settings persistence** | `SettingsController` uses SharedPreferences directly. `StatePersistenceService` also uses SharedPreferences. | Scattered persistence logic; no unified approach. | Consolidate into a single `PreferencesService` with typed accessors. | P2 |
| **LibraryController state** | `_all` and `_filtered` are separate lists. Search creates new list on every keystroke. | Memory waste for large libraries; unnecessary rebuilds. | Use a single source list with computed filtered view; debounce search. | P2 |

### 2.10 UI False States

| Item | Current Problem | Impact | Technical Goal | Priority |
|---|---|---|---|---|
| **Settings placeholders** | Settings screen shows functional-looking controls but some are partially connected. | User confusion when features don't behave as expected. | Either fully implement or clearly mark as "coming soon". | P1 |
| **Empty states** | No empty state UI for playlists, albums, or artists when library is empty. | App appears broken on first launch or empty device. | Design and implement empty state screens with actionable CTAs. | P2 |
| **Loading states** | Some screens show loading indicators, others don't. Inconsistent. | User doesn't know if app is working or frozen. | Standardize loading state pattern across all screens. | P2 |

### Phase 1 Checklist

- [x] Single source of truth for playback state — thin proxies, no duplication
- [x] Unified song-change event stream — single onSongChanged callback
- [x] User-facing audio error feedback — AudioError stream + SnackBar in app.dart
- [x] Proper audio session ID handling — stream-based with _sessionIdSent guard
- [x] Centralized queue persistence — StatePersistenceService
- [x] Queue shuffle consistency — Fisher-Yates _shuffleMap in AuraAudioHandler
- [x] Stale queue validation on restore — 24h check + URI validation
- [x] Repeat mode cycle in handler — cycleRepeat() in AuraAudioHandler
- [x] Explicit queue shuffle implementation — shuffleMap + displayQueue
- [x] Seek bar debouncing — onChangeStart/onChangeEnd pattern
- [x] EQ capability detection + fallback — isAvailable flag + fallback UI
- [x] Per-song EQ load timing fix — initSession re-applies pending config
- [x] Preset name persistence — preset_name column in eq_configs
- [x] Favorites race condition fix — loadFavorites() before AudioService.init
- [x] Computed favorite status layer — Song.isFavorite removed, UI reads from FavoritesRepository
- [x] Auto-load playlists on startup — loadPlaylists() in Provider.create
- [x] Playlist song data normalization — song_album column, DB migration v3
- [x] DynamicThemeService as ChangeNotifier — extends ChangeNotifier, notifyListeners()
- [x] Palette extraction off main thread — compute() isolate
- [x] Fallback colors for missing artwork — 0xFF7C4DFF / 0xFF00E5FF defaults
- [x] Database migration strategy — versioned _migrations map, _currentVersion = 3
- [x] Remove defensive onOpen overhead — onOpen only runs PRAGMA foreign_keys
- [x] Database version tracking — _currentVersion = 3
- [x] Eliminate PlayerController state duplication — redundant notifyListeners removed
- [x] Consolidate preferences persistence — SharedPreferences.getInstance() is singleton
- [x] Library search optimization — 300ms debounce on onChanged
- [x] Remove/complete settings placeholders — all tiles functional
- [x] Empty state screens — all screens have icon+text empty states
- [x] Consistent loading states — shared AuraLoadingIndicator widget

---

## 3. Phase 2 — Design System & Identity

**Objective:** Create a premium, coherent visual identity that makes AURA Music instantly recognizable.

**Estimated Duration:** 3–4 weeks
**Priority:** P0 — Critical (after Phase 1)

### 3.1 Visual Direction

#### Philosophy

AURA Music's visual language should embody **"light through glass"** — layered translucency, soft depth, and colors that breathe with the music. The interface should feel like looking through frosted glass at a glowing light source (the album art).

#### Style Pillars

| Pillar | Description |
|---|---|
| **Depth over flatness** | Layers, elevation, and translucency create spatial hierarchy |
| **Color from content** | UI colors derive from album art, not static palettes |
| **Motion with purpose** | Animations guide attention, never decorate |
| **Space as luxury** | Generous padding and margins; content breathes |
| **Typography as structure** | Font weights and sizes create clear information hierarchy |

#### UI Style

- **Glassmorphism (soft)** — Backdrop blur with subtle borders, not heavy frosted glass
- **Ambient backgrounds** — Gradient meshes derived from artwork, animated slowly
- **Selective blur** — Blur applied only where it adds depth (mini-player, bottom sheets, overlays)
- **Dynamic backgrounds** — Player screen background shifts with current song's palette

### 3.2 Design Token System

#### Typography

| Token | Usage | Size | Weight | Line Height |
|---|---|---|---|---|
| `display` | Player screen song title | 24–28px | Bold (700) | 1.2 |
| `headline` | Section headers, screen titles | 20–22px | Semibold (600) | 1.3 |
| `title` | Card titles, list primary text | 16px | Medium (500) | 1.4 |
| `body` | Body text, descriptions | 14px | Regular (400) | 1.5 |
| `caption` | Secondary info, timestamps | 12px | Regular (400) | 1.4 |
| `label` | Button labels, tags | 13px | Medium (500) | 1.3 |
| `overline` | Section labels, metadata | 10–11px | Medium (500), letter-spacing +1.5 | 1.4 |

**Font family:** System default (Roboto on Android) — no custom fonts to keep APK size minimal. Hierarchy achieved through weight and size, not typeface variety.

#### Spacing Scale

Base unit: **4px**

| Token | Value | Usage |
|---|---|---|
| `xs` | 4px | Tight inline spacing |
| `sm` | 8px | Related elements |
| `md` | 12px | Component internal padding |
| `lg` | 16px | Card padding, section gaps |
| `xl` | 24px | Screen margins, major sections |
| `2xl` | 32px | Hero sections, player spacing |
| `3xl` | 48px | Full-screen breathing room |

#### Color System

**Core palette** (derived from artwork, with fallbacks):

| Token | Dark Fallback | Light Fallback | Usage |
|---|---|---|---|
| `background` | `#0A0A0F` | `#F5F5F7` | Primary background |
| `surface` | `#13131A` | `#FFFFFF` | Cards, surfaces |
| `surface-elevated` | `#1E1E28` | `#F0F0F5` | Raised elements |
| `primary` | Artwork-derived | Artwork-derived | Primary actions, accents |
| `secondary` | Artwork-derived | Artwork-derived | Secondary accents |
| `text-primary` | `#E8E8F0` | `#1A1A2E` | Primary text |
| `text-secondary` | `#8888AA` | `#6B6B80` | Secondary text |
| `text-tertiary` | `#555570` | `#9999AA` | Disabled, placeholders |
| `border` | `#2A2A3A` | `#E0E0E5` | Dividers, borders |
| `success` | `#4CAF50` | `#388E3C` | Positive states |
| `error` | `#EF5350` | `#D32F2F` | Error states |

**Artwork extraction rules:**
- Dominant color → primary accent (desaturated by 20% for readability)
- Vibrant color → secondary accent
- Dark tones → background tint (5–10% opacity overlay)
- If artwork is too bright/white, shift to darker variant

#### Elevation System

| Level | Shadow | Usage |
|---|---|---|
| `0` | None | Background, flat surfaces |
| `1` | `0 1px 3px rgba(0,0,0,0.12)` | Cards, tiles |
| `2` | `0 2px 8px rgba(0,0,0,0.16)` | Mini-player, floating elements |
| `3` | `0 4px 16px rgba(0,0,0,0.20)` | Bottom sheets, modals |
| `4` | `0 8px 32px rgba(0,0,0,0.24)` | Full-screen overlays |

#### Corner Radius

| Token | Value | Usage |
|---|---|---|
| `none` | 0px | Full-bleed images |
| `sm` | 8px | Small chips, tags |
| `md` | 12px | Cards, tiles |
| `lg` | 16px | Mini-player, bottom sheets |
| `xl` | 20px | Album art, hero images |
| `full` | 50% | Circular elements (play button, avatars) |

#### Translucency

| Level | Opacity | Usage |
|---|---|---|
| `subtle` | 0.6–0.7 | Background overlays |
| `medium` | 0.8–0.85 | Mini-player, toolbars |
| `strong` | 0.9–0.95 | Bottom sheets, dialogs |

#### Shadows

Shadows should be **colored**, not black. Use the primary accent color at low opacity (10–20%) for a cohesive look.

#### Iconography

- Use Material Icons (already included via `cupertino_icons`)
- Outlined variants for inactive states
- Filled variants for active states
- Consistent sizes: 20px (small), 24px (default), 32px (large), 40px (hero)

### 3.3 Motion Language

#### Principles

1. **Fast in, slow out** — Enter animations are quick (200–300ms); exit animations are slower (300–400ms)
2. **Spring over linear** — Use `Curves.easeOutCubic` and `Curves.easeInOut` for natural motion
3. **Staggered reveals** — Lists animate items with 30–50ms stagger
4. **Contextual** — Motion direction matches user intent (swipe right = slide right)

#### Animation Tokens

| Token | Duration | Curve | Usage |
|---|---|---|---|
| `instant` | 100ms | `easeOut` | Micro-interactions, toggle states |
| `fast` | 200ms | `easeOutCubic` | Button feedback, icon transitions |
| `normal` | 300ms | `easeOutCubic` | Screen transitions, card reveals |
| `slow` | 500ms | `easeInOut` | Hero transitions, full-screen changes |
| `ambient` | 3000ms+ | `easeInOut` | Background gradients, slow color shifts |

### 3.4 Component Guidelines

#### Rules

1. **Every interactive element must have a pressed state** — opacity change or scale
2. **Loading states must be visible within 200ms** — no silent loading
3. **Error states must be actionable** — show what went wrong and how to fix it
4. **Empty states must be helpful** — explain why it's empty and what to do
5. **All surfaces must have a defined background** — never rely on parent background

#### Consistency Rules

- All lists use the same tile pattern
- All bottom sheets use the same header pattern
- All dialogs use the same action button pattern
- All screens use the same back navigation pattern

### 3.5 Screen Redesigns

#### Mini Player

**Current issues:**
- Dismissible for skip navigation (unintuitive — dismiss usually means close)
- Circular progress indicator is small and hard to read
- No visual connection to current song's artwork colors
- Fixed position at `bottom: 70` overlaps with navigation bar

**Redesign goals:**
- Full-width bar with glassmorphism background
- Artwork thumbnail on left (40×40, rounded)
- Song title + artist with marquee scroll for long text
- Linear progress bar along bottom edge (subtle, 2px)
- Play/pause button (primary), skip next (secondary)
- Tap to expand to full player (not dismiss to skip)
- Long-press for quick actions (add to queue, favorite)
- Dynamic border color from artwork palette
- Height: 56px (compact) → 64px (expanded on play)

#### Player Screen

**Current issues:**
- Gradient from accent to background is static per-song
- Album art scale animation (pause = 0.88) feels abrupt
- No visualizer or ambient element
- Controls are basic IconButton row
- Queue sheet is plain ListView
- No lyrics support
- No gesture controls

**Redesign goals:**
- Full-screen artwork-reactive gradient mesh (3–4 colors, slow animation)
- Album art: large (320×320), centered, with soft colored shadow
- Song info: large title, artist with optional "go to artist" tap
- Seek bar: full-width, with time labels, draggable with haptic feedback
- Controls: larger play button (80px), with skip buttons at 48px
- Secondary row: shuffle, EQ, queue, repeat — with active state glow
- Bottom: swipe-up handle to reveal queue/lyrics panel
- Ambient particles or waveform visualization (subtle, toggleable)
- Gesture: swipe up for queue, swipe down to minimize, swipe left/right for skip

#### Navigation

**Current issues:**
- 5-tab NavigationBar is crowded
- "Canciones" as first tab is redundant with home
- No visual hierarchy between tabs
- No active tab indicator beyond Material default

**Redesign goals:**
- Reduce to 4 tabs: **Home** (discover + recently played), **Library** (songs/albums/artists), **Playlists**, **Settings**
- NavigationBar with custom indicator (pill shape, artwork-tinted)
- Active tab icon filled, inactive outlined
- Tab labels visible at all times (no auto-hide)
- Haptic feedback on tab change
- Consider bottom sheet navigation for Library sub-tabs (Songs, Albums, Artists)

#### Library

**Current issues:**
- Single list of all songs — no grouping or sections
- Search only filters, doesn't provide suggestions
- No sort options
- No view toggle (list/grid)

**Redesign goals:**
- Sectioned list: Recently Played, Recently Added, Most Played
- Search with recent searches and suggestions
- Sort by: title, artist, album, duration, date added
- View toggle: list (default) / grid (for albums)
- Pull-to-refresh for library rescan
- Floating action button: shuffle all

#### Playlists

**Current issues:**
- Basic list with delete button
- No playlist detail screen with songs
- No reorder capability
- No playlist cover art (first song's artwork?)

**Redesign goals:**
- Playlist cards with cover art (grid of 4 song artworks or first song's art)
- Playlist detail: header with cover, song count, total duration, play/shuffle buttons
- Song list with drag handles for reorder
- Long-press for context menu (remove, move to top, add to queue)
- Create playlist: bottom sheet with name input + optional cover selection
- Edit playlist name inline

#### Search

**Current issues:**
- Search only exists in Library screen
- No global search

**Redesign goals:**
- Global search accessible from any screen (search icon in app bar)
- Search across: songs, albums, artists, playlists
- Results grouped by type with section headers
- Recent searches saved locally
- Tap result to navigate to appropriate detail screen

### Phase 2 Checklist

- [x] Design token system implemented (typography, spacing, colors, elevation, radius)
- [x] Color extraction from artwork with fallbacks
- [x] Glassmorphism component variants
- [x] Motion/animation token system
- [x] Mini player redesign
- [x] Player screen redesign
- [x] Navigation redesign (4 tabs)
- [x] Library screen redesign
- [x] Playlist screens redesign
- [ ] Search redesign (global)
- [x] Empty state designs
- [x] Loading state patterns
- [x] Error state patterns
- [x] Component consistency audit
- [ ] Accessibility contrast check

---

## 4. Phase 3 — Premium Experience

**Objective:** Transform the app into a modern, emotional musical product with advanced features.

**Estimated Duration:** 4–6 weeks
**Priority:** P1 — After Phase 1 & 2 are stable

### 4.1 Gestures

| Gesture | Location | Action | Priority |
|---|---|---|---|
| Swipe left/right | Mini player | Skip previous/next | P1 |
| Tap | Mini player | Open full player | P1 |
| Long-press | Mini player | Quick actions (favorite, add to queue) | P2 |
| Swipe up | Player screen bottom | Reveal queue panel | P1 |
| Swipe down | Player screen | Minimize to mini player | P1 |
| Swipe left/right | Player screen artwork | Skip previous/next | P1 |
| Double-tap | Player screen artwork | Toggle play/pause | P2 |
| Pinch | Player screen artwork | Zoom artwork (preview) | P3 |
| Pull-down | Library top | Refresh library scan | P1 |
| Swipe left/right | Song tile | Add to queue / Add to playlist | P1 |
| Long-press | Song tile | Context menu | P1 |
| Drag handle | Playlist song | Reorder songs | P1 |

### 4.2 Advanced Queue

| Feature | Description | Priority |
|---|---|---|
| **Reorder queue** | Drag-and-drop to reorder upcoming songs | P1 |
| **Clear queue** | Option to clear all upcoming songs | P1 |
| **Save queue as playlist** | Export current queue to a new playlist | P2 |
| **Queue history** | View recently played songs (back history) | P2 |
| **Smart queue insertion** | "Play next" inserts after current, not at end | P1 |
| **Queue from multiple sources** | Add songs from different albums/artists to same queue | P1 |

### 4.3 Contextual Menus

| Context | Actions | Priority |
|---|---|---|
| Song (anywhere) | Play next, Add to queue, Add to playlist, Go to album, Go to artist, View info, Share | P1 |
| Album | Play, Shuffle, Add all to queue, Add to playlist, View artist | P1 |
| Artist | Play all, Shuffle, Add to queue, View albums | P1 |
| Playlist | Play, Shuffle, Edit name, Delete, Export, Share | P1 |
| Queue item | Play now, Play next, Remove, Move to top | P1 |

### 4.4 Lyrics

| Feature | Description | Priority |
|---|---|---|
| **Lyrics display** | Show synchronized lyrics in player screen | P2 |
| **Lyrics source** | Local `.lrc` files alongside music files | P2 |
| **Scroll sync** | Auto-scroll lyrics to match playback position | P2 |
| **Manual scroll** | User can scroll lyrics independently | P2 |
| **No lyrics state** | Graceful "No lyrics available" message | P2 |

### 4.5 Audio Features

| Feature | Description | Priority |
|---|---|---|
| **Crossfade** | Overlap end of current song with start of next (configurable: 0–12s) | P2 |
| **Gapless playback** | Seamless transition between tracks (just_audio supports this) | P1 |
| **Volume normalization** | Adjust volume across songs for consistent loudness | P3 |
| **Fade in/out on play/pause** | Smooth volume transitions (100–300ms) | P2 |
| **Sleep timer fade out** | Gradually reduce volume in last 30 seconds of timer | P2 |

### 4.6 Smart Recommendations

| Feature | Description | Priority |
|---|---|---|
| **Recently played** | Show last 10–20 played songs on home screen | P1 |
| **Most played** | Top songs by play count | P1 |
| **Recently added** | Songs added to device in last 7/30 days | P1 |
| **Smart shuffle** | Shuffle weighted by play history (favorite songs appear more) | P2 |
| **Mood-based playlists** | Auto-generated playlists based on listening patterns | P3 |
| **Artist variety** | Avoid playing same artist twice in short succession | P2 |

### 4.7 Ambient Animations

| Animation | Location | Description | Priority |
|---|---|---|---|
| **Color shift** | Player background | Slow gradient transition between artwork colors (3–5s cycle) | P1 |
| **Playing indicator** | Mini player, song tiles | Animated bars or pulse when song is playing | P1 |
| **Album art shadow** | Player screen | Colored shadow that shifts with artwork | P1 |
| **Progress glow** | Seek bar | Subtle glow at progress head | P2 |
| **Button ripple** | All interactive elements | Colored ripple matching theme | P1 |
| **List stagger** | All lists | Items animate in with 30ms stagger on screen enter | P2 |
| **Equalizer bars** | EQ screen | Animated bars showing current band levels | P1 |

### 4.8 Immersive Transitions

| Transition | From → To | Style | Priority |
|---|---|---|---|
| Mini player → Full player | Slide up + expand | Shared element (artwork grows) | P1 |
| Full player → Mini player | Slide down + shrink | Shared element (artwork shrinks) | P1 |
| Library → Album detail | Shared element (album art expands) | Hero animation | P1 |
| Library → Artist detail | Slide in from right | Standard push | P1 |
| Tab switch | Fade + slide | Subtle crossfade | P2 |
| Bottom sheet open | Slide up with spring | Spring animation | P1 |
| Dialog open | Scale + fade | Center scale from 0.9 to 1.0 | P1 |

### 4.9 Onboarding

| Screen | Content | Priority |
|---|---|---|
| Welcome | App name, tagline, brief description | P2 |
| Permission | Explain why audio permission is needed | P1 |
| Library scan | Show scanning progress with animation | P1 |
| Feature tour | Swipeable cards highlighting key features | P2 |
| Theme choice | Let user pick light/dark/system theme | P2 |

### 4.10 Personalization

| Feature | Description | Priority |
|---|---|---|
| **Custom EQ presets** | User creates and names their own EQ presets | P1 |
| **Home screen layout** | User chooses which sections appear on home | P3 |
| **Default view** | User sets default tab on app launch | P2 |
| **Gesture preferences** | User enables/disables specific gestures | P3 |
| **Visualization toggle** | User enables/disables ambient visualizations | P2 |

### Phase 3 Checklist

- [ ] Gesture system implemented
- [ ] Queue reorder (drag-and-drop)
- [ ] Contextual menus (long-press)
- [ ] Lyrics support (local .lrc)
- [ ] Gapless playback
- [ ] Crossfade with config
- [ ] Sleep timer fade out
- [ ] Smart recommendations (recent, most played, recently added)
- [ ] Smart shuffle
- [ ] Ambient color shift animation
- [ ] Playing indicator animations
- [ ] Album art colored shadow
- [ ] List stagger animations
- [ ] Shared element transitions
- [ ] Onboarding flow
- [ ] Custom EQ presets
- [ ] Personalization settings

---

## 5. Phase 4 — Branding

**Objective:** Create a complete brand identity that makes AURA Music instantly recognizable.

**Estimated Duration:** 2–3 weeks
**Priority:** P2 — After core and design are stable

### 5.1 Naming Exploration

**Current name:** AURA Music

**Analysis:**
- "AURA" suggests atmosphere, ambiance, presence — fitting for a music player
- Short, memorable, works globally
- Available as a concept (needs trademark check for commercial distribution)

**Alternative directions to explore:**

| Name | Rationale | Vibe |
|---|---|---|
| AURA | Current — atmospheric, ambient | Ethereal, modern |
| Resonance | Connection between sound and listener | Warm, emotional |
| Cadence | Rhythm, flow, musical timing | Sophisticated, musical |
| Timbre | Quality of sound | Technical, premium |
| Echo | Reflection, memory | Nostalgic, simple |

**Recommendation:** Keep "AURA" — it's distinctive, short, and the concept of "aura" (the atmosphere surrounding something) perfectly matches the design direction of artwork-reactive, ambient UI.

### 5.2 Logo System

#### Concept Directions

1. **Sound wave aura** — Concentric circles or waves emanating from a center point, suggesting sound radiating outward
2. **Abstract "A"** — Minimalist letter A formed by audio waveform or equalizer bars
3. **Orb with gradient** — Circular shape with a gradient that suggests depth and atmosphere
4. **Musical note abstraction** — A note shape simplified into geometric forms

#### Logo Rules

- Must work at 16×16 (favicon size) and 1024×1024 (app icon)
- Must work in single color (for monochrome contexts)
- Must work on dark and light backgrounds
- Must be recognizable without the wordmark

### 5.3 App Icon

**Requirements:**
- Adaptive icon for Android (foreground + background layers)
- Foreground: logo mark
- Background: solid color or subtle gradient (brand color)
- Must follow Android adaptive icon guidelines (safe zone: 108dp circular)

**Design directions:**
- Dark background (`#0A0A0F`) with logo in primary brand color
- Gradient background matching brand palette
- Subtle shadow or glow effect on logo mark

### 5.4 Splash Screen

**Current:** Default Flutter splash (white screen with blue spinner)

**Redesign:**
- Brand background color (dark or gradient)
- Centered logo mark (animated: subtle pulse or glow)
- App name below logo
- Smooth transition to main screen (fade out splash, fade in app)
- Android 12+ splash screen API support

### 5.5 Typography Branding

- **Display font:** System default (no custom font to minimize APK size)
- **Brand treatment:** "AURA" in all caps, wide letter-spacing (+2 to +4), bold weight
- **Tagline direction:** "Music, reimagined" or "Your sound, your space" or "Feel the music"

### 5.6 Color Identity

**Primary brand color:** Purple (`#7C4DFF`) — creative, premium, musical
**Secondary brand color:** Cyan (`#00E5FF`) — modern, digital, fresh
**Accent:** Pink (`#FF4081`) — emotional, warm, human

**Brand palette usage:**
- Primary: main actions, active states, key UI elements
- Secondary: secondary actions, highlights, progress indicators
- Accent: favorites, emotional moments, special states

**Dark mode is the default brand experience** — the app should feel native in dark mode, with light mode as an alternative.

### 5.7 Marketing Visuals

| Asset | Description | Priority |
|---|---|---|
| App Store screenshots | 5–8 screenshots showing key features | P1 |
| Feature graphic | 1024×500 banner for Play Store | P1 |
| Promo video | 30-second video showing the app in use | P2 |
| Social media kit | Square and story-format visuals | P2 |
| Press kit | Logo files, brand guidelines, screenshots | P2 |

### 5.8 Product Personality

**Tone:** Confident but not arrogant. Warm but not casual. Premium but not cold.

**The app should feel like:**
- A well-designed physical object (like a premium speaker or headphones)
- A space designed for listening, not just a tool for playing files
- Something that respects the user's music collection and listening habits

**Sensations to transmit:**
- Calm focus — the UI disappears, the music takes center stage
- Warmth — colors and motion feel inviting, not sterile
- Craftsmanship — every detail feels intentional
- Flow — transitions are smooth, interactions are fluid

### Phase 4 Checklist

- [ ] Finalize brand name decision
- [ ] Design logo mark (vector)
- [ ] Create adaptive app icon
- [ ] Design splash screen
- [ ] Define brand typography treatment
- [ ] Finalize brand color palette
- [ ] Create app store screenshots
- [ ] Create feature graphic
- [ ] Write app store description
- [ ] Define product personality guidelines

---

## 6. Phase 5 — Optimization & Release

**Objective:** Polish performance, ensure quality, and prepare for release.

**Estimated Duration:** 2–3 weeks
**Priority:** P1 — Before any public release

### 6.1 Performance

#### Memory Optimization

| Area | Current Issue | Goal | Priority |
|---|---|---|---|
| **Image caching** | `QueryArtworkWidget` queries artwork repeatedly | Cache artwork in memory; use cached version in lists | P1 |
| **Song list memory** | All songs loaded into memory at once | For libraries >2000 songs, implement lazy loading or pagination | P2 |
| **Palette extraction** | Runs on main thread, creates Image objects | Run in isolate; dispose images immediately after extraction | P1 |
| **Stream subscriptions** | Multiple listeners may not be properly disposed | Audit all subscriptions; ensure disposal in `dispose()` methods | P1 |
| **Widget rebuilds** | `context.watch` on large providers causes full rebuilds | Use `select` for targeted listening; split providers where needed | P1 |

#### Audio Optimization

| Area | Current Issue | Goal | Priority |
|---|---|---|---|
| **Audio player lifecycle** | `AudioPlayer` created in handler, never explicitly disposed | Properly dispose on app termination | P1 |
| **Preload next track** | Next track loads only when skip is triggered | Preload next track when current is 80% complete | P2 |
| **Buffer management** | No explicit buffer configuration | Configure buffer size for local files (minimal buffer needed) | P2 |

#### Animation Optimization

| Area | Current Issue | Goal | Priority |
|---|---|---|---|
| **Gradient animation** | Player background gradient may cause repaints | Use `AnimatedContainer` or custom painter with `RepaintBoundary` | P1 |
| **List animations** | Stagger animations on long lists may cause jank | Use `SliverAnimatedList` for large lists; limit visible animations | P2 |
| **Blur performance** | `BackdropFilter` is expensive on low-end devices | Detect device capability; disable blur on low-end devices | P1 |

### 6.2 Cleanup

| Task | Description | Priority |
|---|---|---|
| **Remove unused imports** | Audit all files for unused imports | P1 |
| **Remove dead code** | Remove commented-out code, unused variables, unused methods | P1 |
| **Consolidate providers** | Review Provider tree; remove redundant providers | P1 |
| **Standardize error handling** | All async operations should have try/catch with user feedback | P1 |
| **Remove debug prints** | Remove or gate `debugPrint` calls behind a debug flag | P2 |
| **Code formatting** | Run `dart format` on all files | P1 |
| **Lint compliance** | Zero warnings from `flutter analyze --no-fatal-infos` | P0 |

### 6.3 QA & Testing

#### Testing Strategy

| Test Type | Coverage Target | Tools | Priority |
|---|---|---|---|
| **Unit tests** | Repositories, services, models | `flutter test` | P1 |
| **Widget tests** | Key UI components (mini player, song tile, seek bar) | `flutter test` | P2 |
| **Integration tests** | Full playback flow (play → pause → skip → seek) | `integration_test` | P2 |

#### Key Test Cases

| Scenario | Expected Behavior | Priority |
|---|---|---|
| Play a song | Audio plays, UI updates, notification appears | P0 |
| Skip to next | Next song plays, queue index updates | P0 |
| Seek to position | Audio jumps to position, UI reflects new position | P0 |
| Toggle shuffle | Queue order changes, shuffle icon shows active | P0 |
| Toggle repeat | Repeat mode cycles: off → all → one → off | P0 |
| Add to favorites | Heart icon fills, song appears in favorites | P1 |
| Create playlist | Playlist appears in list, can add songs | P1 |
| App backgrounded | Playback continues, notification controls work | P0 |
| App killed and restored | Queue restores, playback resumes at saved position | P1 |
| EQ toggle | EQ activates/deactivates, audio changes | P1 |
| Sleep timer expires | Playback pauses at timer end | P1 |
| No permission | Shows permission request, graceful error if denied | P1 |
| Empty library | Shows empty state with helpful message | P2 |

#### Device Testing Matrix

| Device Type | Android Version | Priority |
|---|---|---|
| Flagship (Snapdragon 8 Gen 2+) | Android 14+ | P1 |
| Mid-range (Snapdragon 7 series) | Android 12–13 | P1 |
| Budget (MediaTek Helio) | Android 11–12 | P2 |
| Tablet | Android 13+ | P2 |

### 6.4 Release Preparation

| Task | Description | Priority |
|---|---|---|
| **Version bump** | Update version in `pubspec.yaml` | P0 |
| **Changelog** | Write comprehensive changelog for release | P0 |
| **App name in manifest** | Ensure `android:label` is "AURA Music" | P0 |
| **App icon** | Replace default Flutter icon with branded icon | P0 |
| **Splash screen** | Implement branded splash screen | P1 |
| **Permissions review** | Audit all permissions; remove unnecessary ones | P1 |
| **ProGuard rules** | Configure R8/ProGuard for release build | P1 |
| **Build APK** | `flutter build apk --release` — verify no errors | P0 |
| **Build AAB** | `flutter build appbundle --release` — for Play Store | P1 |
| **APK size check** | Ensure APK is under 50MB (ideal: under 30MB) | P1 |
| **Play Store listing** | Prepare description, screenshots, category | P1 |
| **Privacy policy** | Create privacy policy (required for Play Store) | P1 |

### Phase 5 Checklist

- [ ] Artwork caching implemented
- [ ] Palette extraction in isolate
- [ ] Stream subscription audit
- [ ] Widget rebuild optimization
- [ ] Audio player lifecycle management
- [ ] BackdropFilter capability detection
- [ ] Remove unused imports
- [ ] Remove dead code
- [ ] Consolidate providers
- [ ] Standardize error handling
- [ ] Remove/gate debug prints
- [ ] Code formatting
- [ ] Zero lint warnings
- [ ] Unit tests for repositories
- [ ] Unit tests for services
- [ ] Widget tests for key components
- [ ] Integration test for playback flow
- [ ] Test on flagship device
- [ ] Test on mid-range device
- [ ] Version bump
- [ ] Changelog written
- [ ] App icon replaced
- [ ] Splash screen implemented
- [ ] Permissions audit
- [ ] ProGuard/R8 configured
- [ ] Release APK built successfully
- [ ] APK size under target
- [ ] Play Store listing prepared
- [ ] Privacy policy created

---

## 7. Current Findings

### 7.1 Architecture Issues

| Issue | Location | Severity | Description |
|---|---|---|---|
| **State duplication** | `PlayerController` ↔ `AuraAudioHandler` | High | `PlayerController` duplicates getters that simply proxy to `AuraAudioHandler`. This creates two layers of state that can diverge. |
| **Singleton anti-pattern** | `DynamicThemeService`, `AppDatabase` | Medium | Singletons with mutable state make testing difficult and create hidden dependencies. |
| **Tight coupling** | `main.dart` | High | 110+ lines of initialization logic. All services are wired manually in `main()`, making it hard to test or modify initialization order. |
| **No error boundary** | Global | Medium | No global error handling. Uncaught exceptions crash the app silently. |
| **Provider tree complexity** | `main.dart` | Medium | 13 providers registered. Some could be consolidated; some are provided but never consumed. |

### 7.2 Synchronization Issues

| Issue | Location | Severity | Description |
|---|---|---|---|
| **Song change timing** | `main.dart:74-83` | High | `onSongChanged` callback triggers stats tracking, EQ loading, and theme update simultaneously. If any of these fail, the others may apply to the wrong song. |
| **EQ session dependency** | `EqualizerService` | High | EQ requires audio session ID, which is obtained asynchronously. EQ config may be applied before session is ready. |
| **Queue persistence race** | `PlayerController` | Medium | Queue is saved on every change, but restore happens on init. If restore is slow, user may see empty queue briefly. |
| **Favorites load timing** | `main.dart:41` | Medium | `loadFavorites()` is called before providers are registered. If any provider tries to access favorites during init, it will see empty state. |

### 7.3 UI Issues

| Issue | Location | Severity | Description |
|---|---|---|---|
| **UI partially connected** | Settings screen | Medium | Some settings controls are functional (speed, sleep timer, theme), but others are placeholder-only. No visual distinction between functional and placeholder. |
| **No empty states** | Playlists, Albums, Artists | Medium | When library is empty or has no results, screens show blank content instead of helpful empty state messages. |
| **Inconsistent loading** | Various screens | Low | Some screens show loading indicators, others don't. User can't tell if app is working or frozen. |
| **Mini player dismiss behavior** | `mini_player.dart` | Medium | Swiping mini player horizontally skips tracks (via `Dismissible`). This is unintuitive — dismiss usually means close/remove. |
| **PlayerScreen takes Song param** | `player_screen.dart:13` | Medium | `PlayerScreen` requires a `Song` parameter but then reads from `PlayerController.currentSong`. The param is redundant and can cause confusion. |

### 7.4 Persistence Issues

| Issue | Location | Severity | Description |
|---|---|---|---|
| **PlaylistRepository not auto-loaded** | `main.dart:97` | High | `PlaylistRepository` is provided but `loadPlaylists()` is never called. Playlists screen shows empty until user navigates and triggers load. |
| **Scattered SharedPreferences** | `SettingsController`, `StatePersistenceService` | Medium | Two classes independently manage SharedPreferences. No unified preferences layer. |
| **No persistence for EQ presets** | `EqRepository` | Low | EQ presets are defined in code (`EqConfig.presets`) but user-created presets have no persistence path. |
| **Queue serialization** | `StatePersistenceService` | Medium | Queue is serialized to JSON via `Song.toJson()`. If Song model changes, old saved queues become invalid. |

### 7.5 Database Issues

| Issue | Location | Severity | Description |
|---|---|---|---|
| **No migration strategy** | `app_database.dart` | High | Database version is always 1. `onUpgrade` re-runs CREATE statements. No ALTER TABLE for schema evolution. |
| **Defensive onOpen** | `app_database.dart:78-84` | Low | Re-runs all CREATE statements on every database open. Unnecessary overhead. |
| **Denormalized playlist songs** | `playlist_songs` table | Medium | Songs in playlists store title, artist, uri directly. If file is moved, data becomes stale. |
| **No indexes** | All tables | Low | No explicit indexes beyond PRIMARY KEY. Queries on `playlist_songs` by `playlist_id` could benefit from an index. |
| **Foreign keys not enforced** | All tables | Medium | SQLite foreign keys are not enabled. Orphaned records possible (e.g., playlist_songs referencing deleted playlists). |

### 7.6 Incomplete Features

| Feature | Current State | Gap | Priority |
|---|---|---|---|
| **Equalizer** | Native channel exists, UI exists | No capability detection, no error recovery, no preset persistence | P1 |
| **Smart recommendations** | `RecommendationEngine` computes scores | No UI integration, `statsToSongs` is slow (sequential queries) | P1 |
| **Stats tracking** | `StatsTracker` records plays | No UI to display stats, no integration with recommendations | P1 |
| **For You screen** | `for_you_screen.dart` exists | Minimal content, not integrated into navigation | P2 |
| **Artist detail** | `artists_screen.dart` has detail | Basic implementation, no album grouping | P2 |
| **Album detail** | `album_detail_screen.dart` exists | Functional but not polished | P2 |

### 7.7 Code Quality

| Issue | Severity | Description |
|---|---|---|
| **Large files** | Medium | `player_screen.dart` (354 lines), `audio_handler.dart` (237 lines) — should be split into smaller widgets/components |
| **Magic numbers** | Low | Hardcoded values for sizes, durations, positions throughout the codebase |
| **String literals** | Medium | UI text in Spanish hardcoded in widgets. No localization system. |
| **Error handling gaps** | Medium | Several async operations lack try/catch blocks |
| **Dispose gaps** | Medium | Not all ChangeNotifiers and StreamSubscriptions are properly disposed |

---

## 8. Product Philosophy

### 8.1 What It Should Feel Like

Using AURA Music should feel like **putting on a pair of well-crafted headphones** — the world fades away, and what remains is the music, presented beautifully.

The interface should:
- **Get out of the way** — never compete with the music for attention
- **Feel alive** — respond to the music with color, motion, and depth
- **Respect the collection** — treat the user's music library as something valuable
- **Reward exploration** — make discovering new (or forgotten) songs enjoyable

### 8.2 Emotions to Transmit

| Emotion | How |
|---|---|
| **Calm** | Generous spacing, soft colors, slow ambient animations |
| **Focus** | Clear hierarchy, minimal distractions, content-first layout |
| **Warmth** | Artwork-derived colors, rounded corners, soft shadows |
| **Delight** | Unexpected micro-interactions, smooth transitions, subtle details |
| **Control** | Responsive gestures, clear feedback, predictable behavior |
| **Connection** | The UI feels tied to the music — colors from artwork, motion matching rhythm |

### 8.3 Differentiation from Generic Players

| Generic Player | AURA Music |
|---|---|
| Plays files | Curates an experience |
| Static interface | Living, breathing interface |
| Functional | Emotional |
| Tool | Companion |
| One-size-fits-all | Personal and adaptive |
| Invisible brand | Distinct personality |

### 8.4 What "A Product with Soul" Means

A product with soul is one where **every decision was made with intention**, not by accident. It means:

1. **No placeholder UI** — Every screen is either complete or honestly marked as coming soon
2. **No dead features** — If a feature exists, it works well. If it doesn't work well, it doesn't exist yet
3. **Consistent language** — Visual, interaction, and copy language are unified
4. **Respect for attention** — The app doesn't waste the user's time with loading, errors, or confusion
5. **Pride in details** — The things most users won't notice are still done right
6. **Music first** — Every design decision serves the music, not the interface

### 8.5 Guiding Principles

1. **The music is the hero** — UI exists to serve the music, not the other way around
2. **Less is more** — Remove before adding. Simplify before complicating
3. **Motion with meaning** — Every animation communicates something
4. **Color from content** — The music's artwork drives the visual experience
5. **Performance is a feature** — Jank, lag, and slow loads break the emotional connection
6. **Accessibility is non-negotiable** — Beautiful doesn't mean exclusive
7. **Ship when it's right** — Not when it's done, when it's right

---

## Appendix: Phase Dependencies

```
Phase 1 (Core Stabilization)
    ↓ (must be complete before)
Phase 2 (Design System & Identity)
    ↓ (can begin while Phase 2 is in progress)
Phase 3 (Premium Experience)
    ↓ (can begin in parallel with late Phase 3)
Phase 4 (Branding)
    ↓ (must be complete before)
Phase 5 (Optimization & Release)
```

**Parallel work:**
- Phase 4 (Branding) can begin during Phase 2 or 3 — it's independent of code
- Phase 3 features can be prioritized independently — not all are required for release
- Phase 5 QA can begin as soon as Phase 1 is complete (test the stable core)

## Appendix: Estimated Timeline

| Phase | Duration | Start | End |
|---|---|---|---|
| Phase 1 — Core Stabilization | 2–3 weeks | Week 1 | Week 3 |
| Phase 2 — Design System | 3–4 weeks | Week 3 | Week 7 |
| Phase 3 — Premium Experience | 4–6 weeks | Week 5 | Week 11 |
| Phase 4 — Branding | 2–3 weeks | Week 6 | Week 9 |
| Phase 5 — Optimization & Release | 2–3 weeks | Week 10 | Week 13 |

**Total estimated timeline:** 12–14 weeks (3–3.5 months)

---

> *"AURA Music should not just play music. It should make you feel it."*
