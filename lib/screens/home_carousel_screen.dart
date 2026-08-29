import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../services/library_manager.dart';
import '../services/playback_controller.dart';
import 'library_manager_screen.dart';
import 'playback_screen.dart';
import 'shuffle_screen.dart';

class SensitivePageScrollPhysics extends PageScrollPhysics {
  const SensitivePageScrollPhysics({
    super.parent,
  });

  @override
  SensitivePageScrollPhysics applyTo(
      ScrollPhysics? ancestor,
      ) {
    return SensitivePageScrollPhysics(
      parent: buildParent(ancestor),
    );
  }

  @override
  double get minFlingDistance => 4;

  @override
  double get minFlingVelocity => 50;

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.35,
    stiffness: 300,
    damping: 30,
  );
}

class HomeCarouselScreen extends StatefulWidget {
  const HomeCarouselScreen({
    super.key,
    required this.manager,
    required this.playbackController,
  });

  final LibraryManager manager;
  final PlaybackController playbackController;

  @override
  State<HomeCarouselScreen> createState() => _HomeCarouselScreenState();
}

class _HomeCarouselScreenState extends State<HomeCarouselScreen> {
  static const int _pageCount = 3;
  static const int _initialPage = 3001;

  late final PageController _pageController;

  int _physicalPage = _initialPage;
  int _logicalPage = 1;

  bool _loading = true;
  String? _error;
  bool _miniPlayerCollapsed = false;
  Offset? _collapsedMiniPlayerPosition;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: _initialPage);

    _load();
  }

  Future<void> _load() async {
    try {
      await widget.manager.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  int _logicalIndex(int physicalIndex) {
    return physicalIndex % _pageCount;
  }

  void _handlePageChanged(int page) {
    setState(() {
      _physicalPage = page;
      _logicalPage = _logicalIndex(page);
    });
  }

  Future<void> _showLibraryManager() async {
    await _pageController.animateToPage(
      _physicalPage - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openPlaybackScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaybackScreen(
          controller: widget.playbackController,
        ),
      ),
    );
  }

  Widget _buildPage(int physicalIndex) {
    return switch (_logicalIndex(physicalIndex)) {
      0 => LibraryManagerScreen(
        key: ValueKey('library-$physicalIndex'),
        manager: widget.manager,
        playbackController: widget.playbackController,
        loadOnOpen: false,
      ),
      1 => ShuffleScreen(
        key: ValueKey('shuffle-$physicalIndex'),
        manager: widget.manager,
        playbackController: widget.playbackController,
        loadOnOpen: false,
        onOpenLibraryManager: _showLibraryManager,
      ),
      _ => const Scaffold(),
    };
  }

  Widget _buildCubePage(int physicalIndex) {
    return AnimatedBuilder(
      animation: _pageController,
      child: _buildPage(physicalIndex),
      builder: (context, child) {
        final currentPage = _pageController.hasClients
            ? _pageController.page ?? _physicalPage.toDouble()
            : _physicalPage.toDouble();

        final pageOffset = (currentPage - physicalIndex)
            .clamp(-1.0, 1.0);

        final rotation = pageOffset * math.pi / 2;

        return Transform(
          alignment: pageOffset > 0
              ? Alignment.centerRight
              : Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(rotation),
          transformHitTests: false,
          child: child,
        );
      },
    );
  }

  Offset _defaultCollapsedPosition(Size availableSize) {
    final mediaPadding = MediaQuery.paddingOf(context);

    return Offset(
      availableSize.width - 72,
      availableSize.height - mediaPadding.bottom - 108,
    );
  }

  Offset _constrainCollapsedPosition(
      Offset position,
      Size availableSize,
      ) {
    final mediaPadding = MediaQuery.paddingOf(context);
    const buttonSize = 48.0;
    const edgePadding = 8.0;

    final minimumX = edgePadding;
    final maximumX =
    math.max(minimumX, availableSize.width - buttonSize - edgePadding);

    final minimumY = mediaPadding.top + edgePadding;
    final maximumY = math.max(
      minimumY,
      availableSize.height -
          mediaPadding.bottom -
          buttonSize -
          edgePadding,
    );

    return Offset(
      position.dx.clamp(minimumX, maximumX).toDouble(),
      position.dy.clamp(minimumY, maximumY).toDouble(),
    );
  }

  void _moveCollapsedMiniPlayer(
      DragUpdateDetails details,
      Size availableSize,
      ) {
    final currentPosition = _collapsedMiniPlayerPosition ??
        _defaultCollapsedPosition(availableSize);

    setState(() {
      _collapsedMiniPlayerPosition = _constrainCollapsedPosition(
        currentPosition + details.delta,
        availableSize,
      );
    });
  }

  Widget _buildMiniPlayer(Size availableSize) {
    return StreamBuilder(
      stream: widget.playbackController.currentSongStream,
      initialData: widget.playbackController.currentSong,
      builder: (context, songSnapshot) {
        final song = songSnapshot.data;

        if (song == null) {
          return const SizedBox.shrink();
        }

        if (_miniPlayerCollapsed) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              _moveCollapsedMiniPlayer(details, availableSize);
            },
            child: FloatingActionButton.small(
              heroTag: 'collapsed-mini-player',
              tooltip: 'Expand mini-player',
              onPressed: () {
                setState(() {
                  _miniPlayerCollapsed = false;
                });
              },
              child: const Icon(Icons.music_note),
            ),
          );
        }

        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openPlaybackScreen,
            child: SizedBox(
              height: 68,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(
                    Icons.music_note,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      song.relativePath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: widget.playbackController.playingStream,
                    initialData: false,
                    builder: (context, playingSnapshot) {
                      final isPlaying = playingSnapshot.data ?? false;

                      return IconButton(
                        tooltip: isPlaying ? 'Pause' : 'Play',
                        onPressed: () {
                          if (isPlaying) {
                            widget.playbackController.pause();
                          } else {
                            widget.playbackController.play();
                          }
                        },
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Collapse player',
                    onPressed: () {
                      setState(() {
                        _miniPlayerCollapsed = true;
                      });
                    },
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPositionIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_pageCount, (index) {
        final selected = index == _logicalPage;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 8 : 6,
          height: selected ? 8 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });

                    _load();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableSize = constraints.biggest;
          final collapsedPosition = _constrainCollapsedPosition(
            _collapsedMiniPlayerPosition ??
                _defaultCollapsedPosition(availableSize),
            availableSize,
          );

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                physics: const SensitivePageScrollPhysics(),
                onPageChanged: _handlePageChanged,
                itemBuilder: (context, index) {
                  return _buildCubePage(index);
                },
              ),

              if (_miniPlayerCollapsed)
                Positioned(
                  left: collapsedPosition.dx,
                  top: collapsedPosition.dy,
                  child: _buildMiniPlayer(availableSize),
                )
              else
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 44,
                  child: SafeArea(
                    top: false,
                    child: _buildMiniPlayer(availableSize),
                  ),
                ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: _buildPositionIndicator(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
