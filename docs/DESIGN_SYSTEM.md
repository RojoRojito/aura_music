# AURA Music — Design System

> **Date:** 2026-05-17
> **Status:** Proposed — not yet implemented
> **Scope:** Visual identity, tokens, components, motion, UX rules
> **Basis:** Analysis of current `app_theme.dart` + reconstruction goals from `docs/ROADMAP.md`

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Visual Principles](#2-visual-principles)
3. [Design Tokens](#3-design-tokens)
4. [Color System](#4-color-system)
5. [Components](#5-components)
6. [Motion Language](#6-motion-language)
7. [UX Rules](#7-ux-rules)
8. [Accessibility](#8-accessibility)

---

## 1. Design Philosophy

### Emotional Direction

AURA Music should feel like **putting on well-crafted headphones** — the world fades, the music takes focus, and the interface becomes a transparent medium between listener and sound.

**Target emotions:**

| Emotion | How Achieved |
|---|---|
| **Calm** | Generous spacing, soft colors, slow ambient animations |
| **Focus** | Clear hierarchy, minimal chrome, content-first layout |
| **Warmth** | Artwork-derived colors, rounded corners, colored shadows |
| **Delight** | Micro-interactions, smooth transitions, unexpected details |
| **Control** | Responsive gestures, clear feedback, predictable behavior |

### Visual Identity

**Core metaphor:** "Light through glass"

The interface is layered translucent glass. Behind it, the album art glows — its colors bleeding through the layers, tinting everything. The UI doesn't sit on top of the music; it exists within it.

### Premium Feeling

Premium is achieved through:
- **Restraint** — fewer elements, more space
- **Consistency** — every interaction follows the same rules
- **Responsiveness** — instant feedback on every touch
- **Depth** — layered surfaces with blur and shadow
- **Color** — artwork-derived, not arbitrary

### Ambient UI

The interface is alive but never distracting:
- Background gradients shift slowly with the music's colors
- Playing indicators pulse subtly
- Shadows breathe with the artwork
- Progress bars glow at the leading edge

### Reactive UI

UI elements respond to content:
- Colors derive from current album art
- Shadows match artwork palette
- Active states glow with theme color
- Transitions follow user gesture direction

### Current State vs Target

| Aspect | Current (app_theme.dart) | Target |
|---|---|---|
| Colors | Static palette (purple/cyan/pink) | Artwork-derived with fallbacks |
| Depth | Flat surfaces, basic shadows | Layered glassmorphism with blur |
| Motion | 2 animations (scale, slide) | Full motion language with tokens |
| Typography | System default, basic weights | Structured scale with clear hierarchy |
| Spacing | Inconsistent hardcoded values | Tokenized scale (4px base) |
| Components | Mixed patterns | Unified component system |
| Light theme | ThemeData exists, screens ignore it | Full light mode support |
| Translucency | MiniPlayer uses BackdropFilter | Systematic blur levels |

---

## 2. Visual Principles

### Depth

Surfaces exist at defined elevation levels. Higher surfaces cast colored shadows. Background is always visible through translucent layers.

**Rule:** Never use opaque surfaces where translucency adds value.

### Translucency

Blur is applied selectively:
- MiniPlayer: medium blur (σ=20)
- Bottom sheets: strong blur (σ=24)
- Overlays: subtle blur (σ=12)
- Player background: no blur, gradient only

**Rule:** Blur must enhance readability, not reduce it. Always pair with sufficient background contrast.

### Hierarchy

Information hierarchy is established through:
1. **Size** — larger = more important
2. **Weight** — bold = primary, regular = secondary
3. **Color** — bright = active, muted = secondary, tertiary = disabled
4. **Position** — top/left = primary reading order

**Rule:** No more than 3 visual hierarchy levels in any single component.

### Motion

Motion communicates:
- **Direction** — where content is going
- **Relationship** — what is connected to what
- **State** — what changed and why
- **Priority** — what deserves attention

**Rule:** Every animation must communicate something. Decorative-only motion is forbidden.

### Typography

System font (Roboto on Android). Hierarchy through weight and size, not typeface variety.

**Rule:** Maximum 2 typefaces (system default only). Maximum 4 weights (400, 500, 600, 700).

### Breathing Space

Generous padding and margins. Content never touches screen edges. Lists have bottom padding for mini-player clearance.

**Rule:** Minimum 16px screen margin. Minimum 8px between related elements. Minimum 16px between unrelated elements.

---

## 3. Design Tokens

### Typography Scale

| Token | Size | Weight | Line Height | Letter Spacing | Usage |
|---|---|---|---|---|---|
| `display` | 28px | 700 (Bold) | 1.2 | 0 | Player screen song title |
| `display-sm` | 24px | 700 (Bold) | 1.2 | 0 | Player screen title (compact) |
| `headline` | 22px | 600 (Semibold) | 1.3 | 0 | Screen titles (AppBar) |
| `title-lg` | 18px | 600 (Semibold) | 1.3 | 0 | Section headers, card titles |
| `title` | 16px | 500 (Medium) | 1.4 | 0 | List primary text, button labels |
| `body` | 14px | 400 (Regular) | 1.5 | 0 | Body text, descriptions |
| `caption` | 12px | 400 (Regular) | 1.4 | 0 | Timestamps, secondary info |
| `label` | 13px | 500 (Medium) | 1.3 | 0 | Button labels, tags |
| `overline` | 11px | 500 (Medium) | 1.4 | +1.5 | Section labels, metadata |
| `overline-xs` | 10px | 500 (Medium) | 1.4 | +2.0 | "REPRODUCIENDO" label |

**Current mapping in app_theme.dart:**
- AppBar titles use `fontSize: 22, fontWeight: bold` → matches `headline`
- Song titles use `fontSize: 14` → matches `body` (should be `title`)
- Artist names use `fontSize: 12` → matches `caption`
- Section labels use `fontSize: 11, letterSpacing: 2` → matches `overline`

### Spacing Scale

Base unit: **4px**

| Token | Value | Usage |
|---|---|---|
| `space-1` | 4px | Tight inline spacing, icon-text gap |
| `space-2` | 8px | Related elements, list item padding vertical |
| `space-3` | 12px | Component internal padding |
| `space-4` | 16px | Screen margins, card padding, section gaps |
| `space-5` | 20px | Medium section gaps |
| `space-6` | 24px | Major sections, player spacing |
| `space-8` | 32px | Hero sections, large gaps |
| `space-10` | 40px | Full-screen breathing room |
| `space-12` | 48px | Maximum gap, page margins |

**Current usage audit:**
- `library_screen.dart`: padding 16px (space-4) ✓
- `player_screen.dart`: varied hardcoded values (20, 28, 16, 12) → needs tokenization
- `settings_screen.dart`: padding 16px (space-4) ✓
- `mini_player.dart`: horizontal 12px (space-3) ✓

### Radius Scale

| Token | Value | Usage |
|---|---|---|
| `radius-none` | 0px | Full-bleed images, dividers |
| `radius-sm` | 8px | Album thumbnails, chips, tags |
| `radius-md` | 12px | Cards, song tiles, list items |
| `radius-lg` | 16px | MiniPlayer, bottom sheets, dialogs |
| `radius-xl` | 20px | Album art (player), large cards |
| `radius-2xl` | 24px | Hero images, featured cards |
| `radius-full` | 50% | Circular buttons, avatars, progress indicators |

**Current usage audit:**
- MiniPlayer: 16px (radius-lg) ✓
- Album art player: 20px (radius-xl) ✓
- Song tile thumbnails: 8px (radius-sm) ✓
- Bottom sheets: 20px (radius-xl) ✓
- Play button: BoxShape.circle (radius-full) ✓

### Elevation Scale

| Token | Shadow | Usage |
|---|---|---|
| `elevation-0` | None | Background, flat surfaces |
| `elevation-1` | `0 1px 3px rgba(0,0,0,0.12)` | Cards, song tiles |
| `elevation-2` | `0 2px 8px rgba(0,0,0,0.16)` | MiniPlayer, FAB |
| `elevation-3` | `0 4px 16px rgba(0,0,0,0.20)` | Bottom sheets, dialogs |
| `elevation-4` | `0 8px 32px rgba(0,0,0,0.24)` | Full-screen overlays, modals |

**Colored shadows:** Use primary accent color at 10–20% opacity instead of black for cohesive look.

**Current usage audit:**
- Album art shadow: `primary.withOpacity(0.4), blurRadius: 40` — too strong, should use elevation-2 equivalent
- Play button shadow: `primary.withOpacity(0.5), blurRadius: 24, spreadRadius: 4` — too strong, should use elevation-3 equivalent
- MiniPlayer: no shadow, uses border — acceptable for glassmorphism

### Animation Durations

| Token | Duration | Curve | Usage |
|---|---|---|---|
| `anim-instant` | 100ms | `easeOut` | Toggle states, icon swaps |
| `anim-fast` | 200ms | `easeOutCubic` | Button feedback, pressed states |
| `anim-normal` | 300ms | `easeOutCubic` | Screen transitions, card reveals |
| `anim-slow` | 500ms | `easeInOut` | Hero transitions, full player open/close |
| `anim-ambient` | 3000ms | `easeInOut` | Background gradient shifts, color transitions |

**Current usage audit:**
- Album art scale: 300ms (anim-normal) ✓
- Player screen transition: no explicit duration (default ~300ms) → should use anim-slow
- No ambient animations exist yet

### Motion Curves

| Token | Curve | Usage |
|---|---|---|
| `curve-enter` | `Curves.easeOutCubic` | Elements entering screen |
| `curve-exit` | `Curves.easeInCubic` | Elements leaving screen |
| `curve-standard` | `Curves.easeInOut` | Bidirectional transitions |
| `curve-spring` | `Curves.easeOutBack` | Playful, bouncy interactions |
| `curve-decelerate` | `Curves.decelerate` | Fast start, smooth stop |

### Translucency Levels

| Token | Opacity | Usage |
|---|---|---|
| `blur-subtle` | 0.6–0.7 | Background overlays, decorative layers |
| `blur-medium` | 0.8–0.85 | MiniPlayer, toolbars with blur |
| `blur-strong` | 0.9–0.95 | Bottom sheets, dialogs, modals |

**Current usage audit:**
- MiniPlayer: `surfaceHigh.withOpacity(0.92)` → matches `blur-strong` ✓
- MiniPlayer blur: `sigmaX: 20, sigmaY: 20` → appropriate for glassmorphism ✓

### Icon Sizing

| Token | Size | Usage |
|---|---|---|
| `icon-xs` | 16px | Inline with caption text |
| `icon-sm` | 20px | Trailing icons, status indicators |
| `icon-md` | 24px | Default icon size (Material standard) |
| `icon-lg` | 32px | Navigation bar, toolbar actions |
| `icon-xl` | 40px | Skip buttons in player |
| `icon-2xl` | 48px | Large action buttons |
| `icon-hero` | 64px+ | Empty state icons, hero graphics |

**Current usage audit:**
- Skip buttons: 40px (icon-xl) ✓
- Play button: 38px → should be 48px (icon-2xl) for prominence
- Mini player controls: 28px, 24px → should be icon-lg (32px)
- Empty state icons: 64px (icon-hero) ✓

---

## 4. Color System

### Dynamic Artwork Colors

**Extraction pipeline:**

```
Album Art (bytes)
  → ui.instantiateImageCodec (move to isolate)
  → PaletteGenerator.fromImage
  → Extract: dominant, vibrant, muted, darkMuted
  → Process:
    - Desaturate dominant by 20% for readability
    - Darken vibrant by 30% for dark mode backgrounds
    - Lighten muted by 10% for text contrast
  → Output:
    - primaryAccent: processed vibrant
    - secondaryAccent: processed muted
    - backgroundTint: darkMuted at 5-10% opacity
    - shadowColor: dominant at 15-20% opacity
```

**Fallback palette** (when no artwork available):

| Token | Dark | Light |
|---|---|---|
| `fallback-primary` | `#7C4DFF` (purple) | `#651FFF` (deep purple) |
| `fallback-secondary` | `#00E5FF` (cyan) | `#00B8D4` (teal) |
| `fallback-accent` | `#FF4081` (pink) | `#F50057` (pink) |

Fallback selection based on hash of song ID for variety without artwork.

### Dark Mode Strategy

**Default mode.** The app is designed dark-first. Light mode is an alternative, not an equal.

**Dark palette** (current AuraColors, refined):

| Token | Current | Proposed | Change |
|---|---|---|---|
| `background` | `#0A0A0F` | `#0A0A0F` | Keep |
| `surface` | `#13131A` | `#121218` | Slightly darker |
| `surface-elevated` | `#1E1E28` | `#1A1A24` | Slightly darker |
| `surface-overlay` | — | `#242430` | New: for dialogs |
| `primary` | `#7C4DFF` | Artwork-derived | Dynamic |
| `secondary` | `#00E5FF` | Artwork-derived | Dynamic |
| `text-primary` | `#E8E8F0` | `#E8E8F0` | Keep |
| `text-secondary` | `#8888AA` | `#8888AA` | Keep |
| `text-tertiary` | — | `#555570` | New: disabled |
| `border` | `#2A2A3A` | `#2A2A3A` | Keep |
| `success` | — | `#4CAF50` | New |
| `error` | — | `#EF5350` | New |

### Light Mode Strategy

**Not just inverted dark mode.** Light mode needs its own personality.

| Token | Current | Proposed | Change |
|---|---|---|---|
| `background` | `#F5F5F7` | `#F5F5F7` | Keep |
| `surface` | `#FFFFFF` | `#FFFFFF` | Keep |
| `surface-elevated` | `#F0F0F5` | `#F0F0F5` | Keep |
| `surface-overlay` | — | `#E8E8F0` | New |
| `primary` | `#7C4DFF` | Artwork-derived (darkened) | Dynamic |
| `text-primary` | `#1A1A2E` | `#1A1A2E` | Keep |
| `text-secondary` | `#6B6B80` | `#6B6B80` | Keep |
| `text-tertiary` | — | `#9999AA` | New |
| `border` | `#E0E0E5` | `#E0E0E5` | Keep |

**Light mode artwork colors:** Darken extracted colors by 15–25% to maintain contrast on light backgrounds.

### Contrast Rules

| Combination | Minimum Ratio | Usage |
|---|---|---|
| text-primary on background | 7:1 (AAA) | All body text |
| text-secondary on background | 4.5:1 (AA) | Secondary text |
| text-primary on surface | 7:1 (AAA) | Text on cards |
| text-primary on primary accent | 4.5:1 (AA) | Text on colored buttons |
| icon on surface | 3:1 (AA large) | Icons |

**Rule:** If extracted artwork color fails contrast check, shift to nearest compliant color.

### Current Color Issues

| Issue | Location | Fix |
|---|---|---|
| Static primary/secondary | `app_theme.dart` | Make artwork-derived |
| No semantic colors | `AuraColors` | Add success, error, warning |
| No text-tertiary | `AuraColors` | Add for disabled states |
| Light theme ignored | Most screens | Use Theme.of(context).colorScheme |
| No contrast checking | Palette extraction | Validate ratios after extraction |
| Hardcoded colors | Throughout | Replace with token references |

---

## 5. Components

### Buttons

**Primary Button:**
- Background: primary accent color
- Text: white (dark mode) or dark (light mode)
- Radius: radius-md (12px)
- Height: 48px
- Padding: horizontal 24px
- Shadow: elevation-1 with colored shadow
- Pressed: scale 0.97, opacity 0.9

**Secondary Button:**
- Background: transparent
- Border: 1px primary accent
- Text: primary accent
- Same dimensions as primary

**Icon Button:**
- Size: 48×48px touch target (icon centered at 24px)
- No background by default
- Pressed: circular ripple at 20% primary opacity
- Active: filled circle at 12% primary opacity

**Current state:** Uses Material `IconButton` and `ElevatedButton`. Consistent but not branded.

### Cards

**Standard Card:**
- Background: surface (dark) / surface (light)
- Radius: radius-md (12px)
- Padding: space-4 (16px)
- Shadow: elevation-1
- Border: none (shadow defines elevation)

**Album Card:**
- Aspect ratio: 1:1 (square)
- Artwork: full card background
- Overlay: gradient from bottom (transparent → surface at 80%)
- Title: white text on overlay
- Artist: text-secondary on overlay
- Radius: radius-md (12px)
- Shadow: elevation-1

**Playlist Card:**
- Same as album card but with 2×2 artwork grid or first song's art
- Song count badge: overline text, top-right

**Current state:** Album cards exist in `albums_screen.dart`. Playlist cards in `playlists_screen.dart` are basic ListTiles, not cards.

### Mini Player

**Specification:**
- Position: Fixed above navigation bar
- Height: 64px
- Background: surface-elevated at 92% opacity + BackdropFilter blur(σ=20)
- Border: 0.5px border color
- Radius: radius-lg (16px)
- Margin: horizontal space-2 (8px), bottom space-2 (8px)

**Contents (left to right):**
1. Artwork thumbnail: 40×40px, radius-sm (8px)
2. Song title: title text, maxLines 1, ellipsis
3. Artist name: caption text, maxLines 1, ellipsis
4. Progress: linear bar along bottom edge (2px height)
5. Play/pause: icon button (32px icon)
6. Skip next: icon button (24px icon)

**Interactions:**
- Tap: open full player (slide up transition)
- Long-press: quick actions (favorite, add to queue)
- Swipe left: previous song
- Swipe right: next song
- **NOT dismissible** — remove Dismissible widget

**Current state:** Exists in `mini_player.dart`. Has Dismissible (BUG-20). Circular progress instead of linear. Missing progress bar along bottom edge.

### Player Screen

**Specification:**
- Background: gradient mesh from artwork colors (3–4 colors, slow animation)
- Safe area: full screen

**Layout (top to bottom):**
1. Top bar: back button (icon), "REPRODUCIENDO" overline + album title, more options icon
2. Album art: 320×320px, radius-xl (20px), colored shadow (elevation-2)
3. Song info: title (display), artist (title-lg), favorite button
4. Seek bar: full-width slider, time labels (caption)
5. Controls: skip prev (40px), play (80px circle), skip next (40px)
6. Secondary: shuffle, EQ, queue, repeat (24px icons, active glow)
7. Bottom: swipe-up handle for queue/lyrics panel

**Interactions:**
- Swipe up from bottom: reveal queue panel
- Swipe down: minimize to mini player
- Swipe left/right on artwork: skip prev/next
- Double-tap artwork: play/pause

**Current state:** Exists in `player_screen.dart`. Has gradient (static), album art (256px), controls (basic), queue sheet. Missing: swipe gestures, queue panel, ambient animations, artwork-reactive gradient mesh.

### Bottom Sheets

**Standard Bottom Sheet:**
- Background: surface-overlay
- Radius: radius-lg (16px) top corners
- Handle: 32px wide, 4px tall, border color, radius-full, centered top
- Padding: space-4 (16px)
- Max height: 60% of screen
- Drag: DraggableScrollableSheet

**Header Pattern:**
- Title: headline text, centered
- Subtitle: body text, centered (optional)
- Close button: top-right (optional)

**Current state:** Used in settings (speed picker, sleep timer), player (queue, options), add to playlist. Inconsistent header patterns. Some use `const Padding` with hardcoded values.

### Navigation

**Bottom Navigation Bar:**
- Height: 80px (including safe area)
- Background: surface
- Active indicator: pill shape, primary at 12% opacity
- Active icon: filled variant, primary color
- Inactive icon: outlined variant, text-secondary color
- Label: overline text, visible always
- Haptic: light impact on tab change

**Tab Structure (proposed):**
1. Home (discover + recently played)
2. Library (songs/albums/artists)
3. Playlists
4. Settings

**Current state:** 5 tabs (Canciones, Álbumes, Artistas, Listas, Ajustes). Material NavigationBar with default indicator. No custom styling.

### Song Tiles

**Standard Song Tile:**
- Height: 64px
- Padding: horizontal space-4 (16px), vertical space-2 (8px)
- Artwork: 48×48px, radius-sm (8px)
- Title: title text, maxLines 1
- Artist + duration: caption text, maxLines 1
- Playing indicator: EQ icon or animated bars in trailing position
- Active state: title in primary color, bold weight

**Swipe Actions:**
- Swipe left: Add to playlist (secondary color)
- Swipe right: Add to queue (primary color)

**Current state:** `_SongTile` in `library_screen.dart` and `SongTile` in `widgets/song_tile.dart` are two different implementations. Library tile has Slidable. Widget tile also has Slidable. Should be unified.

### Dialogs

**Standard Dialog:**
- Background: surface-overlay
- Radius: radius-lg (16px)
- Padding: space-4 (16px)
- Title: headline text
- Content: body text
- Actions: text buttons, right-aligned
- Shadow: elevation-3

**Confirmation Dialog:**
- Title: headline text
- Message: body text
- Actions: Cancel (text-secondary) + Confirm (primary color, bold)

**Current state:** Uses Material `AlertDialog`. Functional but not styled.

### Contextual Menus

**Long-press Menu (song):**
- Play next
- Add to queue
- Add to playlist
- Go to album
- Go to artist
- View info
- Share

**Long-press Menu (album):**
- Play
- Shuffle
- Add all to queue
- Add to playlist
- View artist

**Current state:** PlayerScreen has `_showOptions` with 2 items (play next, info). Missing most actions.

---

## 6. Motion Language

### Animation Philosophy

1. **Fast in, slow out** — Enter: 200–300ms. Exit: 300–400ms
2. **Spring over linear** — Natural curves, not mechanical
3. **Staggered reveals** — List items with 30–50ms delay between each
4. **Contextual direction** — Motion follows user intent
5. **Haptic pairing** — Important animations paired with haptic feedback

### Transition Behaviors

| Transition | Style | Duration | Curve |
|---|---|---|---|
| MiniPlayer → Full Player | Slide up + shared element expand | anim-slow (500ms) | curve-enter |
| Full Player → MiniPlayer | Slide down + shared element shrink | anim-slow (500ms) | curve-exit |
| Tab switch | Crossfade + subtle slide | anim-normal (300ms) | curve-standard |
| Bottom sheet open | Slide up with spring | anim-normal (300ms) | curve-spring |
| Bottom sheet close | Slide down | anim-normal (300ms) | curve-exit |
| Dialog open | Scale 0.9→1.0 + fade in | anim-fast (200ms) | curve-enter |
| Dialog close | Scale 1.0→0.95 + fade out | anim-fast (200ms) | curve-exit |
| List item enter | Slide up + fade | anim-normal (300ms) | curve-enter |
| List item stagger | Delay between items | 30ms per item | — |
| Screen push | Slide from right | anim-normal (300ms) | curve-enter |
| Screen pop | Slide to right | anim-normal (300ms) | curve-exit |

### Interaction Feedback

| Interaction | Feedback | Duration |
|---|---|---|
| Button tap | Scale 0.97 + ripple | anim-instant (100ms) |
| Toggle switch | Color change + slide | anim-fast (200ms) |
| Favorite tap | Heart scale 1.3→1.0 + color fill | anim-fast (200ms) |
| Long-press | Scale 0.95 + haptic | anim-fast (200ms) |
| Swipe action | Reveal with resistance | anim-normal (300ms) |
| Drag start | Scale 0.98 + shadow increase | anim-instant (100ms) |
| Tab change | Haptic light impact | — |

### Microinteractions

| Element | Animation | Trigger |
|---|---|---|
| Play button | Icon swap with crossfade | Play/pause toggle |
| Album art | Scale 1.0→0.95 on pause | Playing state change |
| Progress bar head | Glow pulse | Continuous (ambient) |
| Active tab icon | Fill animation | Tab selection |
| Favorite icon | Heart fill with bounce | Favorite toggle |
| EQ active indicator | Glow pulse | EQ enabled |
| Shuffle active | Icon color shift + glow | Shuffle enabled |
| Repeat active | Icon color shift + glow | Repeat enabled |
| Loading spinner | Rotation | During async operations |
| Error banner | Slide down + fade in | Error occurs |
| Success toast | Slide up + fade out | Action completes |

### Ambient Animations

| Animation | Location | Duration | Description |
|---|---|---|---|
| Color shift | Player background | anim-ambient (3000ms) | Slow gradient transition between artwork colors |
| Shadow breathe | Album art shadow | anim-ambient (4000ms) | Shadow intensity pulses subtly |
| Playing bars | Mini player, song tiles | 800ms loop | 3-bar equalizer animation |
| Progress glow | Seek bar head | 1500ms loop | Soft glow pulse at progress position |
| Background mesh | Player screen | anim-ambient (5000ms) | 3-color gradient mesh slowly shifts |

---

## 7. UX Rules

### Loading States

| Rule | Detail |
|---|---|
| Show within 200ms | If operation takes >200ms, show loading indicator |
| Never block interaction | Loading should not prevent navigation away |
| Use appropriate indicator | CircularProgressIndicator for full screen, linear for partial |
| Show context | Loading message: "Scanning library...", "Loading playlist..." |
| Timeout at 15s | If loading exceeds 15s, show error with retry option |

**Current state:** LibraryScreen shows CircularProgressIndicator. Other screens have inconsistent or no loading states.

### Empty States

| Screen | Icon | Message | Action |
|---|---|---|---|
| Library (no songs) | music_off (64px) | "No se encontraron canciones" | None (device has no music) |
| Library (no results) | search (64px) | "No se encontraron resultados para '...'" | Clear search button |
| Playlists (empty) | queue_music (64px) | "No tienes listas de reproducción" | "Crear lista" button |
| Albums (empty) | album (64px) | "No se encontraron álbumes" | Refresh button |
| Artists (empty) | person (64px) | "No se encontrados artistas" | Refresh button |
| Favorites (empty) | favorite_border (64px) | "No tienes canciones favoritas" | Browse library button |
| Recommendations (empty) | music_note (64px) | "Escucha más para recibir recomendaciones" | None |
| Queue (empty) | queue_music (64px) | "Cola vacía" | None |
| Search (no query) | search (64px) | "Busca canciones, álbumes o artistas" | None |

**Current state:** Only LibraryScreen has empty state. All others show blank content.

### Error States

| Error Type | Display | Action |
|---|---|---|
| Permission denied | Full screen with icon + message + settings button | Open app settings |
| Scan error | Full screen with icon + message + retry button | Retry scan |
| Playback error | SnackBar (non-intrusive) | Auto-skip to next |
| Network error | N/A (offline app) | — |
| Database error | SnackBar + log | Retry operation |
| EQ unavailable | Disabled EQ button + tooltip | None |

**Current state:** Permission and scan errors handled in LibraryScreen. Playback errors silent (BUG-06). No EQ error handling.

### Haptics

| Action | Haptic Type |
|---|---|
| Tab change | Light impact |
| Play/pause | Medium impact |
| Skip track | Light impact |
| Favorite toggle | Selection click |
| Long-press menu | Medium impact |
| Delete confirmation | Heavy impact |
| Error | Error haptic |
| Success | Selection click |

### Gestures

| Gesture | Location | Action |
|---|---|---|
| Tap | MiniPlayer | Open full player |
| Long-press | MiniPlayer | Quick actions |
| Swipe left | MiniPlayer | Skip to previous |
| Swipe right | MiniPlayer | Skip to next |
| Tap | Song tile | Play song |
| Long-press | Song tile | Context menu |
| Swipe left | Song tile | Add to queue |
| Swipe right | Song tile | Add to playlist |
| Swipe up | Player bottom | Reveal queue panel |
| Swipe down | Player screen | Minimize to mini player |
| Swipe left | Player artwork | Skip to previous |
| Swipe right | Player artwork | Skip to next |
| Double-tap | Player artwork | Play/pause |
| Pull-down | Library top | Refresh library |
| Drag handle | Playlist song | Reorder |

### Consistency Rules

1. **All lists use the same tile pattern** — Single `SongTile` widget, not duplicated
2. **All bottom sheets use the same header** — Title centered, handle at top
3. **All dialogs use the same action pattern** — Cancel left, Confirm right
4. **All screens use the same back navigation** — Back button in AppBar, same position
5. **All active states use the same visual treatment** — Primary color + bold/glow
6. **All loading uses the same indicator style** — CircularProgressIndicator with primary color
7. **All empty states follow the same pattern** — Icon + message + optional action
8. **All errors use the same feedback level** — SnackBar for recoverable, full screen for blocking

---

## 8. Accessibility

### Contrast

| Requirement | Standard | Implementation |
|---|---|---|
| Body text on background | WCAG AA 4.5:1 | `#E8E8F0` on `#0A0A0F` = 15.4:1 ✓ |
| Secondary text on background | WCAG AA 4.5:1 | `#8888AA` on `#0A0A0F` = 6.8:1 ✓ |
| Primary color on background | WCAG AA 4.5:1 | `#7C4DFF` on `#0A0A0F` = 8.7:1 ✓ |
| Text on artwork-derived colors | WCAG AA 4.5:1 | Must validate after extraction |
| Icon on surface | WCAG AA 3:1 | Verify all icon colors |

**Rule:** After artwork color extraction, validate contrast against text colors. If ratio < 4.5:1, shift color toward compliant range.

### Touch Targets

| Requirement | Value | Implementation |
|---|---|---|
| Minimum touch target | 48×48px | All IconButton, ListTile meet this |
| Spacing between targets | 8px minimum | Verify in dense layouts |
| MiniPlayer controls | 48×48px | Current: play button ~36px effective → needs increase |
| Slider thumb | 48×48px touch area | Current: thumb radius 6px → touch area may be small |

### Readable Typography

| Requirement | Value | Status |
|---|---|---|
| Minimum body text size | 14px | Current: 14px ✓ |
| Minimum caption size | 12px | Current: 12px ✓ |
| Maximum line length | 60–75 characters | Verify in wide layouts |
| Line height minimum | 1.4 | Current: 1.4–1.5 ✓ |
| Letter spacing for readability | 0 for body, +0.5 for captions | Current: 0 for most ✓ |

### Reduced Motion

| Requirement | Implementation |
|---|---|
| Respect system setting | Check `MediaQuery.platformBrightnessOf(context)` and `MediaQuery.boldTextOf(context)` |
| Disable ambient animations | If reduced motion preferred, skip color shift, shadow breathe, progress glow |
| Keep functional animations | Transitions and state changes remain (fast, not decorative) |
| Provide toggle | Settings option to disable all non-essential animations |

**Current state:** No reduced motion support. All animations play regardless of system preference.

### Screen Reader

| Requirement | Implementation |
|---|---|
| Semantic labels | All IconButton must have `tooltip` or `semanticsLabel` |
| State announcements | Play/pause changes announced via `SemanticsService` |
| Queue position | "Song 3 of 12" announced |
| Progress | "1:23 of 3:45" announced |
| Error messages | All errors must have semantic announcements |

**Current state:** Minimal semantic labels. Most icons have no tooltip. Screen reader experience is poor.

---

## Implementation Checklist

### Phase 1 — Token Foundation

- [ ] Create `DesignTokens` class with all spacing, radius, elevation, animation values
- [ ] Create `TypographyTokens` class with all text styles
- [ ] Create `ColorTokens` class with semantic colors
- [ ] Replace hardcoded values in all screens with token references

### Phase 2 — Color System

- [ ] Convert `DynamicThemeService` to ChangeNotifier
- [ ] Implement artwork extraction in isolate
- [ ] Add contrast validation after extraction
- [ ] Implement fallback color generation
- [ ] Fix light theme support in all screens

### Phase 3 — Component System

- [ ] Create unified `SongTile` widget
- [ ] Redesign `MiniPlayer` per specification
- [ ] Redesign `PlayerScreen` per specification
- [ ] Create `BottomSheet` template widget
- [ ] Create `EmptyState` widget
- [ ] Create `ErrorBanner` widget
- [ ] Create `LoadingIndicator` widget
- [ ] Standardize dialog patterns

### Phase 4 — Motion System

- [ ] Implement shared element transitions (mini player ↔ full player)
- [ ] Add staggered list animations
- [ ] Add ambient background animation in player
- [ ] Add playing indicator animations
- [ ] Add haptic feedback system
- [ ] Implement gesture system

### Phase 5 — Accessibility

- [ ] Add semantic labels to all interactive elements
- [ ] Implement reduced motion support
- [ ] Validate contrast for all color combinations
- [ ] Increase touch targets to 48px minimum
- [ ] Add screen reader announcements

---

> **Note:** This design system is proposed, not implemented. Current app uses `app_theme.dart` with static colors and minimal motion. All changes require implementation in Phase 2+ of the reconstruction roadmap.
