import 'package:flutter/material.dart';
import 'package:saf/saf.dart';

import '../models/build_mode.dart';
import '../models/library_command.dart';
import '../models/music_library.dart';
import '../services/library_manager.dart';
import 'path_selector_screen.dart';

class LibraryEditorScreen extends StatefulWidget {
  final LibraryManager manager;
  final MusicLibrary library;
  final SafDocumentFile root;

  const LibraryEditorScreen({
    super.key,
    required this.manager,
    required this.library,
    required this.root,
  });

  @override
  State<LibraryEditorScreen> createState() =>
      _LibraryEditorScreenState();
}

class _LibraryEditorScreenState extends State<LibraryEditorScreen> {
  late LibraryBuildMode _buildMode;
  late List<LibraryCommand> _commands;

  @override
  void initState() {
    super.initState();

    _buildMode = widget.library.buildMode;
    _commands = List<LibraryCommand>.from(
      widget.library.commands,
    );
  }

  void _toggleBuildMode(bool includeAll) {
    setState(() {
      _buildMode = includeAll
          ? LibraryBuildMode.includeAll
          : LibraryBuildMode.includeNone;
    });
  }

  bool get _hasChanges {
    if (_buildMode != widget.library.buildMode) {
      return true;
    }
    if (_commands.length != widget.library.commands.length) {
      return true;
    }
    for (var i = 0; i < _commands.length; i++) {
      final current = _commands[i];
      final original = widget.library.commands[i];
      if (current.include != original.include ||
          current.path != original.path) {
        return true;
      }
    }
    return false;
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
            'You have unsaved changes. What would you like to do?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addCommand() async {
    final include = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Command'),
          content: const Text(
            'Choose what should happen to the selected folder.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Exclude'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Include'),
            ),
          ],
        );
      },
    );

    if (include == null || !mounted) {
      return;
    }

    final selection = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => PathSelectorScreen(
          root: widget.root,
        ),
      ),
    );

    if (selection == null || !mounted) {
      return;
    }

    if (selection is List<String>) {
      _addMultipleCommands(include, selection);
      return;
    }

    if (selection is String) {
      final command = LibraryCommand.create(
        include: include,
        path: selection,
      );

      setState(() {
        _commands.add(command);
      });
    }
  }

  void _addMultipleCommands(bool include, List<String> selectedPaths) {
    final existingPaths = _commands.map((command) => command.path).toSet();
    final commandsToAdd = <LibraryCommand>[];

    for (final path in selectedPaths) {
      final command = LibraryCommand.create(
        include: include,
        path: path,
      );
      if (existingPaths.add(command.path)) {
        commandsToAdd.add(command);
      }
    }

    setState(() {
      _commands.addAll(commandsToAdd);
    });

    final skippedCount = selectedPaths.length - commandsToAdd.length;
    if (skippedCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$skippedCount existing item${skippedCount == 1 ? '' : 's'} skipped.',
          ),
        ),
      );
    }
  }

  void _deleteCommand(int index) {
    setState(() {
      _commands.removeAt(index);
    });
  }

  Future<void> _save() async {
    final updatedLibrary = MusicLibrary(
      name: widget.library.name,
      buildMode: _buildMode,
      commands: List<LibraryCommand>.unmodifiable(
        _commands,
      ),
    );

    await widget.manager.updateLibrary(
      updatedLibrary,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _handleBack() async {
    if (!_hasChanges) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    final choice = await _showUnsavedChangesDialog();
    if (!mounted) {
      return;
    }
    if (choice == true) {
      await _save();
    } else if (choice == false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _handleBack();
      }, child: Scaffold(
        appBar: AppBar(
          title: Text(widget.library.name),
          actions: [
            IconButton(
              onPressed: _save,
              tooltip: 'Save',
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildBuildModeSection(),
            const Divider(height: 1),
            Expanded(
              child: _buildCommandList(),
            ),
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildModeSection() {
    final includeAll =
        _buildMode == LibraryBuildMode.includeAll;

    return SwitchListTile(
      title: const Text(
        'Include everything by default',
      ),
      subtitle: Text(
        includeAll
            ? 'Files are included unless excluded by a command.'
            : 'Files are excluded unless included by a command.',
      ),
      value: includeAll,
      onChanged: _toggleBuildMode,
    );
  }

  Widget _buildCommandList() {
    if (_commands.isEmpty) {
      return const Center(
        child: Text(
          'No commands yet.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      itemCount: _commands.length,
      itemBuilder: (context, index) {
        final command = _commands[index];

        return ListTile(
          leading: Text(
            command.include ? '+' : '-',
            style: Theme.of(context)
                .textTheme
                .titleLarge,
          ),
          title: Text(
            command.path,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: 'Delete command',
            onPressed: () {
              _deleteCommand(index);
            },
            icon: const Icon(
              Icons.delete_outline,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _addCommand,
            icon: const Icon(
              Icons.add,
            ),
            label: const Text(
              'Add Command',
            ),
          ),
        ),
      ),
    );
  }
}
