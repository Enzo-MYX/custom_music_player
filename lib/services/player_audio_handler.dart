import 'dart:async';
import 'dart:collection';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

import '../models/song.dart';
import '../models/song_metadata.dart';
import '../models/playback_resume_state.dart';
import '../models/tuning_settings.dart';
import 'metadata_reader.dart';
import 'path_utils.dart';
import 'shuffle_order.dart';

class PlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  final just_audio.AudioPlayer _player = just_audio.AudioPlayer();
  final ShuffleOrder _shuffleOrder = ShuffleOrder();
  final MetadataReader _metadataReader = MetadataReader();

  final StreamController<SongMetadata?> _metadataController =
      StreamController<SongMetadata?>.broadcast();
  final StreamController<void> _resumeCheckpointController =
      StreamController<void>.broadcast();

  SongMetadata? _currentMetadata;

  // Each loaded track receives a new generation. This prevents an older
  // asynchronous metadata request from updating a newly selected track,
  // including when two queue entries point to the same URI.
  int _trackLoadGeneration = 0;
  int? _metadataRequestedForGeneration;

  List<Song> _songs = const [];
  int? _currentIndex;
  AudioServiceRepeatMode _normalRepeatMode = AudioServiceRepeatMode.none;
  AudioServiceRepeatMode _shuffleRepeatMode = AudioServiceRepeatMode.none;
  bool _shuffleEnabled = false;
  TuningSettings _tuningSettings = TuningSettings.defaults;

  void applyTuningSettings(TuningSettings settings) {
    _tuningSettings = settings;
    playbackState.add(_toPlaybackState(_player.playbackEvent));
  }

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

  Stream<void> get resumeCheckpointStream => _resumeCheckpointController.stream;

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

  AudioServiceRepeatMode get repeatMode =>
      _shuffleEnabled ? _shuffleRepeatMode : _normalRepeatMode;

  PlaybackResumeState? get resumeState {
    final index = _currentIndex;
    if (index == null || _songs.isEmpty) return null;
    return PlaybackResumeState(
      songs: List<Song>.of(_songs),
      currentIndex: index,
      shuffleEnabled: _shuffleEnabled,
      shuffleOrder: _shuffleOrder.indices,
      shufflePosition: _shuffleOrder.position,
      positionMilliseconds: _player.position.inMilliseconds,
      speed: _player.speed,
      normalRepeatMode: _normalRepeatMode,
      shuffleRepeatMode: _shuffleRepeatMode,
    );
  }

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

      if (repeatMode == AudioServiceRepeatMode.one) {
        await _player.seek(Duration.zero);
        _requestResumeCheckpoint();
        unawaited(_player.play());
        return;
      }

      if (canGoNext) {
        await skipToNext();
        return;
      }

      if (repeatMode == AudioServiceRepeatMode.all && _songs.isNotEmpty) {
        if (_shuffleEnabled) {
          final previousIndex = _currentIndex;

          _shuffleOrder.reset(_songs.length, avoidFirstIndex: previousIndex);

          _currentIndex = _shuffleOrder.currentIndex;
        } else {
          _currentIndex = 0;
        }

        await _loadCurrentSong();
        _requestResumeCheckpoint();
        unawaited(_player.play());
        return;
      }

      await _player.pause();
      await _player.seek(Duration.zero);
      _requestResumeCheckpoint();
    });
  }

  Future<void> setSongs(List<Song> songs) {
    return _loadSongs(songs, shuffle: false);
  }

  Future<void> startNormalQueue(List<Song> songs, int initialIndex) async {
    if (initialIndex < 0 || initialIndex >= songs.length) {
      throw RangeError.index(initialIndex, songs, 'initialIndex');
    }

    await _player.stop();
    await _player.setSpeed(_tuningSettings.defaultPlaybackSpeed);

    _songs = songs;
    _shuffleEnabled = false;
    _shuffleOrder.reset(0);
    _currentIndex = initialIndex;

    await _loadCurrentSong();
    await _startPlayback();
    _requestResumeCheckpoint();
  }

  Future<bool> updateNormalQueue(List<Song> songs) async {
    if (_shuffleEnabled) {
      return false;
    }

    final current = currentSong;
    if (current == null) {
      return false;
    }

    final newIndex = songs.indexWhere((song) => song.uri == current.uri);

    if (newIndex < 0) {
      return false;
    }

    // Do not reload the source. The current track, position, playing state,
    // metadata request, and playback speed are all preserved.
    _songs = songs;
    _currentIndex = newIndex;

    playbackState.add(_toPlaybackState(_player.playbackEvent));

    _requestResumeCheckpoint();

    return true;
  }

  Future<void> startShuffle(List<Song> songs) async {
    await _loadSongs(songs, shuffle: true);

    if (_currentIndex != null) {
      await _startPlayback();
    }
  }

  Future<bool> restore(PlaybackResumeState state) async {
    if (!state.isValid) return false;

    try {
      await _player.stop();
      _songs = List<Song>.of(state.songs);
      _shuffleEnabled = state.shuffleEnabled;
      _currentIndex = state.currentIndex;
      _normalRepeatMode = state.normalRepeatMode;
      _shuffleRepeatMode = state.shuffleRepeatMode;
      if (_shuffleEnabled) {
        _shuffleOrder.restore(state.shuffleOrder, state.shufflePosition);
      } else {
        _shuffleOrder.reset(0);
      }
      await _player.setSpeed(state.speed);
      await _loadCurrentSong();
      await seek(state.position);
      playbackState.add(_toPlaybackState(_player.playbackEvent));
      _requestResumeCheckpoint();
      return true;
    } catch (_) {
      await _player.stop();
      _songs = const [];
      _currentIndex = null;
      _shuffleEnabled = false;
      _shuffleOrder.reset(0);
      return false;
    }
  }

  Future<void> _loadSongs(List<Song> songs, {required bool shuffle}) async {
    debugPrint(
      '[audio] loadSongs: ${songs.length} songs, '
      'shuffle=$shuffle',
    );

    await _player.stop();
    await _player.setSpeed(_tuningSettings.defaultPlaybackSpeed);

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
    _requestResumeCheckpoint();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (_shuffleEnabled) {
      _shuffleRepeatMode = repeatMode;
    } else {
      _normalRepeatMode = repeatMode;
    }

    // Re-sample the player rather than copying the last AudioService state.
    // Its updatePosition is a timestamped snapshot; republishing an older
    // snapshot makes AudioService.position briefly jump backwards (and, on
    // some devices, all the way to zero) when only repeat mode changed.
    playbackState.add(_toPlaybackState(_player.playbackEvent));
    _requestResumeCheckpoint();
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
    _requestResumeCheckpoint();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _requestResumeCheckpoint();
  }

  // Called when either the playback-screen slider or the system
  // notification/lock-screen slider is moved.
  @override
  Future<void> seek(Duration position) async {
    final duration = _player.duration;
    var target = position;

    if (target.isNegative) {
      target = Duration.zero;
    }

    if (duration != null && target > duration) {
      target = duration;
    }

    await _player.seek(target);
    _requestResumeCheckpoint();
  }

  /// Moves by the configured seek interval without changing the current track.
  @override
  Future<void> rewind() async {
    final target =
        _player.position - Duration(seconds: _tuningSettings.seekSeconds);
    await seek(target.isNegative ? Duration.zero : target);
  }

  /// Moves by the configured seek interval, continuing at the next track
  /// when the current track is exhausted.
  @override
  Future<void> fastForward() async {
    final duration = _player.duration;
    final target =
        _player.position + Duration(seconds: _tuningSettings.seekSeconds);

    if (duration != null && target >= duration) {
      if (canGoNext) {
        await skipToNext();
      } else {
        await seek(duration);
      }
      return;
    }

    await seek(target);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);

    playbackState.add(_toPlaybackState(_player.playbackEvent));
    _requestResumeCheckpoint();
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
    _requestResumeCheckpoint();
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
    _requestResumeCheckpoint();
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _metadataController.close();
    await _resumeCheckpointController.close();
  }

  void _requestResumeCheckpoint() {
    if (!_resumeCheckpointController.isClosed) {
      _resumeCheckpointController.add(null);
    }
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

    final load = _player
        .setAudioSource(just_audio.AudioSource.uri(Uri.parse(song.uri)))
        .then((_) => true);
    final loadedBeforeTimeout = await Future.any<bool>([
      load,
      Future<bool>.delayed(
        Duration(seconds: _tuningSettings.loadTimeoutSeconds),
        () => false,
      ),
    ]);

    if (!loadedBeforeTimeout) {
      debugPrint(
        '[audio] load exceeded ${_tuningSettings.loadTimeoutSeconds} seconds: '
        '${song.relativePath}',
      );
      await _metadataReader.logPlaybackError(song.relativePath);

      // Starting another source interrupts the timed-out setAudioSource call.
      // Future.any remains subscribed to it, so that expected late interruption
      // cannot surface as an unhandled asynchronous error.
      if (generation != _trackLoadGeneration) {
        return;
      }

      if (canGoNext) {
        if (_shuffleEnabled) {
          _currentIndex = _shuffleOrder.moveNext();
        } else {
          _currentIndex = _currentIndex! + 1;
        }

        _requestResumeCheckpoint();
        await _loadCurrentSong();
      } else {
        // There is nowhere to skip to. Clear the unusable current item so a
        // queue-start caller cannot accidentally try to play it afterward.
        ++_trackLoadGeneration;
        _currentIndex = null;
        _currentMetadata = null;
        _metadataController.add(null);
        mediaItem.add(null);
        await _player.stop();
        playbackState.add(_toPlaybackState(_player.playbackEvent));
        _requestResumeCheckpoint();
      }
      return;
    }

    // Some source changes preserve the player's playing state and therefore
    // do not emit another `true` event on playingStream.
    if (_player.playing && generation == _trackLoadGeneration) {
      _startCurrentMetadataIfNeeded();
    }
  }

  /// Starts playback and returns as soon as the player reports that it has
  /// started. The Future returned by just_audio's play() normally remains
  /// pending until playback stops, so it must not be awaited directly.
  Future<void> _startPlayback() async {
    if (currentSong == null) {
      return;
    }

    final started = _player.playingStream
        .firstWhere((playing) => playing)
        .then<void>((_) {});
    final playbackFinished = _player.play();
    await Future.any<void>([started, playbackFinished]);
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
    unawaited(_loadCurrentLyrics(song, generation));
  }

  Future<void> _loadCurrentMetadata(Song song, int generation) async {
    final loadedMetadata = await _metadataReader.read(song);

    // Ignore stale results when the user changes tracks while extraction is
    // running. The generation check also handles duplicate queue URIs.
    if (generation != _trackLoadGeneration || currentSong?.uri != song.uri) {
      return;
    }

    // Lyrics may have completed first, so preserve them when the independent
    // metadata request catches up.
    final metadata = SongMetadata(
      title: loadedMetadata.title,
      artist: loadedMetadata.artist,
      album: loadedMetadata.album,
      albumArtist: loadedMetadata.albumArtist,
      trackNumber: loadedMetadata.trackNumber,
      year: loadedMetadata.year,
      artwork: loadedMetadata.artwork,
      lyrics: _currentMetadata?.lyrics,
    );
    _currentMetadata = metadata;
    _metadataController.add(metadata);

    // PlaybackScreen already listens to currentMetadataStream, so its title,
    // artist, album, artwork, and lyrics populate as soon as this is emitted.
    _publishCurrentMediaItem(duration: _player.duration, metadata: metadata);
  }

  Future<void> _loadCurrentLyrics(Song song, int generation) async {
    final lyrics = await _metadataReader.readLyrics(song);

    if (generation != _trackLoadGeneration || currentSong?.uri != song.uri) {
      return;
    }

    final current = _currentMetadata ?? const SongMetadata();
    final metadata = SongMetadata(
      title: current.title,
      artist: current.artist,
      album: current.album,
      albumArtist: current.albumArtist,
      trackNumber: current.trackNumber,
      year: current.year,
      artwork: current.artwork,
      lyrics: lyrics,
    );
    _currentMetadata = metadata;
    _metadataController.add(metadata);
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

    // Keep the notification to three symmetric transport actions. Android
    // lays these out as one centred group, with play/pause in the middle.
    // Dedicated icons also make the five-second interval explicit instead of
    // presenting Android's generic rewind/fast-forward glyphs.
    final seekSeconds = _tuningSettings.seekSeconds;
    final controls = <MediaControl>[
      MediaControl(
        androidIcon: 'drawable/audio_service_replay_5',
        label: 'Back $seekSeconds seconds',
        action: MediaAction.rewind,
      ),
      playPauseControl,
      MediaControl(
        androidIcon: 'drawable/audio_service_forward_5',
        label: 'Forward $seekSeconds seconds',
        action: MediaAction.fastForward,
      ),
    ];

    return PlaybackState(
      controls: controls,

      // Enables dragging the Android notification and lock-screen progress bar.
      systemActions: const {MediaAction.seek},

      // All three actions remain visible in the compact notification.
      androidCompactActionIndices: const [0, 1, 2],
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
      repeatMode: repeatMode,
      shuffleMode: _shuffleEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }
}
