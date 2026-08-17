import 'build_mode.dart';
import 'library_command.dart';

class MusicLibrary {
  final String name;
  final LibraryBuildMode buildMode;
  final List<LibraryCommand> commands;

  const MusicLibrary({
    required this.name,
    required this.buildMode,
    required this.commands,
  });
}