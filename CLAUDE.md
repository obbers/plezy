# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment

Prepend these to `PATH` before running any build or device commands:

```
/opt/flutter/bin
/opt/android-sdk/platform-tools
```

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run a specific test file
flutter test test/path/to/test_file.dart

# Run all tests
flutter test

# Static analysis (must pass before merging)
flutter analyze

# Format Dart files
dart format .

# Format native files (Kotlin, Swift, C++, etc.)
scripts/format_native.sh --fix

# Run all CI checks locally (formatting, codegen freshness, analysis, unused code/files)
scripts/ci_checks.sh

# Code generation (run after modifying model classes annotated with @freezed, @JsonSerializable, or Drift table definitions)
scripts/codegen.sh

# Regenerate i18n after modifying lib/i18n/*.i18n.json
dart run slang

# Install pre-commit hooks
scripts/setup_hooks.sh
```

## Architecture

Plezy is a Flutter media client for Plex and Jellyfin targeting Android, iOS, tvOS, macOS, Windows, and Linux.

### Backend abstraction

`lib/media/media_server_client.dart` defines the abstract `MediaServerClient` interface — the single surface the rest of the app uses to browse libraries, fetch items, and report playback. Concrete implementations live in `lib/services/plex_client/` (Plex) and `lib/services/jellyfin_client/` (Jellyfin). Providers and UI must consume `MediaServerClient`, not the concrete clients.

Read methods are prefixed `fetch*`. Write methods (`markWatched`, `rate`, etc.) throw `MediaServerHttpException` on HTTP errors and return `false` on "not applicable" without throwing.

### Connection and profile system

`lib/connection/` handles authentication and server connectivity. A `Connection` is either a `PlexAccountConnection` (one Plex account + discovered servers + optional Home profile) or a `JellyfinConnection` (single server + user).

`lib/profiles/` manages multi-user profiles. A `Profile` is either a `LocalProfile` (Plezy-created, optional PIN) or a `PlexHomeProfile` (auto-surfaced from Plex Home). Profiles own connections via a join table.

### State management

Provider (`package:provider`) is used throughout. Providers live in `lib/providers/`. Key providers: `LibrariesProvider`, `PlaybackStateProvider`, `DownloadProvider`, `ThemeProvider`, `WatchStateStore`, `MultiServerProvider`.

### Video player

`lib/mpv/` wraps a platform-specific mpv engine with a unified Dart API. Platform implementations are in `lib/mpv/player/platform/`. `VideoPlayerScreen` (`lib/screens/video_player_screen.dart`) orchestrates playback; logic is split across mixins in `lib/screens/video_player/parts/` (seeking, episode navigation, Live TV, Watch Together, etc.).

### Database

`lib/database/` uses Drift (type-safe SQLite). `AppDatabase` (`app_database.dart`) + `tables.dart` define the schema. Stable string `id` getters are used for enum persistence — do not use `.name` for values stored in the database.

### i18n

Translations use `slang`. Source strings live in `lib/i18n/strings.i18n.json`; other locales follow the `[locale].i18n.json` pattern. Use `t.section.key` in code. Run `dart run slang` after any JSON change.

### Code generation

Models annotated with `@freezed` or `@JsonSerializable` have generated `.freezed.dart` and `.g.dart` counterparts. Run `scripts/codegen.sh` after modifying annotated files. CI fails if generated files are stale.

### Other components

- `server/` — Go WebSocket relay server for the Watch Together feature (separate from the Flutter app)
- `shared/apple/` and `shared/cpp/` — native code shared across platforms
- `website/` — Svelte marketing site (separate npm project)

## Release process (Android)

Build per-architecture APKs locally and deploy directly — do not use GitHub Actions for releases.

```bash
# 1. Fetch and merge upstream
git fetch upstream
git merge upstream/main --allow-unrelated-histories --no-edit

# 2. Bump version in pubspec.yaml (e.g. 2.7.1+117)

# 3. Build (produces separate APKs per ABI)
flutter build apk --release --split-per-abi

# 4. Push APKs to test devices
ADB=/opt/android-sdk/platform-tools/adb
$ADB -s <device-ip>  install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
$ADB -s <device-ip>  install -r build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
$ADB -s <device-ip>  install -r build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
$ADB -s <device-ip> install -r build/app/outputs/flutter-apk/app-x86_64-release.apk

# 5. Copy APKs to web server and update manifest
#    (paths are in .claude/deploy-paths.md — local only, not committed)

# 6. Commit and push to fork
git add pubspec.yaml
git commit -m "chore: bump version to <version>"
git push origin main
```

Test device addresses and ABI mappings are in `.claude/test-devices.md` (local only, not committed).

## Code style

- Line width: 120 characters (configured in `analysis_options.yaml` and enforced by `dart format`)
- `analysis_options.yaml` enables `dart_code_linter` with the recommended preset plus Flutter-specific rules. Generated files (`*.g.dart`, `*.freezed.dart`) are excluded from analysis and formatting checks.
- Warnings are treated as failures in CI.
