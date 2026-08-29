import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

import '../models/song.dart';
import 'path_utils.dart';

class PlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  final just_audio.AudioPlayer _player = just_audio.AudioPlayer();

  List<Song> _songs = const [];
  int? _currentIndex;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<Song?> get currentSongStream => mediaItem.map((_) => currentSong);

  int? get currentIndex => _currentIndex;

  int get songCount => _songs.length;

  Song? get currentSong {
    final index = _currentIndex;

    if (index == null || index >= _songs.length) {
      return null;
    }

    return _songs[index];
  }

  AudioServiceRepeatMode get repeatMode => _repeatMode;

  bool get canGoPrevious =>
      _currentIndex != null && _currentIndex! > 0;

  bool get canGoNext =>
      _currentIndex != null &&
          _currentIndex! < _songs.length - 1;

  PlayerAudioHandler() {
    _player.playbackEventStream
        .map((event) {
      final state = _toPlaybackState(event);

      debugPrint(
        '[audio] state: '
            'processing=${state.processingState}, '
            'playing=${state.playing}, '
            'position=${state.updatePosition}',
      );

      return state;
    })
        .listen(playbackState.add);

    _player.durationStream.listen((duration) {
      debugPrint('[audio] duration: $duration');

      if (duration != null && currentSong != null) {
        _publishCurrentMediaItem(duration: duration);
      }
    });

    _player.processingStateStream.listen((state) async {
      if (state != just_audio.ProcessingState.completed) {
        return;
      }

      if (_repeatMode == AudioServiceRepeatMode.one) {
        await _player.seek(Duration.zero);
        await _player.play();
        return;
      }

      if (canGoNext) {
        await skipToNext();
        return;
      }

      if (_repeatMode == AudioServiceRepeatMode.all && _songs.isNotEmpty) {
        _currentIndex = 0;
        await _loadCurrentSong();
        await _player.play();
        return;
      }

      await _player.pause();
      await _player.seek(Duration.zero);
    });
  }

  Future<void> setSongs(List<Song> songs) async {
    debugPrint('[audio] setSongs: ${songs.length} songs');

    await _player.stop();
    await _player.setSpeed(1.0);

    // Use the already-built library list; do not duplicate it.
    _songs = songs;
    _currentIndex = songs.isEmpty ? null : 0;

    if (_currentIndex != null) {
      await _loadCurrentSong();
    }
  }

  @override
  Future<void> setRepeatMode(
      AudioServiceRepeatMode repeatMode,
      ) async {
    _repeatMode = repeatMode;

    playbackState.add(
      playbackState.value.copyWith(
        repeatMode: repeatMode,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (currentSong == null) {
      return;
    }

    await _player.play();
  }

  @override
  Future<void> pause() {
    return _player.pause();
  }

  @override
  Future<void> seek(Duration position) {
    return _player.seek(position);
  }

  @override
  Future<void> skipToPrevious() async {
    if (!canGoPrevious) {
      return;
    }

    final wasPlaying = _player.playing;
    _currentIndex = _currentIndex! - 1;

    await _loadCurrentSong();

    if (wasPlaying) {
      await _player.play();
    }
  }

  @override
  Future<void> skipToNext() async {
    if (!canGoNext) {
      return;
    }

    final wasPlaying = _player.playing;
    _currentIndex = _currentIndex! + 1;

    await _loadCurrentSong();

    if (wasPlaying) {
      await _player.play();
    }
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  Future<void> dispose() {
    return _player.dispose();
  }

  Future<void> _loadCurrentSong() async {
    final song = currentSong!;

    debugPrint('[audio] loading: ${song.relativePath}');

    _publishCurrentMediaItem();

    await _player.setAudioSource(
      just_audio.AudioSource.uri(
        Uri.parse(song.uri),
      ),
    );
  }

  void _publishCurrentMediaItem({
    Duration? duration,
  }) {
    final song = currentSong;

    if (song == null) {
      return;
    }

    mediaItem.add(
      MediaItem(
        id: song.uri,
        title: PathUtils.basename(song.relativePath),
        album: PathUtils.parent(song.relativePath),
        duration: duration,
      ),
    );
  }

  PlaybackState _toPlaybackState(
      just_audio.PlaybackEvent event,
      ) {
    final controls = <MediaControl>[
      if (canGoPrevious) MediaControl.skipToPrevious,
      if (_player.playing)
        MediaControl.pause
      else
        MediaControl.play,
      if (canGoNext) MediaControl.skipToNext,
      MediaControl.stop,
    ];

    return PlaybackState(
      controls: controls,
      repeatMode: _repeatMode,
      systemActions: const {
        MediaAction.seek,
      },
      androidCompactActionIndices: List.generate(
        controls.length > 3 ? 3 : controls.length,
            (index) => index,
      ),
      processingState: switch (_player.processingState) {
        just_audio.ProcessingState.idle =>
        AudioProcessingState.idle,
        just_audio.ProcessingState.loading =>
        AudioProcessingState.loading,
        just_audio.ProcessingState.buffering =>
        AudioProcessingState.buffering,
        just_audio.ProcessingState.ready =>
        AudioProcessingState.ready,
        just_audio.ProcessingState.completed =>
        AudioProcessingState.completed,
      },
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    );
  }
}
