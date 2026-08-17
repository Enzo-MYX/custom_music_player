import 'package:flutter_test/flutter_test.dart';

import 'package:custom_music_player/models/build_mode.dart';
import 'package:custom_music_player/models/library_command.dart';
import 'package:custom_music_player/services/command_matcher.dart';

void main() {
  group('LibraryCommandMatcher', () {
    test('includeAll includes everything by default', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeAll,
        commands: const [],
      );

      expect(matcher.shouldInclude('Music/song.mp3'), isTrue);
    });

    test('includeNone excludes everything by default', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeNone,
        commands: const [],
      );

      expect(matcher.shouldInclude('Music/song.mp3'), isFalse);
    });

    test('includeAll allows exclusion', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeAll,
        commands: const [
          LibraryCommand(
            include: false,
            path: 'Music/Live',
          ),
        ],
      );

      expect(matcher.shouldInclude('Music/song.mp3'), isTrue);
      expect(matcher.shouldInclude('Music/Live/song.mp3'), isFalse);
    });

    test('includeAll allows inclusion to override exclusion', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeAll,
        commands: const [
          LibraryCommand(
            include: false,
            path: 'Music/Live',
          ),
          LibraryCommand(
            include: true,
            path: 'Music/Live/Favourites',
          ),
        ],
      );

      expect(matcher.shouldInclude('Music/Live/song.mp3'), isFalse);
      expect(
        matcher.shouldInclude('Music/Live/Favourites/song.mp3'),
        isTrue,
      );
    });

    test('includeNone allows inclusion', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeNone,
        commands: const [
          LibraryCommand(
            include: true,
            path: 'Music',
          ),
        ],
      );

      expect(matcher.shouldInclude('Music/song.mp3'), isTrue);
      expect(matcher.shouldInclude('Other/song.mp3'), isFalse);
    });

    test('includeNone allows exclusion to override inclusion', () {
      final matcher = LibraryCommandMatcher(
        buildMode: LibraryBuildMode.includeNone,
        commands: const [
          LibraryCommand(
            include: true,
            path: 'Music',
          ),
          LibraryCommand(
            include: false,
            path: 'Music/Live',
          ),
        ],
      );

      expect(matcher.shouldInclude('Music/song.mp3'), isTrue);
      expect(matcher.shouldInclude('Music/Live/song.mp3'), isFalse);
    });
  });
}