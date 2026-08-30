import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../models/song.dart';
import '../models/song_metadata.dart';
import '../models/song_lyrics.dart';

class MetadataReader {
  static const MethodChannel _channel = MethodChannel(
    'com.example.custom_music_player/metadata',
  );

  Future<SongMetadata> read(Song song) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readMetadata',
        {
          'uri': song.uri,
          if (song.lyricsUri != null) 'lyricsUri': song.lyricsUri,
        },
      );

      if (result == null) {
        return const SongMetadata();
      }

      return SongMetadata(
        title: _clean(result['title']),
        artist: _clean(result['artist']),
        album: _clean(result['album']),
        albumArtist: _clean(result['albumArtist']),
        trackNumber: _clean(result['trackNumber']),
        year: _clean(result['year']),
        artwork: result['artwork'] as Uint8List?,
        lyrics: chooseLyrics(
          sidecar: _clean(result['sidecarLyrics']),
          embedded: _clean(result['embeddedLyrics']),
        ),
      );
    } on PlatformException {
      return const SongMetadata();
    }
  }

  String? _clean(Object? value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}
