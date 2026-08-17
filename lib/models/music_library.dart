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

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'buildMode': buildMode.name,
      'commands': commands
          .map((command) => command.toJson())
          .toList(),
    };
  }

  factory MusicLibrary.fromJson(Map<String, dynamic> json) {
    final modeString = json['buildMode'] as String;
    final buildMode = LibraryBuildMode.values.firstWhere(
          (mode) => mode.name == modeString,
    );
    final commandList = (json['commands'] as List<dynamic>)
        .map(
          (command) => LibraryCommand.fromJson(
        command as Map<String, dynamic>,
      ),
    ).toList();
    return MusicLibrary(
      name: json['name'] as String,
      buildMode: buildMode,
      commands: commandList,
    );
  }
}