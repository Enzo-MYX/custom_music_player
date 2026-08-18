import 'package:flutter/material.dart';
import 'package:saf/saf.dart';

import '../models/build_mode.dart';
import '../models/library_command.dart';
import '../models/library_state.dart';
import '../models/music_library.dart';
import '../services/library_manager.dart';

class LibraryManagerScreen extends StatefulWidget {
  const LibraryManagerScreen({
    super.key,
    required this.manager,
  });

  final LibraryManager manager;

  @override
  State<LibraryManagerScreen> createState() =>
      _LibraryManagerScreenState();
}

class _LibraryManagerScreenState
    extends State<LibraryManagerScreen> {
  LibraryManager get _manager => widget.manager;

  bool _loading = true;
  String? _error;

  LibraryState get _state => _manager.state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _manager.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = null;
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

  Future<void> _chooseRoot() async {
    try {
      final saf = Saf();

      final root = await saf.pickDirectory();

      if (root == null) {
        return;
      }

      await _manager.setRoot(root);

      if (!mounted) {
        return;
      }

      setState(() {});
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _createLibrary() async {
    final result = await _showLibraryNameDialog(
      title: 'New Library',
    );

    if (result == null) {
      return;
    }

    try {
      await _manager.addLibrary(
        MusicLibrary(
          name: result,
          buildMode: LibraryBuildMode.includeAll,
          commands: const [],
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {});
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _renameLibrary(
      MusicLibrary library,
      ) async {
    final result = await _showLibraryNameDialog(
      title: 'Rename Library',
      initialName: library.name,
    );

    if (result == null) {
      return;
    }

    try {
      await _manager.renameLibrary(
        library.name,
        result,
      );

      if (!mounted) {
        return;
      }

      setState(() {});
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _deleteLibrary(
      MusicLibrary library,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Library?'),
          content: Text(
            'Delete "${library.name}"?\n\n'
                'This only deletes the library recipe. '
                'Your music files will not be touched.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _manager.deleteLibrary(
        library.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {});
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _selectLibrary(
      MusicLibrary library,
      ) async {
    try {
      await _manager.selectLibrary(
        library.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {});
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _rebuild() async {
    if (_state.selectedLibrary == null) {
      _showError('Select a library first.');
      return;
    }

    try {
      setState(() {});

      await _manager.rebuildSelectedLibrary();

      if (!mounted) {
        return;
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Library rebuilt: '
                '${_manager.state.songs.length} songs',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {});

      _showError(e.toString());
    }
  }

  Future<String?> _showLibraryNameDialog({
    required String title,
    String initialName = '',
  }) async {
    final controller = TextEditingController(
      text: initialName,
    );

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Library name',
            ),
            onSubmitted: (value) {
              final name = value.trim();

              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isNotEmpty) {
                  Navigator.pop(context, name);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text(_error!),
        ),
      );
    }

    final rootUri = _state.settings.rootUri;
    final selected = _state.selectedLibrary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Library'),
      ),
      body: Column(
        children: [
          if (_state.scanning)
            const LinearProgressIndicator(),

          _buildRootSection(rootUri),

          const Divider(height: 1),

          _buildLibraryHeader(),

          Expanded(
            child: _buildLibraryList(),
          ),

          _buildBottomSection(selected),
        ],
      ),
    );
  }

  Widget _buildRootSection(String? rootUri) {
    return ListTile(
      leading: const Icon(Icons.folder),
      title: const Text('Root Directory'),
      subtitle: Text(
        rootUri ?? 'No root directory selected',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: FilledButton.tonal(
        onPressed: _state.scanning
            ? null
            : _chooseRoot,
        child: Text(
          rootUri == null ? 'Choose' : 'Change',
        ),
      ),
    );
  }

  Widget _buildLibraryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        8,
      ),
      child: Row(
        children: [
          Text(
            'Libraries',
            style: Theme.of(context)
                .textTheme
                .titleLarge,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'New Library',
            onPressed:
            _state.scanning ? null : _createLibrary,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryList() {
    final libraries = _state.settings.libraries;

    if (libraries.isEmpty) {
      return const Center(
        child: Text(
          'No libraries yet.\n'
              'Press + to create one.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: libraries.length,
      itemBuilder: (context, index) {
        final library = libraries[index];

        final selected =
            library.name == _state.selectedLibraryName;

        return ListTile(
          selected: selected,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          title: Text(library.name),
          subtitle: Text(
            '${library.buildMode.name} • '
                '${library.commands.length} commands',
          ),
          onTap: () => _selectLibrary(library),
          trailing: PopupMenuButton<String>(
            enabled: !_state.scanning,
            onSelected: (action) {
              if (action == 'rename') {
                _renameLibrary(library);
              } else if (action == 'delete') {
                _deleteLibrary(library);
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ];
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomSection(
      MusicLibrary? selected,
      ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            Text(
              selected == null
                  ? 'No library selected'
                  : 'Selected: ${selected.name}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 8),

            Text(
              _state.songs.isEmpty
                  ? 'No library currently loaded'
                  : '${_state.songs.length} songs loaded',
            ),

            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed:
              _state.scanning ||
                  selected == null ||
                  _state.settings.rootUri == null
                  ? null
                  : _rebuild,
              icon: const Icon(Icons.refresh),
              label: Text(
                _state.scanning
                    ? 'Rebuilding...'
                    : 'Rebuild Library',
              ),
            ),
          ],
        ),
      ),
    );
  }
}