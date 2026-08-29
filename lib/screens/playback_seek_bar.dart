import 'package:flutter/material.dart';

typedef SeekCallback = Future<void> Function(Duration position);

class PlaybackSeekBar extends StatefulWidget {
  final Stream<Duration?> durationStream;
  final Stream<Duration> positionStream;
  final SeekCallback onSeek;

  const PlaybackSeekBar({
    super.key,
    required this.durationStream,
    required this.positionStream,
    required this.onSeek,
  });

  @override
  State<PlaybackSeekBar> createState() => _PlaybackSeekBarState();
}

class _PlaybackSeekBarState extends State<PlaybackSeekBar> {
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: widget.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data;
        final durationMilliseconds = duration?.inMilliseconds ?? 0;
        final canSeek = durationMilliseconds > 0;
        final maximum = canSeek ? durationMilliseconds.toDouble() : 1.0;

        return StreamBuilder<Duration>(
          stream: widget.positionStream,
          builder: (context, positionSnapshot) {
            final streamedPosition = positionSnapshot.data ?? Duration.zero;
            final displayedPosition = _clampPosition(
              _dragPosition ?? streamedPosition,
              duration,
            );
            final value = displayedPosition.inMilliseconds.toDouble();

            return Column(
              children: [
                Slider(
                  value: value.clamp(0.0, maximum),
                  max: maximum,
                  onChanged: canSeek
                      ? (milliseconds) {
                          setState(() {
                            _dragPosition = Duration(
                              milliseconds: milliseconds.round(),
                            );
                          });
                        }
                      : null,
                  onChangeEnd: canSeek
                      ? (milliseconds) async {
                          final seekPosition = Duration(
                            milliseconds: milliseconds.round(),
                          );
                          await widget.onSeek(seekPosition);

                          if (mounted) {
                            setState(() {
                              _dragPosition = null;
                            });
                          }
                        }
                      : null,
                ),
                Text(
                  '${formatPlaybackDuration(displayedPosition)} / '
                  '${formatPlaybackDuration(duration ?? Duration.zero)}',
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Duration _clampPosition(Duration position, Duration? duration) {
  if (position.isNegative) {
    return Duration.zero;
  }

  if (duration != null && position > duration) {
    return duration;
  }

  return position;
}

String formatPlaybackDuration(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final hours = safeDuration.inHours;
  final minutes = safeDuration.inMinutes.remainder(60);
  final seconds = safeDuration.inSeconds.remainder(60);
  String twoDigits(int value) => value.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  return '${safeDuration.inMinutes}:${twoDigits(seconds)}';
}
