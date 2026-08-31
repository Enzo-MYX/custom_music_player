import 'package:audio_service/audio_service.dart';

import 'song.dart';

class PlaybackResumeState {
  static const int currentVersion = 1;

  final List<Song> songs;
  final int currentIndex;
  final bool shuffleEnabled;
  final List<int> shuffleOrder;
  final int shufflePosition;
  final int positionMilliseconds;
  final double speed;
  final AudioServiceRepeatMode repeatMode;

  const PlaybackResumeState({
    required this.songs,
    required this.currentIndex,
    required this.shuffleEnabled,
    required this.shuffleOrder,
    required this.shufflePosition,
    required this.positionMilliseconds,
    required this.speed,
    required this.repeatMode,
  });

  Duration get position => Duration(milliseconds: positionMilliseconds);

  Map<String, dynamic> toJson() => {
    'version': currentVersion,
    'songs': songs.map((song) => song.toJson()).toList(),
    'currentIndex': currentIndex,
    'shuffleEnabled': shuffleEnabled,
    'shuffleOrder': shuffleOrder,
    'shufflePosition': shufflePosition,
    'positionMilliseconds': positionMilliseconds,
    'speed': speed,
    'repeatMode': repeatMode.name,
  };

  factory PlaybackResumeState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != currentVersion) {
      throw const FormatException('Unsupported resume-state version');
    }

    final songsJson = json['songs'];
    final orderJson = json['shuffleOrder'];
    if (songsJson is! List || orderJson is! List) {
      throw const FormatException('Invalid resume-state lists');
    }

    final repeatName = json['repeatMode'] as String?;
    final repeatMode = AudioServiceRepeatMode.values.firstWhere(
      (mode) => mode.name == repeatName,
      orElse: () => AudioServiceRepeatMode.none,
    );

    return PlaybackResumeState(
      songs: songsJson
          .map(
            (value) => Song.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false),
      currentIndex: json['currentIndex'] as int,
      shuffleEnabled: json['shuffleEnabled'] as bool,
      shuffleOrder: orderJson.cast<int>().toList(growable: false),
      shufflePosition: json['shufflePosition'] as int,
      positionMilliseconds: json['positionMilliseconds'] as int,
      speed: (json['speed'] as num).toDouble(),
      repeatMode: repeatMode,
    );
  }

  bool get isValid {
    if (songs.isEmpty || currentIndex < 0 || currentIndex >= songs.length) {
      return false;
    }
    if (positionMilliseconds < 0 || speed <= 0) {
      return false;
    }
    if (!shuffleEnabled) {
      return true;
    }
    return shuffleOrder.length == songs.length &&
        shuffleOrder.toSet().length == songs.length &&
        shuffleOrder.every((index) => index >= 0 && index < songs.length) &&
        shufflePosition >= 0 &&
        shufflePosition < shuffleOrder.length &&
        shuffleOrder[shufflePosition] == currentIndex;
  }
}
