import 'package:saf/saf.dart';

import '../models/music_library.dart';
import '../models/song.dart';
import 'command_matcher.dart';

class LibraryScanner {
  final Saf _saf;

  LibraryScanner({
    Saf? saf,
  }) : _saf = saf ?? Saf();

  Future<List<Song>> rebuild(
      SafDocumentFile root,
      MusicLibrary library,
      ) async {
    final matcher = LibraryCommandMatcher(
      buildMode: library.buildMode,
      commands: library.commands,
    );

    final songs = <Song>[];

    await for (final entry in _saf.walk(root.uri)) {
      final relativePath = entry.relativePath;

      if (matcher.shouldInclude(relativePath)) {
        songs.add(
          Song(relativePath: relativePath),
        );
      }
    }

    return songs;
  }
}