import 'package:flutter_test/flutter_test.dart';

import 'package:custom_music_player/models/build_mode.dart';
import 'package:custom_music_player/services/command_matcher.dart';
import 'package:custom_music_player/models/library_command.dart';

void main() {
  group('includeAll', () {
    test('everything is included by default', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeAll,
        commands: const [],
      );

      expect(
        matcher.shouldInclude('song.mp3'),
        isTrue,
      );

      expect(
        matcher.shouldInclude('Anime/song.mp3'),
        isTrue,
      );
    });

    test('specific exclusion overrides default inclusion', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeAll,
        commands: [
          LibraryCommand(
            include: false,
            path: 'Anime',
          ),
        ],
      );

      expect(
        matcher.shouldInclude('Anime/song.mp3'),
        isFalse,
      );

      expect(
        matcher.shouldInclude('Music/song.mp3'),
        isTrue,
      );
    });

    test('more specific inclusion overrides exclusion', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeAll,
        commands: [
          LibraryCommand(
            include: false,
            path: 'Anime',
          ),
          LibraryCommand(
            include: true,
            path: 'Anime/Favourites',
          ),
        ],
      );

      expect(
        matcher.shouldInclude(
          'Anime/song.mp3',
        ),
        isFalse,
      );

      expect(
        matcher.shouldInclude(
          'Anime/Favourites/song.mp3',
        ),
        isTrue,
      );
    });

    test('even deeper exclusion wins', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeAll,
        commands: [
          LibraryCommand(
            include: false,
            path: 'Anime',
          ),
          LibraryCommand(
            include: true,
            path: 'Anime/Favourites',
          ),
          LibraryCommand(
            include: false,
            path: 'Anime/Favourites/Bad',
          ),
        ],
      );

      expect(
        matcher.shouldInclude(
          'Anime/song.mp3',
        ),
        isFalse,
      );

      expect(
        matcher.shouldInclude(
          'Anime/Favourites/good.mp3',
        ),
        isTrue,
      );

      expect(
        matcher.shouldInclude(
          'Anime/Favourites/Bad/song.mp3',
        ),
        isFalse,
      );
    });
  });

  group('includeNone', () {
    test('everything is excluded by default', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeNone,
        commands: const [],
      );

      expect(
        matcher.shouldInclude('song.mp3'),
        isFalse,
      );

      expect(
        matcher.shouldInclude('Anime/song.mp3'),
        isFalse,
      );
    });

    test('specific inclusion overrides default exclusion', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeNone,
        commands: [
          LibraryCommand(
            include: true,
            path: 'Anime',
          ),
        ],
      );

      expect(
        matcher.shouldInclude(
          'Anime/song.mp3',
        ),
        isTrue,
      );

      expect(
        matcher.shouldInclude(
          'Music/song.mp3',
        ),
        isFalse,
      );
    });

    test('more specific exclusion overrides inclusion', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeNone,
        commands: [
          LibraryCommand(
            include: true,
            path: 'Anime',
          ),
          LibraryCommand(
            include: false,
            path: 'Anime/Bad',
          ),
        ],
      );

      expect(
        matcher.shouldInclude(
          'Anime/good.mp3',
        ),
        isTrue,
      );

      expect(
        matcher.shouldInclude(
          'Anime/Bad/song.mp3',
        ),
        isFalse,
      );
    });
  });

  group('command order', () {
    test('order does not matter', () {
      final matcher1 = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeAll,
        commands: [
          LibraryCommand(
            include: false,
            path: 'Anime',
          ),
          LibraryCommand(
            include: true,
            path: 'Anime/Favourites',
          ),
        ],
      );

      final matcher2 = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeAll,
        commands: [
          LibraryCommand(
            include: true,
            path: 'Anime/Favourites',
          ),
          LibraryCommand(
            include: false,
            path: 'Anime',
          ),
        ],
      );

      const path = 'Anime/Favourites/song.mp3';

      expect(
        matcher1.shouldInclude(path),
        isTrue,
      );

      expect(
        matcher2.shouldInclude(path),
        isTrue,
      );
    });
  });

  group('path boundaries', () {
    test('similar names do not accidentally match', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeAll,
        commands: [
          LibraryCommand(
            include: false,
            path: 'Anime',
          ),
        ],
      );

      expect(
        matcher.shouldInclude('Anime/song.mp3'),
        isFalse,
      );

      expect(
        matcher.shouldInclude('Anime2/song.mp3'),
        isTrue,
      );
    });
  });
}