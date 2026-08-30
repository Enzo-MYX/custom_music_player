class Song {
  final String relativePath;
  final String uri;
  final String? lyricsUri;

  const Song({required this.relativePath, required this.uri, this.lyricsUri});

  Map<String, dynamic> toJson() {
    return {
      'relativePath': relativePath,
      'uri': uri,
      if (lyricsUri != null) 'lyricsUri': lyricsUri,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      relativePath: json['relativePath'] as String,
      uri: json['uri'] as String,
      lyricsUri: json['lyricsUri'] as String?,
    );
  }
}
