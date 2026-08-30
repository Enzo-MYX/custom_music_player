import 'package:flutter_test/flutter_test.dart';

import 'package:custom_music_player/models/app_settings.dart';
import 'package:custom_music_player/models/build_mode.dart';
import 'package:custom_music_player/models/library_command.dart';
import 'package:custom_music_player/models/music_library.dart';
import 'package:custom_music_player/models/song.dart';

void main() {
  test('MusicLibrary survives JSON serialization', () {
    const original = MusicLibrary(
      name: 'Test Library',
      buildMode: LibraryBuildMode.includeAll,
      commands: [
        LibraryCommand(include: false, path: 'Live'),
        LibraryCommand(include: true, path: 'Live/Favourites'),
      ],
    );

    final json = original.toJson();
    final restored = MusicLibrary.fromJson(json);

    expect(restored.name, original.name);
    expect(restored.buildMode, original.buildMode);
    expect(restored.commands.length, 2);

    expect(restored.commands[0].include, false);

    expect(restored.commands[0].path, 'Live');

    expect(restored.commands[1].include, true);

    expect(restored.commands[1].path, 'Live/Favourites');
  });

  test('AppSettings survives JSON serialization', () {
    const original = AppSettings(
      rootUri: 'content://example/root',
      libraries: [
        MusicLibrary(
          name: 'Test',
          buildMode: LibraryBuildMode.includeNone,
          commands: [LibraryCommand(include: true, path: 'Music')],
        ),
      ],
    );

    final json = original.toJson();
    final restored = AppSettings.fromJson(json);

    expect(restored.rootUri, 'content://example/root');

    expect(restored.libraries.length, 1);
    expect(restored.libraries[0].name, 'Test');
    expect(restored.libraries[0].buildMode, LibraryBuildMode.includeNone);
    expect(restored.libraries[0].commands.length, 1);
  });

  test('Song preserves a sidecar lyrics URI in the lightweight cache', () {
    const song = Song(
      relativePath: 'Album/Track.flac',
      uri: 'content://example/track',
      lyricsUri: 'content://example/lyrics',
    );

    final json = song.toJson();
    final restored = Song.fromJson(json);

    expect(json.keys, unorderedEquals(['relativePath', 'uri', 'lyricsUri']));
    expect(json, isNot(contains('metadata')));
    expect(json, isNot(contains('artwork')));

    expect(restored.relativePath, song.relativePath);
    expect(restored.uri, song.uri);
    expect(restored.lyricsUri, song.lyricsUri);
  });
}
