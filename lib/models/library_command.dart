import '../services/path_utils.dart';

class LibraryCommand {
  final bool include;
  final String path;

  const LibraryCommand({
    required this.include,
    required this.path,
  });

  factory LibraryCommand.create({
    required bool include,
    required String path,
  }) {
    final normalizedPath = PathUtils.normalize(path);

    if (normalizedPath.isEmpty) {
      throw ArgumentError(
        'A library command cannot target the root directory.',
      );
    }

    return LibraryCommand(
      include: include,
      path: normalizedPath,
    );
  }

  String get displayText {
    return '${include ? '+' : '-'} $path';
  }

  Map<String, dynamic> toJson() {
    return {
      'include': include,
      'path': path,
    };
  }

  factory LibraryCommand.fromJson(Map<String, dynamic> json) {
    return LibraryCommand.create(
      include: json['include'] as bool,
      path: json['path'] as String,
    );
  }
}