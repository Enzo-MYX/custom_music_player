import 'package:flutter/material.dart';
import 'package:saf/saf.dart';

import '../models/music_library.dart';
import '../models/song.dart';
import 'command_matcher.dart';

class LibraryScanner {
  final Saf _saf;

  LibraryScanner({Saf? saf}) : _saf = saf ?? Saf();

  Future<List<Song>> rebuild(SafDocumentFile root, MusicLibrary library) async {
    final matcher = LibraryCommandMatcher(
      buildMode: library.buildMode,
      commands: library.commands,
    );

    final songs = <Song>[];

    await _scanDirectory(
      directory: root,
      relativeDirectory: '',
      matcher: matcher,
      songs: songs,
    );

    return songs;
  }

  Future<void> _scanDirectory({
    required SafDocumentFile directory,
    required String relativeDirectory,
    required LibraryCommandMatcher matcher,
    required List<Song> songs,
  }) async {
    final entries = await _saf.list(directory.uri);
    final sidecarLyricsByBasename = <String, String>{};

    for (final entry in entries) {
      if (!entry.isDir && _extension(entry.name) == 'lrc') {
        sidecarLyricsByBasename[_basenameWithoutExtension(entry.name)] =
            entry.uri;
      }
    }

    for (final entry in entries) {
      final relativePath = relativeDirectory.isEmpty
          ? entry.name
          : '$relativeDirectory/${entry.name}';

      if (entry.isDir) {
        await _scanDirectory(
          directory: entry,
          relativeDirectory: relativePath,
          matcher: matcher,
          songs: songs,
        );
      } else if (_extension(entry.name) != 'lrc') {
        if (matcher.shouldInclude(relativePath)) {
          songs.add(
            Song(
              relativePath: relativePath,
              uri: entry.uri,
              lyricsUri:
                  sidecarLyricsByBasename[_basenameWithoutExtension(
                    entry.name,
                  )],
            ),
          );
        }
      }
    }
  }

  String _extension(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot < 0 ? '' : filename.substring(dot + 1).toLowerCase();
  }

  String _basenameWithoutExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    final basename = dot < 0 ? filename : filename.substring(0, dot);
    return basename.toLowerCase();
  }
}
