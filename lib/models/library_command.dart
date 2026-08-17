class LibraryCommand {
  final bool include;
  final String path;

  const LibraryCommand({
    required this.include,
    required this.path,
  });

  Map<String, dynamic> toJson() {
    return {
      'include': include,
      'path': path,
    };
  }

  factory LibraryCommand.fromJson(Map<String, dynamic> json) {
    return LibraryCommand(
      include: json['include'] as bool,
      path: json['path'] as String,
    );
  }
}