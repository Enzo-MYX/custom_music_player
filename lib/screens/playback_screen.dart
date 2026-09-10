import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';
import '../models/song_metadata.dart';
import '../models/tuning_settings.dart';
import '../services/path_utils.dart';
import '../services/playback_controller.dart';
import 'playback_queue_screen.dart';
import 'playback_seek_bar.dart';
import 'song_lyrics_view.dart';

class PlaybackScreen extends StatefulWidget {
  const PlaybackScreen({super.key, required this.controller});

  final PlaybackController controller;

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

  Future<void> _openQueue() async {
    if (widget.controller.shuffleEnabled) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaybackQueueScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Song?>(
      stream: widget.controller.currentSongStream,
      initialData: widget.controller.currentSong,
      builder: (context, snapshot) {
        final song = snapshot.data;

        return Scaffold(
          appBar: AppBar(title: const Text('Now Playing')),
          body: song == null
              ? const Center(child: Text('No song loaded.'))
              : OrientationBuilder(
                  builder: (context, orientation) {
                    if (orientation == Orientation.landscape) {
                      return _buildLandscape(song);
                    }

                    return _buildPortrait(song);
                  },
                ),
        );
      },
    );
  }

  Widget _buildPortrait(Song song) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 36,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildArtwork(
                    height: constraints.maxWidth.clamp(220, 340).toDouble(),
                  ),
                  const SizedBox(height: 20),
                  _buildMetadata(song),
                  const SizedBox(height: 24),
                  _buildLyrics(height: 160),
                  const SizedBox(height: 24),
                  _buildSeekBar(),
                  const SizedBox(height: 12),
                  _buildControls(landscape: false),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLandscape(Song song) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minimumContentHeight = 340.0;

          final contentHeight = constraints.maxHeight < minimumContentHeight
              ? minimumContentHeight
              : constraints.maxHeight;

