import 'package:flutter_test/flutter_test.dart';

import 'package:custom_music_player/models/app_settings.dart';
import 'package:custom_music_player/models/build_mode.dart';
import 'package:custom_music_player/models/library_command.dart';
import 'package:custom_music_player/models/music_library.dart';
import 'package:custom_music_player/models/song.dart';
import 'package:custom_music_player/models/tuning_settings.dart';

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
      ignoreLibrary: MusicLibrary(
        name: 'Ignored files',
        buildMode: LibraryBuildMode.includeNone,
        commands: [LibraryCommand(include: true, path: 'Podcasts')],
      ),
    );

    final json = original.toJson();
    final restored = AppSettings.fromJson(json);

    expect(restored.rootUri, 'content://example/root');

    expect(restored.libraries.length, 1);
    expect(restored.libraries[0].name, 'Test');
    expect(restored.libraries[0].buildMode, LibraryBuildMode.includeNone);
    expect(restored.libraries[0].commands.length, 1);
    expect(restored.ignoreLibrary.commands.single.path, 'Podcasts');
  });

  test('older AppSettings default to an empty ignore library', () {
    final restored = AppSettings.fromJson({
      'rootUri': 'content://example/root',
      'libraries': <dynamic>[],
    });

    expect(restored.ignoreLibrary.buildMode, LibraryBuildMode.includeNone);
    expect(restored.ignoreLibrary.commands, isEmpty);
  });

  test('TuningSettings survives JSON serialization', () {
    const original = TuningSettings(
      nightMode: true,
      shuffleSkipThreshold: 90,
      shuffleSkipThresholdUnit: ShuffleSkipThresholdUnit.seconds,
      loadTimeoutSeconds: 20,
      seekSeconds: 8,
      defaultPlaybackSpeed: 1.25,
      playbackSpeeds: [0.75, 1, 1.25, 1.5],
      carouselMinFlingDistance: 12,
      carouselMinFlingVelocity: 120,
    );

    final restored = TuningSettings.fromJson(original.toJson());

    expect(restored.nightMode, isTrue);
    expect(restored.shuffleSkipThreshold, 90);
    expect(restored.shuffleSkipThresholdUnit, ShuffleSkipThresholdUnit.seconds);
    expect(restored.shuffleSkipDuration, const Duration(seconds: 90));
    expect(restored.loadTimeoutSeconds, 20);
    expect(restored.seekSeconds, 8);
    expect(restored.defaultPlaybackSpeed, 1.25);
    expect(restored.playbackSpeeds, [0.75, 1, 1.25, 1.5]);
    expect(restored.carouselMinFlingDistance, 12);
    expect(restored.carouselMinFlingVelocity, 120);
  });

  test('TuningSettings repairs invalid persisted values', () {
    final restored = TuningSettings.fromJson({
      'nightMode': 'invalid',
      'shuffleSkipThreshold': 0,
      'shuffleSkipThresholdUnit': 'invalid',
      'loadTimeoutSeconds': 0,
      'seekSeconds': -1,
      'defaultPlaybackSpeed': 9,
      'playbackSpeeds': [0, 1, 8],
      'carouselMinFlingDistance': -2,
      'carouselMinFlingVelocity': -3,
    });

    expect(restored.nightMode, isFalse);
    expect(restored.shuffleSkipThreshold, isNull);
    expect(restored.shuffleSkipThresholdUnit, ShuffleSkipThresholdUnit.minutes);
    expect(restored.loadTimeoutSeconds, 10);
    expect(restored.seekSeconds, 5);
    expect(restored.defaultPlaybackSpeed, 1);
    expect(restored.playbackSpeeds, [1]);
    expect(restored.carouselMinFlingDistance, 4);
    expect(restored.carouselMinFlingVelocity, 50);
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
