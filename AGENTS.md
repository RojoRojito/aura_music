# AGENTS.md — Aura Music Player

## Build & CI

- CI runs on every push to `master` via GitHub Actions (`.github/workflows/build.yml`)
- **Analyzer command**: `flutter analyze --no-fatal-infos` — infos are ignored, warnings/errors fail the build
- **Build command**: `flutter build apk --release`
- Android folder is regenerated from scratch on CI (manifest preserved, kotlin version patched to 1.9.22)
- **Required order**: `flutter pub get` → `flutter analyze --no-fatal-infos` → `flutter build apk`

## Project Structure

- **Entry point**: `lib/main.dart` — initializes AudioService, SettingsController, PlayerController
- **State management**: Provider (no Riverpod/Bloc)
- **Audio**: `just_audio` + `audio_service` for background playback
- **Persistence**: SharedPreferences for settings and queue state
- **Database**: sqflite for playlists (see `lib/data/repositories/playlist_repository.dart`)

## Common Pitfalls Fixed

- String interpolation uses `$` not `\$` — 6 bugs were fixed (escaped dollar signs appeared as literal text)
- `MaterialStateProperty` deprecated → use `WidgetStateProperty`
- `background` in ColorScheme deprecated → use `surface`
- Unused imports cause warnings → keep imports minimal
- Artist name `?? 0` dead expression when `numberOfTracks` is non-nullable in on_audio_query

## Key Files

- `lib/services/audio_handler.dart` — audio queue, playback, error stream
- `lib/services/media_scanner.dart` — returns `ScanResult` with status enum (noPermission, error, success)
- `lib/services/state_persistence_service.dart` — queue serialization for session restore
- `lib/features/settings/settings_controller.dart` — sleep timer with Timer countdown

## Conventions

- Use `notifyListeners()` after async operations in controllers
- Sleep timer: `SettingsController` owns the Timer; `PlayerController` listens via stream
- Queue persistence: auto-saves on every `_queueChangeController.add(null)`
- All `ChangeNotifier` subclasses must call `dispose()` to cancel streams