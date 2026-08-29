import 'package:audio_service/audio_service.dart';

import '../models/song.dart';
import 'player_audio_handler.dart';

class PlaybackController {
  final PlayerAudioHandler _handler;

  PlaybackController(this._handler);

  Stream<bool> get playingStream =>
      _handler.playbackState.map((state) => state.playing).distinct();

  Stream<Duration?> get durationStream => _handler.durationStream;

  Stream<Duration> get positionStream => AudioService.position;

  Duration get position => _handler.position;

  Song? get currentSong => _handler.currentSong;

  bool get canGoPrevious => _handler.canGoPrevious;

  bool get canGoNext => _handler.canGoNext;

  Stream<Song?> get currentSongStream => _handler.currentSongStream;

  int? get currentIndex => _handler.queuePosition;

  int get songCount => _handler.songCount;

  AudioServiceRepeatMode get repeatMode => _handler.repeatMode;

  Stream<AudioServiceRepeatMode> get repeatModeStream =>
      _handler.playbackState.map((state) => state.repeatMode).distinct();

  Future<void> setSongs(List<Song> songs) {
    return _handler.setSongs(songs);
  }

  Future<void> startShuffle(List<Song> songs) {
    return _handler.startShuffle(songs);
  }

  Future<void> play() {
    return _handler.play();
  }

  Future<void> pause() {
    return _handler.pause();
  }

  Future<void> seek(Duration position) {
    return _handler.seek(position);
  }

  Future<void> previous() {
    return _handler.skipToPrevious();
  }

  Future<void> next() {
    return _handler.skipToNext();
  }

  Future<void> cycleRepeatMode() {
    final nextMode = switch (_handler.repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.none,
    };

    return _handler.setRepeatMode(nextMode);
  }

  Future<void> dispose() {
    return _handler.dispose();
  }
}
