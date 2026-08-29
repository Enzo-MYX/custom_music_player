import 'package:flutter/material.dart';

import '../services/path_utils.dart';
import '../services/playback_controller.dart';

class PlaybackQueueScreen extends StatefulWidget {
  const PlaybackQueueScreen({
    super.key,
    required this.controller,
  });

  final PlaybackController controller;

  @override
  State<PlaybackQueueScreen> createState() =>
      _PlaybackQueueScreenState();
}

class _PlaybackQueueScreenState
    extends State<PlaybackQueueScreen> {
  static const double _itemHeight = 72;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    final currentIndex = widget.controller.currentIndex ?? 0;

    _scrollController = ScrollController(
      initialScrollOffset: currentIndex * _itemHeight,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final songs = controller.songs;
    final currentIndex = controller.currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Current playlist'),
      ),
      body: songs.isEmpty
          ? const Center(
        child: Text('The current playlist is empty.'),
      )
          : ListView.builder(
        controller: _scrollController,
        itemExtent: _itemHeight,
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final selected = index == currentIndex;

          return ListTile(
            selected: selected,
            onTap: selected
                ? () {
              Navigator.of(context).pop();
            }
                : () async {
              await controller.playAt(index);

              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            leading: selected
                ? const Icon(Icons.graphic_eq)
                : SizedBox(
              width: 32,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
              ),
            ),
            title: Text(
              PathUtils.basename(song.relativePath),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              PathUtils.parent(song.relativePath),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }
}