          return SingleChildScrollView(
            reverse: true,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: SizedBox(
              height: contentHeight - 20,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 4, child: _buildArtwork()),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildMetadata(song),
                              const SizedBox(height: 8),
                              Expanded(child: _buildLyrics()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSeekBar(),
                  const SizedBox(height: 2),
                  _buildControls(landscape: true),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtwork({double? height}) {
    return StreamBuilder<SongMetadata?>(
      stream: widget.controller.currentMetadataStream,
      initialData: widget.controller.currentMetadata,
      builder: (context, snapshot) {
        final artwork = snapshot.data?.artwork;

        return Container(
          height: height,
          constraints: const BoxConstraints(minHeight: 120),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: artwork == null
              ? Image.asset(
                  'assets/images/driftwave_default_cover.gif',
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : Image.memory(
                  artwork,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image_outlined, size: 72),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildMetadata(Song song) {
    return StreamBuilder<SongMetadata?>(
      stream: widget.controller.currentMetadataStream,
      initialData: widget.controller.currentMetadata,
      builder: (context, snapshot) {
        final metadata = snapshot.data;

        final title = metadata?.title ?? PathUtils.basename(song.relativePath);

        final artist =
            metadata?.artist ?? metadata?.albumArtist ?? 'Unknown artist';

        final album =
            metadata?.album ??
            (PathUtils.parent(song.relativePath).isEmpty
                ? 'Unknown album'
                : PathUtils.parent(song.relativePath));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              album,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${(widget.controller.currentIndex ?? 0) + 1} '
              'of ${widget.controller.songCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLyrics({double? height}) {
    return SongLyricsView(
      height: height,
      metadataStream: widget.controller.currentMetadataStream,
      initialMetadata: widget.controller.currentMetadata,
      positionStream: widget.controller.positionStream,
    );
  }

  Widget _buildSeekBar() {
    return PlaybackSeekBar(
      durationStream: widget.controller.durationStream,
      positionStream: widget.controller.positionStream,
      initialPosition: widget.controller.position,
      onSeek: widget.controller.seek,
    );
  }

  Widget _buildControls({required bool landscape}) {
    return StreamBuilder<AudioServiceRepeatMode>(
      stream: widget.controller.repeatModeStream,
      initialData: widget.controller.repeatMode,
      builder: (context, repeatSnapshot) {
        final repeatMode = repeatSnapshot.data ?? AudioServiceRepeatMode.none;

        return StreamBuilder<double>(
          stream: widget.controller.speedStream,
          initialData: widget.controller.speed,
          builder: (context, speedSnapshot) {
            final speed = speedSnapshot.data ?? 1.0;

            return StreamBuilder<bool>(
              stream: widget.controller.playingStream,
              initialData: widget.controller.playing,
              builder: (context, playingSnapshot) {
                final isPlaying = playingSnapshot.data ?? false;

                if (landscape) {
                  return _buildLandscapeControls(
                    repeatMode: repeatMode,
                    speed: speed,
                    isPlaying: isPlaying,
                  );
                }

                return _buildPortraitControls(
                  repeatMode: repeatMode,
                  speed: speed,
                  isPlaying: isPlaying,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPortraitControls({
    required AudioServiceRepeatMode repeatMode,
    required double speed,
    required bool isPlaying,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_rewindButton(), _speedButton(speed), _forwardButton()],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _repeatButton(repeatMode),
            _previousButton(),
            _playPauseButton(isPlaying),
            _nextButton(),
            _queueButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildLandscapeControls({
    required AudioServiceRepeatMode repeatMode,
    required double speed,
    required bool isPlaying,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _repeatButton(repeatMode),
            _previousButton(),
            _rewindButton(),
            _playPauseButton(isPlaying),
            _forwardButton(),
            _nextButton(),
            _speedButton(speed),
            _queueButton(),
          ],
        ),
      ),
    );
  }

  Widget _repeatButton(AudioServiceRepeatMode repeatMode) {
    return IconButton(
      tooltip: switch (repeatMode) {
        AudioServiceRepeatMode.all => 'Repeat all',
        AudioServiceRepeatMode.one => 'Repeat one',
        _ => 'Repeat off',
      },
      onPressed: () {
        _run(widget.controller.cycleRepeatMode());
      },
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
    );
  }

  Widget _previousButton() {
    return IconButton(
      tooltip: 'Previous',
      onPressed: widget.controller.canGoPrevious
          ? () {
              _run(widget.controller.previous());
            }
          : null,
      icon: const Icon(Icons.skip_previous),
    );
  }

  Widget _rewindButton() {
    final seconds = widget.controller.tuningSettings.seekSeconds;
    return IconButton(
      tooltip: 'Back $seconds seconds',
      onPressed: () {
        _run(widget.controller.rewindInterval());
      },
      icon: const Icon(Icons.replay),
    );
  }

  Widget _playPauseButton(bool isPlaying) {
    return IconButton(
      tooltip: isPlaying ? 'Pause' : 'Play',
      iconSize: 54,
      onPressed: () {
        _run(isPlaying ? widget.controller.pause() : widget.controller.play());
      },
      icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
    );
  }

  Widget _forwardButton() {
    final seconds = widget.controller.tuningSettings.seekSeconds;
    return IconButton(
      tooltip: 'Forward $seconds seconds',
      onPressed: () {
        _run(widget.controller.forwardInterval());
      },
      icon: const Icon(Icons.forward),
    );
  }

  Widget _nextButton() {
    final canGoNext = widget.controller.canGoNext;
    return Tooltip(
      message: widget.controller.shuffleEnabled
          ? 'Next (hold to set length limit)'
          : 'Next',
      triggerMode: TooltipTriggerMode.tap,
      child: GestureDetector(
        onLongPress: widget.controller.shuffleEnabled
            ? _showShuffleThresholdDialog
            : null,
        child: IconButton(
          onPressed: canGoNext
              ? () {
                  _run(widget.controller.next());
                }
              : null,
          icon: const Icon(Icons.skip_next),
        ),
      ),
    );
  }

  Future<void> _showShuffleThresholdDialog() async {
    final current = widget.controller.tuningSettings;
    final controller = TextEditingController(
      text: current.shuffleSkipThreshold?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var unit = current.shuffleSkipThresholdUnit;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Shuffle track limit'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Longer than',
                          hintText: 'No limit',
                          border: OutlineInputBorder(),
                        ),
                        validator: (text) {
                          final trimmed = text?.trim() ?? '';
                          if (trimmed.isEmpty) return null;
                          final value = int.tryParse(trimmed);
                          return value == null || value <= 0
                              ? 'Use a positive integer.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SegmentedButton<ShuffleSkipThresholdUnit>(
                          segments: const [
                            ButtonSegment(
                              value: ShuffleSkipThresholdUnit.seconds,
                              label: Text('Seconds'),
                            ),
                            ButtonSegment(
                              value: ShuffleSkipThresholdUnit.minutes,
                              label: Text('Minutes'),
                            ),
                          ],
                          selected: {unit},
                          onSelectionChanged: (selection) {
                            setDialogState(() => unit = selection.single);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save and close'),
                ),
              ],
            );
          },
        );
      },
    );
    final text = controller.text.trim();
    final threshold = int.tryParse(text);
    controller.dispose();

    // Leaving by the button, Back, or tapping outside all saves valid input.
    // Invalid input cannot replace the last persisted value.
    if (text.isNotEmpty && (threshold == null || threshold <= 0)) return;
    // The dialog route and its inherited-widget dependents need to finish
    // detaching before applying a limit that may immediately skip this song.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final latest = widget.controller.tuningSettings;
    await widget.controller.updateTuningSettings(
      TuningSettings(
        nightMode: latest.nightMode,
        shuffleSkipThreshold: threshold,
        shuffleSkipThresholdUnit: unit,
        loadTimeoutSeconds: latest.loadTimeoutSeconds,
        seekSeconds: latest.seekSeconds,
        defaultPlaybackSpeed: latest.defaultPlaybackSpeed,
        playbackSpeeds: latest.playbackSpeeds,
        carouselMinFlingDistance: latest.carouselMinFlingDistance,
        carouselMinFlingVelocity: latest.carouselMinFlingVelocity,
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _speedButton(double currentSpeed) {
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      initialValue: currentSpeed,
      onSelected: (speed) {
        _run(widget.controller.setSpeed(speed));
      },
      itemBuilder: (context) {
        return widget.controller.tuningSettings.playbackSpeeds.map((speed) {
          final selected = speed == currentSpeed;

          return PopupMenuItem<double>(
            value: speed,
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 12),
                Text('${_formatSpeed(speed)}×'),
              ],
            ),
          );
        }).toList();
      },
      child: SizedBox(
        width: 54,
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.speed),
            Text(
              '${_formatSpeed(currentSpeed)}×',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _queueButton() {
    return Visibility(
      visible: !widget.controller.shuffleEnabled,
      maintainAnimation: true,
      maintainSize: true,
      maintainState: true,
      child: IconButton(
        tooltip: 'Current playlist',
        onPressed: _openQueue,
        icon: const Icon(Icons.queue_music),
      ),
    );
  }

  String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) {
      return speed.toStringAsFixed(1);
    }

    return speed.toString();
  }
}
