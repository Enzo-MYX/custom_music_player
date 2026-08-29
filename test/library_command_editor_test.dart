import 'package:flutter_test/flutter_test.dart';

import 'package:custom_music_player/models/library_command.dart';
import 'package:custom_music_player/services/library_command_editor.dart';

void main() {
  group('single-folder command addition', () {
    test('adds one new folder command', () {
      final result = LibraryCommandEditor.prepareAddition(
        existingCommands: const [],
        include: true,
        paths: ['Anime'],
      );

      expect(result.conflictingPaths, isEmpty);
      expect(result.commandsToAdd, hasLength(1));
      expect(result.commandsToAdd.single.include, isTrue);
      expect(result.commandsToAdd.single.path, 'Anime');
    });
  });

  group('bulk command addition', () {
    test('adds every selected non-conflicting folder and file', () {
      final result = LibraryCommandEditor.prepareAddition(
        existingCommands: const [],
        include: false,
        paths: [
          'Anime',
          'Podcasts/Episodes',
          'Singles/song.mp3',
        ],
      );

      expect(result.conflictingPaths, isEmpty);
      expect(
        result.commandsToAdd.map((command) => command.displayText),
        [
          '- Anime',
          '- Podcasts/Episodes',
          '- Singles/song.mp3',
        ],
      );
    });

    test('adds unaffected paths and reports exact-path conflicts', () {
      final result = LibraryCommandEditor.prepareAddition(
        existingCommands: [
          LibraryCommand.create(
            include: true,
            path: 'Anime',
          ),
        ],
        include: false,
        paths: [
          'Anime',
          'Podcasts',
          'Singles/song.mp3',
        ],
      );

      expect(result.conflictingPaths, ['Anime']);
      expect(
        result.commandsToAdd.map((command) => command.path),
        [
          'Podcasts',
          'Singles/song.mp3',
        ],
      );
    });
  });

  group('exact-path conflict resolution', () {
    test('replaces only the conflicting command with the chosen rule', () {
      final updatedCommands =
      LibraryCommandEditor.resolveExactPathConflicts(
        existingCommands: [
          LibraryCommand.create(
            include: true,
            path: 'Anime',
          ),
          LibraryCommand.create(
            include: false,
            path: 'Podcasts',
          ),
        ],
        paths: ['Anime'],
        include: false,
      );

      expect(
        updatedCommands.map((command) => command.displayText),
        [
          '- Anime',
          '- Podcasts',
        ],
      );
    });
  });
}