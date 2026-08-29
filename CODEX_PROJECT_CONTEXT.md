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

## Next stages

### Playback refinement — next

Foreground and background playback are working with `just_audio` and
`audio_service`:
- selected/rebuilt libraries are passed to `PlaybackController`
- play/pause and previous/next work
- the foreground service, media notification, and lock-screen media controls
  are present and working on the test phone
- debug logging was temporarily added around audio-service startup, loading,
  and player state to diagnose notification behaviour

The next requested playback improvement is a **draggable seek/progress bar**
in the playback screen. It should:
- show the current position and total duration
- call the controller/handler seek method when the user drags it
- stay synchronized with the audio handler's position stream
- preserve the existing working media-session behaviour

After that, add only the remaining requested controls as needed:
- repeat
- shuffle/random

### Random playlist
Use the already-built `List<Song>`:
- equal opportunity for songs
- no filesystem rescan for each next song
- no loading full audio files into memory
- randomized index/order is acceptable
- integrate repeat/shuffle behavior

### Dedicated shuffle screen

Shuffle/random playback starts from its own simple screen rather than from a
small toggle on the Now Playing screen.

The screen has two primary controls:

- a large circular Play button that starts a shuffled session from the
  currently built library;
- a compact rectangular library selector positioned roughly 75–80% down the
  screen, displaying the selected library name and opening a radio-style
  dropdown containing all saved libraries.

Play-button behavior:

- if no library is selected, open `LibraryManagerScreen`;
- if the current selection needs rebuilding and was not explicitly chosen
  through the shuffle screen selector, open `LibraryManagerScreen`;
- selecting a library through the dropdown makes it the pending selection;
- pressing Play after an explicit dropdown selection automatically rebuilds
  that library when necessary, then starts shuffle and opens Now Playing;
- if the selected library already has a current build, start shuffle without
  rescanning.

Build validity must be tracked explicitly rather than inferred from
`songs.isEmpty`, because an empty library can be a legitimate completed build.
Track the library associated with the in-memory built song list and invalidate
it when its root, recipe, or selected library changes.

### Final simple music-player UI
Build only the requested practical UI:
- Now Playing
- queue/current song
- playback controls
- seek bar
- song information
- library selection
- rebuild
- shuffle/random
- repeat

### Playback layout TODOs

- The user has additional changes planned for the Now Playing/playback layout.
- Defer those layout changes until music metadata is added, so metadata fields
  and the revised playback design can be implemented together.
- Collect the exact requested layout changes before treating the playback UI as
  final.
- Preserve the tested seek, queue-position, playback-control, repeat, and
  shuffle behavior while revising the layout.
- Do not perform speculative playback-layout redesign before those details are
  provided.

### Main carousel navigation

Replace the single Shuffle home screen with a looping three-page horizontal
carousel:

1. left: Library Manager;
2. center and initial page: Shuffle;
3. right: intentionally empty placeholder for now.

Swiping past either end loops to the opposite end. Programmatic transitions
between these main sections must use the same horizontal slide rather than
pushing a standalone replacement screen. Show a small three-position carousel
indicator at the bottom.

`PlaybackScreen` remains a route above the carousel. Returning from playback
reveals the carousel. Whenever a song session is loaded, including while paused,
the carousel displays a floating mini-player that opens `PlaybackScreen`. The
mini-player can be collapsed into a small icon without stopping or discarding
the current song.

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

**Immediate task:** preserve the device-tested shuffle/repeat behavior, report
shuffle status accurately through the media session, then collect and implement
the user's requested playback-layout changes. Keep the already-working
lock-screen and notification media controls intact.
