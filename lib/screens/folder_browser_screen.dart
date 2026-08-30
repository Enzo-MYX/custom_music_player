import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saf/saf.dart';

import '../models/song.dart';
import '../services/library_manager.dart';
import '../services/path_utils.dart';
import '../services/playback_controller.dart';

class FolderBrowserScreen extends StatefulWidget {
  const FolderBrowserScreen({
    super.key,
    required this.manager,
    required this.playbackController,
  });

  final LibraryManager manager;
  final PlaybackController playbackController;

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  final Saf _saf = Saf();

  SafDocumentFile? _root;
  SafDocumentFile? _currentDirectory;

  String _currentPath = '';
  List<SafDocumentFile> _entries = const [];

  bool _recursive = true;
  bool _loading = true;
  bool _buildingQueue = false;
  String? _error;

  // Incrementing this invalidates an older recursive scan when the user starts
  // another song or changes the recursion setting.
  int _queueBuildGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final recursive = await widget.manager.loadFolderBrowserRecursive();
      final root = await widget.manager.getRoot();

      if (root == null) {
        throw StateError('No valid root directory is selected.');
      }

      final entries = await _listVisibleEntries(root);

      if (!mounted) {
        return;
      }

      setState(() {
        _root = root;
        _currentDirectory = root;
        _currentPath = '';
        _entries = entries;
        _recursive = recursive;
        _loading = false;
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

  Future<List<SafDocumentFile>> _listVisibleEntries(
      SafDocumentFile directory,
      ) async {
    final entries = await _saf.list(directory.uri);

    final visibleEntries = entries.where((entry) {
      return entry.isDir || !_isLyricsFile(entry.name);
    }).toList();

    visibleEntries.sort(_compareBrowserEntries);
    return visibleEntries;
  }

  int _compareBrowserEntries(
      SafDocumentFile first,
      SafDocumentFile second,
      ) {
    if (first.isDir != second.isDir) {
      return first.isDir ? -1 : 1;
    }

    final insensitiveComparison = first.name
        .toLowerCase()
        .compareTo(second.name.toLowerCase());

    if (insensitiveComparison != 0) {
      return insensitiveComparison;
    }

    return first.name.compareTo(second.name);
  }

  Future<void> _openDirectory(SafDocumentFile directory) async {
    final nextPath = _currentPath.isEmpty
        ? directory.name
        : '$_currentPath/${directory.name}';

    await _loadDirectory(
      directory: directory,
      relativePath: PathUtils.normalize(nextPath),
    );
  }

  Future<void> _loadDirectory({
    required SafDocumentFile directory,
    required String relativePath,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await _listVisibleEntries(directory);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentDirectory = directory;
        _currentPath = relativePath;
        _entries = entries;
        _loading = false;
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

  Future<void> _goToParent() async {
    if (_currentPath.isEmpty) {
      return;
    }

    final root = _root;
    if (root == null) {
      return;
    }

    final parentPath = PathUtils.parent(_currentPath);
    final parent = await _findDirectory(root, parentPath);

    if (parent == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to access the parent directory.';
      });
      return;
    }

    await _loadDirectory(
      directory: parent,
      relativePath: parentPath,
    );
  }

  Future<SafDocumentFile?> _findDirectory(
      SafDocumentFile root,
      String relativePath,
      ) async {
    if (relativePath.isEmpty) {
      return root;
    }

    var current = root;

    for (final component in PathUtils.components(relativePath)) {
      final entries = await _saf.list(current.uri);
      SafDocumentFile? next;

      for (final entry in entries) {
        if (entry.isDir && entry.name == component) {
          next = entry;
          break;
        }
      }

      if (next == null) {
        return null;
      }

      current = next;
    }

    return current;
  }

  Future<void> _setRecursive(bool enabled) async {
    ++_queueBuildGeneration;

    setState(() {
      _recursive = enabled;
      _buildingQueue = false;
    });

    try {
      await widget.manager.saveFolderBrowserRecursive(enabled);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _recursive = !enabled;
        _error = 'Unable to save the recursion setting: $error';
      });
    }
  }

  Future<void> _playFile(SafDocumentFile selectedFile) async {
    final directory = _currentDirectory;

    if (directory == null) {
      return;
    }

    final generation = ++_queueBuildGeneration;

    try {
      // Construct the direct-folder queue from entries already displayed on
      // screen. This avoids waiting for another SAF request before playback.
      final directSongs = _songsFromEntries(
        entries: _entries,
        relativeDirectory: _currentPath,
      );

      final selectedIndex = directSongs.indexWhere(
            (song) => song.uri == selectedFile.uri,
      );

      if (selectedIndex < 0) {
        throw StateError('The selected audio file is no longer available.');
      }

      await widget.playbackController.startNormalQueue(
        directSongs,
        selectedIndex,
      );

      if (!_recursive || !mounted || generation != _queueBuildGeneration) {
        return;
      }

      setState(() {
        _buildingQueue = true;
      });

      // Playback is already running. Complete the recursive queue separately.
      unawaited(
        _completeRecursiveQueue(
          directory: directory,
          relativeDirectory: _currentPath,
          generation: generation,
        ),
      );
    } catch (error) {
      if (!mounted || generation != _queueBuildGeneration) {
        return;
      }

      setState(() {
        _buildingQueue = false;
        _error = 'Unable to play this file: $error';
      });
    }
  }

