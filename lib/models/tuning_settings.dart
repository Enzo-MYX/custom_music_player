class TuningSettings {
  static const defaults = TuningSettings(
    nightMode: false,
    loadTimeoutSeconds: 10,
    seekSeconds: 5,
    defaultPlaybackSpeed: 1.0,
    playbackSpeeds: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    carouselMinFlingDistance: 4,
    carouselMinFlingVelocity: 50,
  );

  final bool nightMode;
  final int loadTimeoutSeconds;
  final int seekSeconds;
  final double defaultPlaybackSpeed;
  final List<double> playbackSpeeds;
  final double carouselMinFlingDistance;
  final double carouselMinFlingVelocity;

  const TuningSettings({
    required this.nightMode,
    required this.loadTimeoutSeconds,
    required this.seekSeconds,
    required this.defaultPlaybackSpeed,
    required this.playbackSpeeds,
    required this.carouselMinFlingDistance,
    required this.carouselMinFlingVelocity,
  });

  Map<String, dynamic> toJson() => {
    'nightMode': nightMode,
    'loadTimeoutSeconds': loadTimeoutSeconds,
    'seekSeconds': seekSeconds,
    'defaultPlaybackSpeed': defaultPlaybackSpeed,
    'playbackSpeeds': playbackSpeeds,
    'carouselMinFlingDistance': carouselMinFlingDistance,
    'carouselMinFlingVelocity': carouselMinFlingVelocity,
  };

  factory TuningSettings.fromJson(Map<String, dynamic> json) {
    final speeds =
        (json['playbackSpeeds'] as List<dynamic>?)
            ?.whereType<num>()
            .map((value) => value.toDouble())
            .where((value) => value >= 0.25 && value <= 4)
            .toSet()
            .toList()
          ?..sort();

    double validDouble(String key, double fallback, double min, double max) {
      final value = (json[key] as num?)?.toDouble();
      return value != null && value >= min && value <= max ? value : fallback;
    }

    int validInt(String key, int fallback, int min, int max) {
      final value = (json[key] as num?)?.toInt();
      return value != null && value >= min && value <= max ? value : fallback;
    }

    final defaultSpeed = validDouble(
      'defaultPlaybackSpeed',
      defaults.defaultPlaybackSpeed,
      0.25,
      4,
    );
    final normalizedSpeeds = speeds == null || speeds.isEmpty
        ? defaults.playbackSpeeds
        : speeds;

    return TuningSettings(
      nightMode: json['nightMode'] is bool
          ? json['nightMode'] as bool
          : defaults.nightMode,
      loadTimeoutSeconds: validInt(
        'loadTimeoutSeconds',
        defaults.loadTimeoutSeconds,
        1,
        300,
      ),
      seekSeconds: validInt('seekSeconds', defaults.seekSeconds, 1, 300),
      defaultPlaybackSpeed: defaultSpeed,
      playbackSpeeds: normalizedSpeeds.contains(defaultSpeed)
          ? normalizedSpeeds
          : ([...normalizedSpeeds, defaultSpeed]..sort()),
      carouselMinFlingDistance: validDouble(
        'carouselMinFlingDistance',
        defaults.carouselMinFlingDistance,
        0,
        1000,
      ),
      carouselMinFlingVelocity: validDouble(
        'carouselMinFlingVelocity',
        defaults.carouselMinFlingVelocity,
        0,
        10000,
      ),
    );
  }
}
