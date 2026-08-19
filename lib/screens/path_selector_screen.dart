import 'package:flutter/material.dart';
import 'package:saf/saf.dart';

import '../services/path_utils.dart';

class PathSelectorScreen extends StatefulWidget {
  final SafDocumentFile root;

  /// Relative path within [root] where browsing should initially begin.
  ///
  /// Empty string means the root itself.
  final String initialPath;

  const PathSelectorScreen({
    super.key,
    required this.root,
    this.initialPath = '',
  });

  @override
  State<PathSelectorScreen> createState() => _PathSelectorScreenState();
}

class _PathSelectorScreenState extends State<PathSelectorScreen> {
  final Saf _saf = Saf();

  late String _currentPath;

  List<SafDocumentFile> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _currentPath = PathUtils.normalize(widget.initialPath,);

    _loadCurrentDirectory();
  }

  Future<void> _loadCurrentDirectory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final directory = await _getCurrentDirectory();

      if (directory == null) {
        throw Exception(
          'Unable to access the selected directory.',
        );
      }

      final children = await _saf.list(directory.uri);

      children.sort((a, b) {
        final aDirectory = a.isDir;
        final bDirectory = b.isDir;

        // Directories first.
        if (aDirectory != bDirectory) {
          return aDirectory ? -1 : 1;
        }

        return a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        );
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _entries = children;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<SafDocumentFile?> _getCurrentDirectory() async {
    if (_currentPath.isEmpty) {
      return widget.root;
    }

    SafDocumentFile current = widget.root;

    final components = PathUtils.components(
      _currentPath,
    );

    for (final component in components) {
      final children = await _saf.list(current.uri);

      SafDocumentFile? next;

      for (final child in children) {
        if (child.isDir && child.name == component) {
          next = child;
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

  Future<void> _openDirectory(
      SafDocumentFile directory,
      ) async {
    final name = directory.name;

    final nextPath = _currentPath.isEmpty
        ? name
        : '$_currentPath/$name';

    setState(() {
      _currentPath = PathUtils.normalize(
        nextPath,
      );
    });

    await _loadCurrentDirectory();
  }

  void _goToParent() {
    if (_currentPath.isEmpty) {
      // Root cannot go any higher.
      return;
    }

    setState(() {
      _currentPath = PathUtils.parent(
        _currentPath,
      );
    });

    _loadCurrentDirectory();
  }

  void _selectCurrentFolder() {
    // Root selection is deliberately invalid.
    if (_currentPath.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _currentPath,
    );
  }

  String get _displayPath {
    if (_currentPath.isEmpty) {
      return '/';
    }

    return '/$_currentPath';
  }

  @override
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPath.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _goToParent();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Folder'),
        ),
        body: Column(
          children: [
            _buildPathBar(),
            const Divider(height: 1),
            Expanded(
              child: _buildContent(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPathBar() {
    return Material(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Go to parent',
              onPressed: _currentPath.isEmpty
                  ? null
                  : _goToParent,
              icon: const Icon(
                Icons.arrow_back,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _displayPath,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadCurrentDirectory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Text('This folder is empty.'),
      );
    }

    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];

        return ListTile(
          leading: Icon(
            entry.isDir
                ? Icons.folder
                : Icons.music_note,
          ),
          title: Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: entry.isDir
              ? const Icon(
            Icons.chevron_right,
          )
              : null,
          onTap: entry.isDir
              ? () => _openDirectory(entry)
              : null,
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _currentPath.isEmpty
                ? null
                : _selectCurrentFolder,
            icon: const Icon(
              Icons.check,
            ),
            label: const Text(
              'Select This Folder',
            ),
          ),
        ),
      ),
    );
  }
}