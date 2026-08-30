import 'package:custom_music_player/models/song_lyrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses and sorts synchronized LRC timestamps', () {
    final lyrics = SongLyrics.parse(
      '[00:12.50]Second\n[00:01.250][00:03.00]First',
    );

    expect(lyrics?.isSynchronized, isTrue);
    expect(lyrics?.lines.map((line) => line.time).toList(), const [
      Duration(seconds: 1, milliseconds: 250),
      Duration(seconds: 3),
      Duration(seconds: 12, milliseconds: 500),
    ]);
    expect(lyrics?.lines.first.text, 'First');
  });

  test('keeps unsynchronized lyrics and removes LRC metadata', () {
    final lyrics = SongLyrics.parse('[ar:Artist]\nLine one\nLine two');

    expect(lyrics?.isSynchronized, isFalse);
    expect(lyrics?.text, 'Line one\nLine two');
  });

  test('prefers synchronized sidecar lyrics', () {
    final lyrics = chooseLyrics(
      sidecar: '[00:01.00]Sidecar',
      embedded: '[00:01.00]Embedded',
    );

    expect(lyrics?.lines.single.text, 'Sidecar');
  });

  test('prefers synchronized embedded lyrics over plain sidecar lyrics', () {
    final lyrics = chooseLyrics(
      sidecar: 'Plain sidecar',
      embedded: '[00:01.00]Timed embedded',
    );

    expect(lyrics?.lines.single.text, 'Timed embedded');
  });
}
