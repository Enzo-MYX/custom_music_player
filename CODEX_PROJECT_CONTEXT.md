# Codex Project Context — Custom Music Player

## Purpose

Personal-only Flutter/Dart Android music player for the user's Android phone and Xiaomi Android tablet. No online search/streaming, accounts, ads, cloud sync, market-driven features, or unnecessary UI/configuration. Use IntelliJ IDEA Community Edition.

The core custom feature is an efficient random-play system based on user-defined folder collections.

## Core requirements

- User chooses a global root directory.
- All library operations are scoped to that root.
- Folder navigation must never leave the root.
- Files in the chosen root environment can be assumed to be valid music files.
- Libraries are **recipes/command sets**, similar to a `.gitignore`, not permanent playlists.
- Multiple library recipes may be stored.
- Only one library is loaded into the scanner at a time.
- A built song list should be stored at most once to avoid unnecessary memory use.
- Music files may total tens of GB and a library may contain 2000+ songs.
- Do not load audio contents into memory just to build a playlist.
- Random selection should give songs equal opportunity; either precomputed shuffle order or on-demand next-song selection is acceptable.
- Current scan performance: about 6–7 seconds for 2017 songs on the test device. This is acceptable enough to proceed; do not rewrite the scanner without a concrete significant optimization.

## Library semantics

A library consists of commands such as:

```text
+ Anime
- Anime/Remixes
+ Anime/Remixes/Favourites
```

Command display must remain concise directory syntax only.

The root `/` is **never** a valid command.

Instead each library has a default build mode:

```dart
LibraryBuildMode.includeAll
LibraryBuildMode.includeNone
```

UI representation:

```text
Include everything by default [switch]
```

Most-specific applicable command wins. More-specific paths override less-specific ancestor paths.

For the extremely unlikely exact-path contradiction:

```text
+ Some/Path
- Some/Path
```

the configuration must not become invalid as a whole. When commands are added/bulk-added, unaffected commands should still be accepted and conflicting paths should be resolved safely, preferably with a user Include/Exclude decision. Newest explicit change may override an old exact-path command.

## Existing technology

Flutter/Dart on Android.

Playback packages currently in use:

```yaml
just_audio: ^0.10.6
audio_service: ^0.18.19
```

SAF package:

```yaml
saf: ^2.1.0
```

Important API facts already established:
- `Saf.hasPersistedPermission` does not exist in this installed version.
- Persisted grants are obtained through `_saf.persistedPermissions()`.
- Root retrieval uses `_saf.stat(rootUri)`; do not pass a second positional argument.

## Existing models

Relevant models:

- `AppSettings`
- `BuildMode` / `build_mode.dart`
- `LibraryCommand`
- `LibraryState`
- `MusicLibrary`
- `Song`

`Song` also carries the SAF-backed `uri` and a `relativePath`, so playback
does not need to rescan the filesystem or load audio data into memory.

Filename notes:
- command matcher file is `command_matcher.dart`
- build mode file is `build_mode.dart`
- class names were not changed.

`LibraryCommand`:
- fields: `bool include`, `String path`
- normalizes path through `PathUtils.normalize`
- normalized empty path is invalid and throws `ArgumentError`
- display is only `+ path` or `- path`
- has `toJson()` / `fromJson()`.

## Existing services

- `LibraryScanner`
- `LibraryManager`
- `SettingsStorage`
- command matcher
- `PathUtils`

### LibraryScanner

Already tested successfully:
- recursively scans a `SafDocumentFile` root
- applies a `MusicLibrary`
- returns `List<Song>`
- 2017-song scan takes roughly 6–7 seconds
- performance accepted for now

### LibraryManager

Current manager supports:
- `load()`
- `setRoot(SafDocumentFile root)`
- `getRoot()`
- `selectLibrary(String name)`
- `addLibrary(MusicLibrary library)`
- `renameLibrary(...)`
- `deleteLibrary(String name)`
- `rebuildSelectedLibrary()`

`getRoot()` checks persisted SAF permissions and retrieves the root. Root URI is stored in `AppSettings.rootUri`.

