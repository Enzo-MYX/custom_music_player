import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';

import '../services/playback_controller.dart';
import 'playback_seek_bar.dart';

class PlaybackScreen extends StatefulWidget {
  final PlaybackController controller;

  const PlaybackScreen({super.key, required this.controller});

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  Future<void> _run(Future<void> action) async {
    await action;

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.controller.currentSongStream,
      initialData: widget.controller.currentSong,
      builder: (context, snapshot) {
        final song = snapshot.data;

        return Scaffold(
          appBar: AppBar(title: const Text('Now Playing')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: song == null
                ? const Center(child: Text('No song loaded.'))
                : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  song.relativePath,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(widget.controller.currentIndex ?? 0) + 1} '
                      'of ${widget.controller.songCount}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                _buildSeekBar(),
                const SizedBox(height: 12),
                _buildControls(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeekBar() {
    return PlaybackSeekBar(
      durationStream: widget.controller.durationStream,
      positionStream: widget.controller.positionStream,
      onSeek: widget.controller.seek,
    );
  }

  Widget _buildControls() {
    return StreamBuilder<AudioServiceRepeatMode>(
      stream: widget.controller.repeatModeStream,
      initialData: widget.controller.repeatMode,
      builder: (context, repeatSnapshot) {
        final repeatMode =
            repeatSnapshot.data ?? AudioServiceRepeatMode.none;

        return StreamBuilder<bool>(
          stream: widget.controller.playingStream,
          initialData: false,
          builder: (context, playingSnapshot) {
            final isPlaying = playingSnapshot.data ?? false;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: switch (repeatMode) {
                    AudioServiceRepeatMode.all => 'Repeat all',
                    AudioServiceRepeatMode.one => 'Repeat one',
                    _ => 'Repeat off',
                  },
                  onPressed: () => _run(
                    widget.controller.cycleRepeatMode(),
                  ),
                  icon: Icon(
                    switch (repeatMode) {
                      AudioServiceRepeatMode.none => Icons.queue_music,
                      AudioServiceRepeatMode.all => Icons.repeat,
                      AudioServiceRepeatMode.one => Icons.repeat_one,
                      _ => Icons.queue_music,
                    },
                    color: repeatMode == AudioServiceRepeatMode.none
                        ? Colors.grey
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                IconButton(
                  tooltip: 'Previous',
                  onPressed: widget.controller.canGoPrevious
                      ? () => _run(widget.controller.previous())
                      : null,
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton(
                  tooltip: isPlaying ? 'Pause' : 'Play',
                  iconSize: 48,
                  onPressed: () => _run(
                    isPlaying
                        ? widget.controller.pause()
                        : widget.controller.play(),
                  ),
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                  ),
                ),
                IconButton(
                  tooltip: 'Next',
                  onPressed: widget.controller.canGoNext
                      ? () => _run(widget.controller.next())
                      : null,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            );
          },
        );
      },
    );
  }
}