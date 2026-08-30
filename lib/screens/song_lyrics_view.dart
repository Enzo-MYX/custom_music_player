import 'package:flutter/material.dart';

import '../models/song_lyrics.dart';
import '../models/song_metadata.dart';

class SongLyricsView extends StatelessWidget {
  const SongLyricsView({
    super.key,
    required this.metadataStream,
    required this.positionStream,
    this.initialMetadata,
    this.height,
  });

  final Stream<SongMetadata?> metadataStream;
  final Stream<Duration> positionStream;
  final SongMetadata? initialMetadata;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: StreamBuilder<SongMetadata?>(
        stream: metadataStream,
        initialData: initialMetadata,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: Text('Loading lyrics…'));
          }

          final lyrics = snapshot.data?.lyrics;
          if (lyrics == null) {
            return const Center(child: Text('No lyrics found'));
          }

          if (!lyrics.isSynchronized) {
            return SingleChildScrollView(
              child: SelectableText(
                lyrics.text,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          return _SynchronizedLyrics(
            key: ValueKey(lyrics),
            lyrics: lyrics,
            positionStream: positionStream,
          );
        },
      ),
    );
  }
}

class _SynchronizedLyrics extends StatefulWidget {
  const _SynchronizedLyrics({
    super.key,
    required this.lyrics,
    required this.positionStream,
  });

  final SongLyrics lyrics;
  final Stream<Duration> positionStream;

  @override
  State<_SynchronizedLyrics> createState() => _SynchronizedLyricsState();
}

class _SynchronizedLyricsState extends State<_SynchronizedLyrics> {
  static const _lineHeight = 56.0;

  final ScrollController _scrollController = ScrollController();
  int _activeIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _indexAt(Duration position) {
    var low = 0;
    var high = widget.lyrics.lines.length - 1;
    var result = -1;

    while (low <= high) {
      final middle = (low + high) >> 1;
      if (widget.lyrics.lines[middle].time <= position) {
        result = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    return result;
  }

  void _follow(int index) {
    if (index < 0 || !_scrollController.hasClients) {
      return;
    }

    final viewport = _scrollController.position.viewportDimension;
    final target = (index * _lineHeight - viewport / 2 + _lineHeight / 2).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.positionStream,
      initialData: Duration.zero,
      builder: (context, snapshot) {
        final activeIndex = _indexAt(snapshot.data ?? Duration.zero);
        if (activeIndex != _activeIndex) {
          _activeIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _follow(activeIndex);
            }
          });
        }

        return ListView.builder(
          controller: _scrollController,
          itemExtent: _lineHeight,
          itemCount: widget.lyrics.lines.length,
          itemBuilder: (context, index) {
            final active = index == activeIndex;
            return Center(
              child: Text(
                widget.lyrics.lines[index].text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
