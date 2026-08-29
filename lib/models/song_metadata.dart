import 'dart:typed_data';

class SongMetadata {
  const SongMetadata({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNumber,
    this.year,
    this.artwork,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? trackNumber;
  final String? year;
  final Uint8List? artwork;
}