The editor needs a generic `updateLibrary(MusicLibrary library)` method. It should:
1. verify the library exists;
2. replace only that library in the settings list;
3. preserve the global root URI;
4. preserve selected library name;
5. save with `SettingsStorage`;
6. clear the current built song list because the recipe changed.

## Current UI

`LibraryManagerScreen` already:
- loads manager state
- displays/changes root
- lists libraries
- creates libraries
- selects libraries
- renames libraries
- deletes libraries
- rebuilds selected library

The existing library popup menu currently has Rename/Delete. Add:

```text
Edit
Rename
Delete
```

Edit flow:

```text
LibraryManagerScreen
    -> manager.getRoot()
    -> LibraryEditorScreen
```

Pass:
- `LibraryManager`
- selected `MusicLibrary`
- `SafDocumentFile root`

If no valid root exists, show an error instead of opening the editor.

## Folder browser

`PathSelectorScreen` exists and has been tested.

Normal flow:

```text
root
 -> navigate inside root
 -> select current folder
 -> return relative path
```

Root itself cannot be selected as a command.

Bulk mode is implemented and tested:
- "Bulk Select" appears above "Select This Folder"
- entering bulk mode locks the current folder scope
- selected folders/files retain relative paths
- the normal folder-selection button becomes the batch confirmation button
- the native Android Back action exits bulk mode while remaining in the same
  folder

## Test scanner

`TestScannerScreen` was created and tested for SAF scanning and folder-browser behavior. It is a temporary test screen, not the final app entry point.

`main.dart` normally launches:

```dart
LibraryManagerScreen(
  manager: manager,
)
```

The test scanner was temporarily used as the app home during testing.

## Completed milestones

- Flutter project setup
- Android emulator testing
- data models
- library command representation/serialization
- path normalization
- root command rejection
- build modes
- command matching/trie direction
- global root selection
- persisted root handling
- recursive SAF scanning
- `saf: ^2.1.0` compatibility fixes
- 2017-song scan test
- `PathSelectorScreen`
- navigation constrained to root
- single-folder selection
- multiple library recipes
- selecting/adding/renaming/deleting libraries
- rebuilding selected library
- Library Editor integration, command addition/deletion, persistence, and
  `updateLibrary()`
- bulk folder/file selection
- exact-path conflict resolution without discarding unaffected commands
- playback screen and foreground playback
- background audio service
- notification media controls
- lock-screen media controls
- draggable playback seek/progress bar
- automatic queue advancement
- repeat off/all/one behavior
- dedicated shuffle start screen and library selector
- explicit built-library/rebuild-state tracking
- randomized index order with non-repeating cycles
- shuffle integration with Previous, Next, completion, and repeat modes
- looping three-page home carousel with cube transition and position indicator
- persistent carousel mini-player, including collapse/expand and draggable icon
- responsive portrait/landscape playback layouts without overflow
- five-second rewind/forward and selectable playback speeds
- current-playlist screen with automatic scrolling to the active track
- non-shuffle playlist track selection
- lazy current-track metadata and embedded-artwork extraction through Android
  `MediaMetadataRetriever` (implemented; broader format/device testing pending)
- latest-built-library persistence using lightweight song paths and SAF URIs
  (implemented; restart/invalidation testing pending)

## Next stages

### Built-library persistence validation — next

The most recent successfully built library is now serialized separately from
normal settings. Only its library name, root URI, recipe signature, and each
song's relative path/SAF URI are stored; metadata and artwork are excluded.

Still test:
- build, fully restart, and start shuffle without rescanning;
- a valid empty built library;
- switching away from and back to the cached library;
- invalidation after root changes or edits to the built recipe;
- preservation after edits to unrelated recipes;
- rename and deletion of the cached library;
- corrupt or version-mismatched cache fallback.

### Metadata and playback validation

Current-track metadata is loaded lazily through Android
`MediaMetadataRetriever`, including title, artist, album, and embedded artwork.
The lightweight `Song` list does not retain metadata or artwork for every track.

