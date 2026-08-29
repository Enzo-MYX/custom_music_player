import 'dart:async';
import 'dart:collection';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

import '../models/song.dart';
import '../models/song_metadata.dart';
import 'metadata_reader.dart';
import 'path_utils.dart';
import 'shuffle_order.dart';

class PlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  final just_audio.AudioPlayer _player = just_audio.AudioPlayer();
  final ShuffleOrder _shuffleOrder = ShuffleOrder();
  final MetadataReader _metadataReader = MetadataReader();

  final StreamController<SongMetadata?> _metadataController =
  StreamController<SongMetadata?>.broadcast();

  SongMetadata? _currentMetadata;

  List<Song> _songs = const [];
  int? _currentIndex;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  bool _shuffleEnabled = false;

  Stream<Duration?> get durationStream => _player.durationStream;

  Duration get position => _player.position;

  Duration? get duration => _player.duration;

  double get speed => _player.speed;

  bool get playing => _player.playing;

  UnmodifiableListView<Song> get songs => UnmodifiableListView(_songs);

  Stream<Song?> get currentSongStream => mediaItem.map((_) => currentSong);

  int? get currentIndex => _currentIndex;

  SongMetadata? get currentMetadata => _currentMetadata;

  Stream<SongMetadata?> get currentMetadataStream =>
      _metadataController.stream;

  int? get queuePosition {
    if (_currentIndex == null) {
      return null;
    }

    if (_shuffleEnabled) {
      return _shuffleOrder.position;
    }

    return _currentIndex;
  }

  bool get shuffleEnabled => _shuffleEnabled;

  int get songCount => _songs.length;

  Song? get currentSong {
    final index = _currentIndex;

    if (index == null || index >= _songs.length) {
      return null;
    }

    return _songs[index];
  }

  AudioServiceRepeatMode get repeatMode => _repeatMode;

  bool get canGoPrevious {
    if (_shuffleEnabled) {
      return _shuffleOrder.canGoPrevious;
    }

    return _currentIndex != null && _currentIndex! > 0;
  }

  bool get canGoNext {
    if (_shuffleEnabled) {
      return _shuffleOrder.canGoNext;
    }

    return _currentIndex != null && _currentIndex! < _songs.length - 1;
  }

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
        unawaited(_player.play());
        return;
      }

      if (canGoNext) {
        await skipToNext();
        return;
      }

      if (_repeatMode == AudioServiceRepeatMode.all && _songs.isNotEmpty) {
        if (_shuffleEnabled) {
          final previousIndex = _currentIndex;

          _shuffleOrder.reset(_songs.length, avoidFirstIndex: previousIndex);

          _currentIndex = _shuffleOrder.currentIndex;
        } else {
          _currentIndex = 0;
        }

        await _loadCurrentSong();
        unawaited(_player.play());
        return;
      }

      await _player.pause();
      await _player.seek(Duration.zero);
    });
  }

  Future<void> setSongs(List<Song> songs) {
    return _loadSongs(songs, shuffle: false);
  }

  Future<void> startShuffle(List<Song> songs) {
    return _loadSongs(songs, shuffle: true);
  }

  Future<void> _loadSongs(List<Song> songs, {required bool shuffle}) async {
    debugPrint(
      '[audio] loadSongs: ${songs.length} songs, '
      'shuffle=$shuffle',
    );

    await _player.stop();
    await _player.setSpeed(1.0);

    // Keep the existing built list; only shuffled indices are separate.
    _songs = songs;
    _shuffleEnabled = shuffle;

    if (shuffle) {
      _shuffleOrder.reset(songs.length);
      _currentIndex = _shuffleOrder.currentIndex;
    } else {
      _shuffleOrder.reset(0);
      _currentIndex = songs.isEmpty ? null : 0;
    }

    if (_currentIndex != null) {
      await _loadCurrentSong();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;

    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> play() async {
    if (currentSong == null) {
      return;
    }

    await _player.play();
  }

  Future<void> playAt(int index) async {
    if (_shuffleEnabled) {
      return;
    }

    if (index < 0 || index >= _songs.length) {
      throw RangeError.index(index, _songs, 'index');
    }

    final wasPlaying = _player.playing;

    _currentIndex = index;

    await _loadCurrentSong();

    if (wasPlaying) {
      unawaited(_player.play());
    }
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
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);

    playbackState.add(
      _toPlaybackState(_player.playbackEvent),
    );
  }

  @override
  Future<void> skipToPrevious() async {
    if (!canGoPrevious) {
      return;
    }

    final wasPlaying = _player.playing;

    if (_shuffleEnabled) {
      _currentIndex = _shuffleOrder.movePrevious();
    } else {
      _currentIndex = _currentIndex! - 1;
    }

    await _loadCurrentSong();

    if (wasPlaying) {
      unawaited(_player.play());
    }
  }

  @override
  Future<void> skipToNext() async {
    if (!canGoNext) {
      return;
    }

    final wasPlaying = _player.playing;

    if (_shuffleEnabled) {
      _currentIndex = _shuffleOrder.moveNext();
    } else {
      _currentIndex = _currentIndex! + 1;
    }

    await _loadCurrentSong();

    if (wasPlaying) {
      unawaited(_player.play());
    }
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _metadataController.close();
  }

  Future<void> _loadCurrentSong() async {
    final song = currentSong!;

    debugPrint('[audio] loading: ${song.relativePath}');

    _currentMetadata = null;
    _metadataController.add(null);

    _publishCurrentMediaItem();

    await _player.setAudioSource(
      just_audio.AudioSource.uri(Uri.parse(song.uri)),
    );

    unawaited(_loadCurrentMetadata(song));
  }

  Future<void> _loadCurrentMetadata(Song song) async {
    final metadata = await _metadataReader.read(song);

    // Ignore a result if another track was selected while extraction
    // was still running.
    if (currentSong?.uri != song.uri) {
      return;
    }

    _currentMetadata = metadata;
    _metadataController.add(metadata);

    _publishCurrentMediaItem(
      duration: _player.duration,
      metadata: metadata,
    );
  }

  void _publishCurrentMediaItem({
    Duration? duration,
    SongMetadata? metadata,
  }) {
    final song = currentSong;

    if (song == null) {
      return;
    }

    mediaItem.add(
      MediaItem(
        id: song.uri,
        title:
        metadata?.title ?? PathUtils.basename(song.relativePath),
        artist:
        metadata?.artist ??
            metadata?.albumArtist ??
            'Unknown artist',
        album:
        metadata?.album ?? PathUtils.parent(song.relativePath),
        duration: duration,
        extras: {
          if (metadata?.trackNumber != null)
            'trackNumber': metadata!.trackNumber,
          if (metadata?.year != null)
            'year': metadata!.year,
        },
      ),
    );
  }

  PlaybackState _toPlaybackState(just_audio.PlaybackEvent event) {
    final controls = <MediaControl>[
      if (canGoPrevious) MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      if (canGoNext) MediaControl.skipToNext,
      MediaControl.stop,
    ];

    return PlaybackState(
      controls: controls,
      repeatMode: _repeatMode,
      shuffleMode: _shuffleEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: List.generate(
        controls.length > 3 ? 3 : controls.length,
        (index) => index,
      ),
      processingState: switch (_player.processingState) {
        just_audio.ProcessingState.idle => AudioProcessingState.idle,
        just_audio.ProcessingState.loading => AudioProcessingState.loading,
        just_audio.ProcessingState.buffering => AudioProcessingState.buffering,
        just_audio.ProcessingState.ready => AudioProcessingState.ready,
        just_audio.ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: queuePosition,
    );
  }
}
