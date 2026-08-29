import '../models/library_command.dart';

class CommandAddition {
  final List<LibraryCommand> commandsToAdd;
  final List<String> conflictingPaths;

  const CommandAddition({
    required this.commandsToAdd,
    required this.conflictingPaths,
  });
}

class LibraryCommandEditor {
  const LibraryCommandEditor._();

  static CommandAddition prepareAddition({
    required List<LibraryCommand> existingCommands,
    required bool include,
    required Iterable<String> paths,
  }) {
    final knownPaths = existingCommands
        .map((command) => command.path)
        .toSet();

    final commandsToAdd = <LibraryCommand>[];
    final conflictingPaths = <String>[];

    for (final path in paths) {
      final command = LibraryCommand.create(
        include: include,
        path: path,
      );

      if (knownPaths.contains(command.path)) {
        conflictingPaths.add(command.path);
        continue;
      }

      knownPaths.add(command.path);
      commandsToAdd.add(command);
    }

    return CommandAddition(
      commandsToAdd: commandsToAdd,
      conflictingPaths: conflictingPaths,
    );
  }

  static List<LibraryCommand> resolveExactPathConflicts({
    required List<LibraryCommand> existingCommands,
    required Iterable<String> paths,
    required bool include,
  }) {
    final pathsToReplace = paths.toSet();
    final replacedPaths = <String>{};
    final updatedCommands = <LibraryCommand>[];

    for (final command in existingCommands) {
      if (!pathsToReplace.contains(command.path)) {
        updatedCommands.add(command);
        continue;
      }

      if (replacedPaths.add(command.path)) {
        updatedCommands.add(
          LibraryCommand.create(
            include: include,
            path: command.path,
          ),
        );
      }
    }

    return updatedCommands;
  }
}