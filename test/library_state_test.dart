import 'package:custom_music_player/models/app_settings.dart';
import 'package:custom_music_player/models/build_mode.dart';
import 'package:custom_music_player/models/library_state.dart';
import 'package:custom_music_player/models/music_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const library = MusicLibrary(
    name: 'Test library',
    buildMode: LibraryBuildMode.includeAll,
    commands: [],
  );
  const settings = AppSettings(
    rootUri: 'content://test-root',
    libraries: [library],
  );

  test('selected library needs rebuilding when no build is current', () {
    const state = LibraryState(
      settings: settings,
      selectedLibraryName: 'Test library',
      builtLibraryName: null,
      songs: [],
      scanning: false,
    );

    expect(state.needsRebuild, isTrue);
  });

  test('completed empty build is not treated as needing rebuilding', () {
    const state = LibraryState(
      settings: settings,
      selectedLibraryName: 'Test library',
      builtLibraryName: 'Test library',
      songs: [],
      scanning: false,
    );

    expect(state.needsRebuild, isFalse);
  });

  test('copyWith can explicitly invalidate the current build', () {
    const state = LibraryState(
      settings: settings,
      selectedLibraryName: 'Test library',
      builtLibraryName: 'Test library',
      songs: [],
      scanning: false,
    );

    final invalidated = state.copyWith(builtLibraryName: null);

    expect(invalidated.builtLibraryName, isNull);
    expect(invalidated.needsRebuild, isTrue);
  });
}