Still test and refine:
- metadata extraction for MP3, FLAC, and other formats actually used;
- files with missing or malformed tags and missing artwork;
- rapid Previous/Next changes while metadata extraction is still running;
- metadata updates in the app, media notification, and lock screen;
- playback-speed reporting and persistence across track changes;
- portrait/landscape rotation while playing and paused.

### Remaining playback and queue work

- Decide whether shuffled playback should expose its shuffled order as a queue;
  the queue button is currently disabled during shuffle.
- Decide whether selecting the currently playing queue row should restart it or
  only close the queue; it currently closes the queue.
- Consider caching only small current-track metadata if native extraction delay
  is noticeable; do not cache artwork for the entire library.
- Complete lyrics only if explicitly requested; it remains a placeholder.

### Remaining carousel work

- Decide the purpose of the intentionally empty right-hand carousel page.
- Test cube transitions and draggable mini-player placement on both target
  devices and after orientation changes.
- Decide whether the collapsed state and draggable icon position should persist
  between app launches.

### Cleanup and release

- Remove temporary audio-service and player `debugPrint` logging.
- Delete unreferenced temporary scanner/settings test screens if still present.
- Run `flutter analyze` and resolve warnings and unused imports.
- Run the complete unit/widget test suite.
- Perform regression testing for large/empty libraries, stale rebuild routing,
  repeat modes, full shuffle cycles, notification controls, lock-screen
  controls, backgrounding, reopening, and SAF permission persistence.
- Test on the target phone and Xiaomi tablet.
- Configure release signing and produce the release APK.

## Architectural rules

1. Personal-use project; do not add market-oriented features.
2. No online functionality unless explicitly requested.
3. No ads.
4. Preserve the global root concept.
5. A library is a recipe, not the built song list.
6. Only one library is loaded into the scanner at a time.
7. Do not duplicate large song lists unnecessarily.
8. Never use `/` as a command.
9. Use includeAll/includeNone as the default.
10. Most-specific command wins.
11. Exact contradictory commands must never invalidate unrelated configuration.
12. Keep command display to directory syntax only.
13. Folder navigation cannot escape the configured root.
14. Respect the installed `saf: ^2.1.0` API.
15. Prefer minimal targeted changes to tested files.
16. Do not assume nonexistent methods/APIs.
17. Test each milestone before moving on.

## Known mistakes to avoid

Do not use:

```dart
manager.saveLibrary(...)
```

Use the planned:

```dart
manager.updateLibrary(...)
```

Do not use:

```dart
_saf.hasPersistedPermission(...)
```

Use the existing persisted-permission/stat pattern.

Do not assume `SafDocumentFile.isDir` exists; the installed SAF API differs from some examples online.

## Suggested repository structure

```text
lib/
├── main.dart
├── models/
│   ├── app_settings.dart
│   ├── build_mode.dart
│   ├── library_command.dart
│   ├── library_state.dart
│   ├── music_library.dart
│   └── song.dart
├── screens/
│   ├── library_manager_screen.dart
│   ├── library_editor_screen.dart
│   ├── path_selector_screen.dart
│   └── test_scanner_screen.dart
└── services/
    ├── command_matcher.dart
    ├── library_manager.dart
    ├── library_scanner.dart
    ├── path_utils.dart
    └── settings_storage.dart
```

## Instructions for Codex

When continuing:
1. Inspect the actual repository first; repository state overrides this document if it is newer.
2. Preserve already-tested behavior.
3. Make small, coherent changes.
4. Do not replace whole screens unnecessarily.
5. Verify the actual installed package APIs before guessing.
6. Avoid new dependencies unless needed.
7. Keep UI simple and aligned with explicitly requested behavior.
8. Run/analyze/test relevant Flutter code after changes.
9. Work through the staged roadmap rather than jumping to speculative features.

**Immediate task:** device-test the newly implemented built-library persistence,
including restart restoration and every invalidation path. Then validate lazy
metadata extraction across the user's actual audio formats while preserving the
tested playback, shuffle/repeat, notification, and lock-screen behavior.
