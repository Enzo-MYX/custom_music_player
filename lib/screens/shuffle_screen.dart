import 'dart:async';
import 'package:flutter/material.dart';

import '../services/library_manager.dart';
import '../services/playback_controller.dart';
import 'library_manager_screen.dart';
import 'playback_screen.dart';

class ShuffleScreen extends StatefulWidget {
  const ShuffleScreen({
    super.key,
    required this.manager,
    required this.playbackController,
    this.loadOnOpen = true,
    this.onOpenLibraryManager,
  });

  final LibraryManager manager;
  final PlaybackController playbackController;
  final bool loadOnOpen;
  final Future<void> Function()? onOpenLibraryManager;

  @override
  State<ShuffleScreen> createState() => _ShuffleScreenState();
}

class _ShuffleScreenState extends State<ShuffleScreen> {
  bool _loading = true;
  bool _starting = false;
  bool _selectedThroughDropdown = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    if (widget.loadOnOpen) {
      _load();
    } else {
      _loading = false;
    }
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

  Future<void> _selectLibrary(String name) async {
    await widget.manager.selectLibrary(name);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedThroughDropdown = true;
      _error = null;
    });
  }

  Future<void> _openLibraryManager() async {
    final carouselNavigation = widget.onOpenLibraryManager;

    if (carouselNavigation != null) {
      await carouselNavigation();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedThroughDropdown = false;
      });

      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryManagerScreen(
          manager: widget.manager,
          playbackController: widget.playbackController,
          loadOnOpen: false,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedThroughDropdown = false;
    });
  }

  Future<void> _startShuffle() async {
    if (_starting) {
      return;
    }

    final initialState = widget.manager.state;

    if (initialState.selectedLibrary == null) {
      await _openLibraryManager();
      return;
    }

    if (initialState.needsRebuild && !_selectedThroughDropdown) {
      await _openLibraryManager();
      return;
    }

    try {
      setState(() {
        _starting = true;
        _error = null;
      });

      final songs = widget.manager.state.needsRebuild
          ? await widget.manager.rebuildSelectedLibrary()
          : widget.manager.state.songs;

      if (!mounted) {
        return;
      }

      if (songs.isEmpty) {
        setState(() {
          _starting = false;
          _error = 'The selected library contains no songs.';
        });
        return;
      }

      await widget.playbackController.startShuffle(songs);

      if (!mounted) {
        return;
      }

      unawaited(widget.playbackController.play());

      setState(() {
        _starting = false;
      });

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaybackScreen(controller: widget.playbackController),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _starting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.manager.state;
    final selectedName = state.selectedLibraryName;
    final libraries = state.settings.libraries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shuffle'),
        actions: [
          IconButton(
            tooltip: 'Manage libraries',
            onPressed: _starting ? null : _openLibraryManager,
            icon: const Icon(Icons.library_music),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Align(
                  alignment: const Alignment(0, -0.25),
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: FilledButton(
                      onPressed: _starting ? null : _startShuffle,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      child: _starting
                          ? const SizedBox(
                              width: 42,
                              height: 42,
                              child: CircularProgressIndicator(strokeWidth: 4),
                            )
                          : const Icon(Icons.play_arrow, size: 100),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.55),
                  child: SizedBox(
                    width: 320,
                    child: PopupMenuButton<String>(
                      enabled: libraries.isNotEmpty && !_starting,
                      initialValue: selectedName,
                      position: PopupMenuPosition.under,
                      constraints: const BoxConstraints.tightFor(width: 320),
                      onSelected: _selectLibrary,
                      itemBuilder: (context) {
                        return libraries.map((library) {
                          final selected = library.name == selectedName;

                          return PopupMenuItem<String>(
                            value: library.name,
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    library.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        width: 320,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedName ?? 'No library selected',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Align(
                    alignment: const Alignment(0, 0.9),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