  Future<void> _completeRecursiveQueue({
    required SafDocumentFile directory,
    required String relativeDirectory,
    required int generation,
  }) async {
    try {
      final songs = <Song>[];

      await _scanDirectory(
        directory: directory,
        relativeDirectory: relativeDirectory,
        songs: songs,
        generation: generation,
      );

      if (!mounted || generation != _queueBuildGeneration) {
        return;
      }

      _sortSongs(songs);

      // This replaces only the in-memory queue and preserves the currently
      // loaded track and its playback position.
      await widget.playbackController.updateNormalQueue(songs);

      if (!mounted || generation != _queueBuildGeneration) {
        return;
      }

      setState(() {
        _buildingQueue = false;
      });
    } catch (error) {
      if (!mounted || generation != _queueBuildGeneration) {
        return;
      }

      setState(() {
        _buildingQueue = false;
        _error = 'Playback started, but the recursive queue failed: $error';
      });
    }
  }

  Future<void> _scanDirectory({
    required SafDocumentFile directory,
    required String relativeDirectory,
    required List<Song> songs,
    required int generation,
  }) async {
    if (generation != _queueBuildGeneration) {
      return;
    }

    final entries = await _saf.list(directory.uri);

    if (generation != _queueBuildGeneration) {
      return;
    }

    songs.addAll(
      _songsFromEntries(
        entries: entries,
        relativeDirectory: relativeDirectory,
      ),
    );

    final directories = entries.where((entry) => entry.isDir).toList()
      ..sort(_compareBrowserEntries);

    for (final childDirectory in directories) {
      if (generation != _queueBuildGeneration) {
        return;
      }

      final childPath = relativeDirectory.isEmpty
          ? childDirectory.name
          : '$relativeDirectory/${childDirectory.name}';

      await _scanDirectory(
        directory: childDirectory,
        relativeDirectory: childPath,
        songs: songs,
        generation: generation,
      );
    }
  }

  List<Song> _songsFromEntries({
    required Iterable<SafDocumentFile> entries,
    required String relativeDirectory,
  }) {
    final sidecarLyricsByBasename = <String, String>{};

    for (final entry in entries) {
      if (!entry.isDir && _isLyricsFile(entry.name)) {
        sidecarLyricsByBasename[_basenameWithoutExtension(entry.name)] =
            entry.uri;
      }
    }

    final songs = <Song>[];

    for (final entry in entries) {
      if (entry.isDir || _isLyricsFile(entry.name)) {
        continue;
      }

      final relativePath = relativeDirectory.isEmpty
          ? entry.name
          : '$relativeDirectory/${entry.name}';

      songs.add(
        Song(
          relativePath: relativePath,
          uri: entry.uri,
          lyricsUri:
          sidecarLyricsByBasename[_basenameWithoutExtension(entry.name)],
        ),
      );
    }

    _sortSongs(songs);
    return songs;
  }

  void _sortSongs(List<Song> songs) {
    songs.sort((first, second) {
      final insensitiveComparison = first.relativePath
          .toLowerCase()
          .compareTo(second.relativePath.toLowerCase());

      if (insensitiveComparison != 0) {
        return insensitiveComparison;
      }

      return first.relativePath.compareTo(second.relativePath);
    });
  }

  bool _isLyricsFile(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0) {
      return false;
    }

    return filename.substring(dot + 1).toLowerCase() == 'lrc';
  }

  String _basenameWithoutExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    final basename = dot < 0 ? filename : filename.substring(0, dot);
    return basename.toLowerCase();
  }

  String get _displayPath {
    return _currentPath.isEmpty ? '/' : '/$_currentPath';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPath.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentPath.isNotEmpty) {
          unawaited(_goToParent());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Folders'),
          actions: [
            IconButton(
              tooltip: 'Refresh root',
              onPressed: _loading ? null : _loadInitialState,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            SwitchListTile(
              title: const Text('Include descendant folders'),
              subtitle: const Text(
                'Add audio files from subfolders to the playback queue',
              ),
              value: _recursive,
              onChanged: _loading ? null : _setRecursive,
            ),
            const Divider(height: 1),
            _buildPathBar(),
            const Divider(height: 1),
            if (_buildingQueue)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildPathBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Go to parent',
            onPressed: _loading || _currentPath.isEmpty ? null : _goToParent,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _displayPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _currentDirectory == null
                    ? _loadInitialState
                    : () {
                  final directory = _currentDirectory!;
                  unawaited(
                    _loadDirectory(
                      directory: directory,
                      relativePath: _currentPath,
                    ),
                  );
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(child: Text('This folder is empty.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 128),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];

        return ListTile(
          leading: Icon(entry.isDir ? Icons.folder : Icons.music_note),
          title: Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: entry.isDir
              ? const Icon(Icons.chevron_right)
              : const Icon(Icons.play_arrow),
          onTap: entry.isDir
              ? () => _openDirectory(entry)
              : () => _playFile(entry),
        );
      },
    );
  }
}