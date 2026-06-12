# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

Build a fat APK locally and deploy it directly — do not use GitHub Actions for releases.

```bash
# 1. Bump version in pubspec.yaml (e.g. 2.6.1+113)

# 2. Build
flutter build apk --release

# 3. Copy APK
cp build/app/outputs/flutter-apk/app-release.apk <deploy-path>

# 4. Update <deploy-path>
#    Set "version" to the new pubspec version string (e.g. "2.6.1+113")
#    Set "published_at" to current UTC time in ISO 8601 format
#    Leave "count" unchanged
```

`plezy.json` shape:
```json
{
  "count": <leave unchanged>,
  "version": "<versionName>+<versionCode>",
  "published_at": "<UTC ISO 8601>"
}
```

## Code style

- Line width: 120 characters (configured in `analysis_options.yaml` and enforced by `dart format`)
- `analysis_options.yaml` enables `dart_code_linter` with the recommended preset plus Flutter-specific rules. Generated files (`*.g.dart`, `*.freezed.dart`) are excluded from analysis and formatting checks.
- Warnings are treated as failures in CI.
