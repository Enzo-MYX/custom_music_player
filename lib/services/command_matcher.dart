import '../models/build_mode.dart';
import '../models/library_command.dart';

class LibraryCommandMatcher {
  final LibraryBuildMode buildMode;
  final List<LibraryCommand> commands;

  const LibraryCommandMatcher({
    required this.buildMode,
    required this.commands,
  });

  bool shouldInclude(String relativePath) {
    final matchingCommands = commands
        .where((command) => _matches(command.path, relativePath))
        .toList();

    if (matchingCommands.isEmpty) {
      return buildMode == LibraryBuildMode.includeAll;
    }

    if (buildMode == LibraryBuildMode.includeAll) {
      // Exclusions are applied first, then inclusions.
      var included = true;
      for (final command in matchingCommands) {
        if (!command.include) {
          included = false;
        }
      }
      for (final command in matchingCommands) {
        if (command.include) {
          included = true;
        }
      }
      return included;
    } else {
      // Inclusions are applied first, then exclusions.
      var included = false;
      for (final command in matchingCommands) {
        if (command.include) {
          included = true;
        }
      }
      for (final command in matchingCommands) {
        if (!command.include) {
          included = false;
        }
      }
      return included;
    }
  }

  bool _matches(String commandPath, String filePath) {
    if (filePath == commandPath) {
      return true;
    }
    return filePath.startsWith('$commandPath/');
  }
}