import 'dart:async';
import 'dart:collection';

import 'package:audio_service/audio_service.dart';

import '../models/song.dart';
import '../models/song_metadata.dart';
import '../models/tuning_settings.dart';
import 'player_audio_handler.dart';
import 'settings_storage.dart';

class PlaybackController {
  final PlayerAudioHandler _handler;
  final SettingsStorage _storage;
  String? _lastSavedState;
  Future<void> _saveChain = Future<void>.value();
  late final StreamSubscription<void> _checkpointSubscription;
  final StreamController<TuningSettings> _tuningSettingsController =
      StreamController<TuningSettings>.broadcast();
  TuningSettings _tuningSettings = TuningSettings.defaults;

  PlaybackController(this._handler, {SettingsStorage? storage})
    : _storage = storage ?? SettingsStorage() {
    _checkpointSubscription = _handler.resumeCheckpointStream.listen(
      (_) => unawaited(checkpoint().catchError((Object _) {})),
    );
  }

  Future<void> initialize() async {
    _tuningSettings = await _storage.loadTuningSettings();
    _handler.applyTuningSettings(_tuningSettings);
    final state = await _storage.loadPlaybackResumeState();
    if (state == null) return;
    if (!await _handler.restore(state)) {
      await _storage.clearPlaybackResumeState();
    } else {
      _lastSavedState = state.toJson().toString();
    }
  }

  Future<void> checkpoint() {
    final state = _handler.resumeState;
    Future<void> save() async {
      if (state == null) {
        if (_lastSavedState != null) {
          await _storage.clearPlaybackResumeState();
          _lastSavedState = null;
        }
        return;
      }
      final serialized = state.toJson().toString();
      if (serialized == _lastSavedState) return;
      await _storage.savePlaybackResumeState(state);
      _lastSavedState = serialized;
    }

    _saveChain = _saveChain.then((_) => save(), onError: (_) => save());
    return _saveChain;
  }

  Stream<bool> get playingStream =>
      _handler.playbackState.map((state) => state.playing).distinct();

  Stream<Duration?> get durationStream => _handler.durationStream;

  Stream<Duration> get positionStream => AudioService.position;

  Duration get position => _handler.position;

  Duration? get duration => _handler.duration;

  double get speed => _handler.speed;

  TuningSettings get tuningSettings => _tuningSettings;

  Stream<TuningSettings> get tuningSettingsStream =>
      _tuningSettingsController.stream;

  Future<void> updateTuningSettings(TuningSettings settings) async {
    _tuningSettings = settings;
    _handler.applyTuningSettings(settings);
    _tuningSettingsController.add(settings);
    await _storage.saveTuningSettings(settings);
  }

  bool get playing => _handler.playing;

  bool get shuffleEnabled => _handler.shuffleEnabled;

  UnmodifiableListView<Song> get songs => _handler.songs;

  Stream<double> get speedStream =>
      _handler.playbackState.map((state) => state.speed).distinct();

  Song? get currentSong => _handler.currentSong;

  bool get canGoPrevious => _handler.canGoPrevious;

  bool get canGoNext => _handler.canGoNext;

  Stream<Song?> get currentSongStream => _handler.currentSongStream;

  int? get currentIndex => _handler.queuePosition;

  int get songCount => _handler.songCount;

  SongMetadata? get currentMetadata => _handler.currentMetadata;

  Stream<SongMetadata?> get currentMetadataStream =>
      _handler.currentMetadataStream;

  AudioServiceRepeatMode get repeatMode => _handler.repeatMode;

  Stream<AudioServiceRepeatMode> get repeatModeStream =>
      _handler.playbackState.map((state) => state.repeatMode).distinct();

  Future<void> setSongs(List<Song> songs) {
    return _thenCheckpoint(_handler.setSongs(songs));
  }

  Future<void> startNormalQueue(List<Song> songs, int initialIndex) {
    return _thenCheckpoint(_handler.startNormalQueue(songs, initialIndex));
  }

  Future<bool> updateNormalQueue(List<Song> songs) {
    return _handler.updateNormalQueue(songs).then((updated) async {
      if (updated) await checkpoint();
      return updated;
    });
  }

  Future<void> startShuffle(List<Song> songs) {
    return _thenCheckpoint(_handler.startShuffle(songs));
  }

  Future<void> play() {
    return _handler.play();
  }

  Future<void> playAt(int index) {
    return _thenCheckpoint(_handler.playAt(index));
  }

  Future<void> pause() {
    return _thenCheckpoint(_handler.pause());
  }

  Future<void> seek(Duration position) {
    return _thenCheckpoint(_handler.seek(position));
  }

  Future<void> seekBy(Duration offset) {
    final duration = _handler.duration;
    var target = _handler.position + offset;

    if (target.isNegative) {
      target = Duration.zero;
    }

    if (duration != null && target > duration) {
      target = duration;
    }

    return _handler.seek(target);
  }

  Future<void> rewindInterval() {
    return seekBy(Duration(seconds: -_tuningSettings.seekSeconds));
  }

  Future<void> forwardInterval() {
    return seekBy(Duration(seconds: _tuningSettings.seekSeconds));
  }

  Future<void> setSpeed(double speed) {
    return _thenCheckpoint(_handler.setSpeed(speed));
  }

  Future<void> previous() {
    return _thenCheckpoint(_handler.skipToPrevious());
  }

  Future<void> next() {
    return _thenCheckpoint(_handler.skipToNext());
  }

  Future<void> cycleRepeatMode() {
    final nextMode = switch (_handler.repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.none,
    };

    return _thenCheckpoint(_handler.setRepeatMode(nextMode));
  }

  Future<void> dispose() {
    return checkpoint().whenComplete(() async {
      await _checkpointSubscription.cancel();
      await _tuningSettingsController.close();
      await _handler.dispose();
    });
  }

  Future<void> _thenCheckpoint(Future<void> operation) async {
    await operation;
    await checkpoint();
  }
}
