import 'package:audio_service/audio_service.dart';
import 'package:custom_music_player/models/playback_resume_state.dart';
import 'package:custom_music_player/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resume state round-trips a shuffled queue', () {
    const state = PlaybackResumeState(
      songs: [
        Song(relativePath: 'a.mp3', uri: 'content://a'),
        Song(relativePath: 'b.mp3', uri: 'content://b'),
        Song(relativePath: 'c.mp3', uri: 'content://c'),
      ],
      currentIndex: 0,
      shuffleEnabled: true,
      shuffleOrder: [2, 0, 1],
      shufflePosition: 1,
      positionMilliseconds: 12345,
      speed: 1.25,
      repeatMode: AudioServiceRepeatMode.all,
    );

    final restored = PlaybackResumeState.fromJson(state.toJson());

    expect(restored.isValid, isTrue);
    expect(restored.songs.map((song) => song.uri), [
      'content://a',
      'content://b',
      'content://c',
    ]);
    expect(restored.shuffleOrder, [2, 0, 1]);
    expect(restored.shufflePosition, 1);
    expect(restored.currentIndex, 0);
    expect(restored.position, const Duration(milliseconds: 12345));
    expect(restored.speed, 1.25);
    expect(restored.repeatMode, AudioServiceRepeatMode.all);
  });

  test('rejects a shuffle order that does not match the queue', () {
    const state = PlaybackResumeState(
      songs: [Song(relativePath: 'a.mp3', uri: 'content://a')],
      currentIndex: 0,
      shuffleEnabled: true,
      shuffleOrder: [1],
      shufflePosition: 0,
      positionMilliseconds: 0,
      speed: 1,
      repeatMode: AudioServiceRepeatMode.none,
    );

    expect(state.isValid, isFalse);
  });
}
