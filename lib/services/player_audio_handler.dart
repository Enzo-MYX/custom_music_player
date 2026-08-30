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

  // Each loaded track receives a new generation. This prevents an older
  // asynchronous metadata request from updating a newly selected track,
  // including when two queue entries point to the same URI.
  int _trackLoadGeneration = 0;
  int? _metadataRequestedForGeneration;

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

  Stream<SongMetadata?> get currentMetadataStream => _metadataController.stream;

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

    // Metadata is secondary to playback. Begin extraction only after the
    // selected track has actually entered the playing state, and never await
    // it from the playback path.
    _player.playingStream.distinct().listen((playing) {
      if (playing) {
        _startCurrentMetadataIfNeeded();
      }
    });

    // Android needs a MediaItem with a duration before it can display
    // a usable notification and lock-screen seek bar.
    _player.durationStream.listen((duration) {
      debugPrint('[audio] duration: $duration');

      if (duration != null && currentSong != null) {
        _publishCurrentMediaItem(
          duration: duration,
          metadata: _currentMetadata,
        );
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

  Future<void> startNormalQueue(
      List<Song> songs,
      int initialIndex,
      ) async {
    if (initialIndex < 0 || initialIndex >= songs.length) {
      throw RangeError.index(initialIndex, songs, 'initialIndex');
    }

    await _player.stop();
    await _player.setSpeed(1.0);

    _songs = songs;
    _shuffleEnabled = false;
    _shuffleOrder.reset(0);
    _currentIndex = initialIndex;

    await _loadCurrentSong();
    unawaited(_player.play());
  }

  Future<bool> updateNormalQueue(List<Song> songs) async {
    if (_shuffleEnabled) {
      return false;
    }

    final current = currentSong;
    if (current == null) {
      return false;
    }

    final newIndex = songs.indexWhere(
          (song) => song.uri == current.uri,
    );

    if (newIndex < 0) {
      return false;
    }

    // Do not reload the source. The current track, position, playing state,
    // metadata request, and playback speed are all preserved.
    _songs = songs;
    _currentIndex = newIndex;

    playbackState.add(
      _toPlaybackState(_player.playbackEvent),
    );

    return true;
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

  // Called when either the playback-screen slider or the system
  // notification/lock-screen slider is moved.
  @override
  Future<void> seek(Duration position) {
    final duration = _player.duration;
    var target = position;

    if (target.isNegative) {
      target = Duration.zero;
    }

    if (duration != null && target > duration) {
      target = duration;
    }

    return _player.seek(target);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);

    playbackState.add(_toPlaybackState(_player.playbackEvent));
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
    final generation = ++_trackLoadGeneration;

    debugPrint('[audio] loading: ${song.relativePath}');

    _metadataRequestedForGeneration = null;
    _currentMetadata = null;
    _metadataController.add(null);

    // Publish the lightweight item immediately. Loading the audio source and
    // starting playback do not depend on metadata or embedded artwork.
    _publishCurrentMediaItem();

    await _player.setAudioSource(
      just_audio.AudioSource.uri(Uri.parse(song.uri)),
    );

    // Some source changes preserve the player's playing state and therefore
    // do not emit another `true` event on playingStream.
    if (_player.playing && generation == _trackLoadGeneration) {
      _startCurrentMetadataIfNeeded();
    }
  }

  void _startCurrentMetadataIfNeeded() {
    final song = currentSong;
    final generation = _trackLoadGeneration;

    if (song == null ||
        !_player.playing ||
        _metadataRequestedForGeneration == generation) {
      return;
    }

    _metadataRequestedForGeneration = generation;
    unawaited(_loadCurrentMetadata(song, generation));
  }

  Future<void> _loadCurrentMetadata(Song song, int generation) async {
    final metadata = await _metadataReader.read(song);

    // Ignore stale results when the user changes tracks while extraction is
    // running. The generation check also handles duplicate queue URIs.
    if (generation != _trackLoadGeneration || currentSong?.uri != song.uri) {
      return;
    }

    _currentMetadata = metadata;
    _metadataController.add(metadata);

    // PlaybackScreen already listens to currentMetadataStream, so its title,
    // artist, album, artwork, and lyrics populate as soon as this is emitted.
    _publishCurrentMediaItem(duration: _player.duration, metadata: metadata);
  }

  void _publishCurrentMediaItem({Duration? duration, SongMetadata? metadata}) {
    final song = currentSong;

    if (song == null) {
      return;
    }

    // Preserve previously extracted metadata when this update comes from
    // durationStream rather than the metadata reader.
    final effectiveMetadata = metadata ?? _currentMetadata;

    mediaItem.add(
      MediaItem(
        id: song.uri,
        title:
            effectiveMetadata?.title ?? PathUtils.basename(song.relativePath),
        artist:
            effectiveMetadata?.artist ??
            effectiveMetadata?.albumArtist ??
            'Unknown artist',
        album: effectiveMetadata?.album ?? PathUtils.parent(song.relativePath),

        // A non-null duration allows Android to render the seek bar.
        duration: duration ?? _player.duration,
        extras: {
          if (effectiveMetadata?.trackNumber != null)
            'trackNumber': effectiveMetadata!.trackNumber,
          if (effectiveMetadata?.year != null) 'year': effectiveMetadata!.year,
        },
      ),
    );
  }

  PlaybackState _toPlaybackState(just_audio.PlaybackEvent event) {
    // Use one stable action while only changing its icon. Some Android skins
    // cache the old notification action when Pause is replaced with Play.
    final playPauseControl = MediaControl(
      androidIcon: _player.playing
          ? 'drawable/audio_service_pause'
          : 'drawable/audio_service_play_arrow',
      label: _player.playing ? 'Pause' : 'Play',
      action: MediaAction.playPause,
    );

    final controls = <MediaControl>[
      if (canGoPrevious) MediaControl.skipToPrevious,
      playPauseControl,
      if (canGoNext) MediaControl.skipToNext,
      MediaControl.stop,
    ];

    return PlaybackState(
      controls: controls,

      // Enables dragging the Android notification and lock-screen progress bar.
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

      // Android extrapolates the live notification position from these values.
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,

      queueIndex: queuePosition,
      repeatMode: _repeatMode,
      shuffleMode: _shuffleEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }
}
