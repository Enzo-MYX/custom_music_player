class Song {
  final String relativePath;
  final String uri;

  const Song({
    required this.relativePath,
    required this.uri,
  });

  Map<String, dynamic> toJson() {
    return {
      'relativePath': relativePath,
      'uri': uri,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      relativePath: json['relativePath'] as String,
      uri: json['uri'] as String,
    );
  }
}