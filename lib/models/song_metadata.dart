import 'dart:typed_data';

import 'song_lyrics.dart';

class SongMetadata {
  const SongMetadata({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNumber,
    this.year,
    this.artwork,
    this.lyrics,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? trackNumber;
  final String? year;
  final Uint8List? artwork;
  final SongLyrics? lyrics;
}
