import 'song.dart';

class BuiltLibraryCache {
  const BuiltLibraryCache({
    required this.rootUri,
    required this.libraryName,
    required this.librarySignature,
    required this.songs,
  });

  final String? rootUri;
  final String libraryName;
  final String librarySignature;
  final List<Song> songs;

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'rootUri': rootUri,
      'libraryName': libraryName,
      'librarySignature': librarySignature,
      'songs': songs.map((song) => song.toJson()).toList(),
    };
  }

  factory BuiltLibraryCache.fromJson(Map<String, dynamic> json) {
    final songsJson = json['songs'] as List<dynamic>? ?? const [];

    return BuiltLibraryCache(
      rootUri: json['rootUri'] as String?,
      libraryName: json['libraryName'] as String,
      librarySignature: json['librarySignature'] as String,
      songs: songsJson
          .map(
            (entry) => Song.fromJson(
          Map<String, dynamic>.from(entry as Map),
        ),
      )
          .toList(growable: false),
    );
  }
}