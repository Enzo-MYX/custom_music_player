import 'package:flutter/material.dart';
import 'package:saf/saf.dart';

import '../models/build_mode.dart';
import '../models/library_command.dart';
import '../models/music_library.dart';
import '../models/song.dart';
import '../services/library_scanner.dart';

class TestScannerScreen extends StatefulWidget {
  const TestScannerScreen({super.key});

  @override
  State<TestScannerScreen> createState() => _TestScannerScreenState();
}

class _TestScannerScreenState extends State<TestScannerScreen> {
  final Saf _saf = Saf();
  final LibraryScanner _scanner = LibraryScanner();

  SafDocumentFile? _root;
  List<Song> _songs = [];

  bool _scanning = false;
  String? _errorMessage;

  Future<void> _chooseRoot() async {
    try {
      final selectedRoot = await _saf.pickDirectory();
      if (selectedRoot == null) {
        // The user cancelled the picker.
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _root = selectedRoot;
        _songs = [];
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Failed to choose root directory:\n$e';
      });
    }
  }

  Future<void> _scan() async {
    final root = _root;
    if (root == null || _scanning) {
      return;
    }
    setState(() {
      _scanning = true;
      _songs = [];
      _errorMessage = null;
    });

    try {
      // Temporary test library:
      // Include everything under the selected root.
      final testLibrary = MusicLibrary(
        name: 'Test',
        buildMode: LibraryBuildMode.includeAll,
        commands: const [
          LibraryCommand(include: false, path: 'Alexander Hamilton'),
          LibraryCommand(include: true, path: 'Alexander Hamilton/Additions')
        ],
      );
      final songs = await _scanner.rebuild(
        root,
        testLibrary,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _songs = songs;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Failed to scan library:\n$e';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rootName = _root?.name ?? 'No root directory selected';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Root directory',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              rootName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _scanning ? null : _chooseRoot,
              child: const Text('Choose Root Directory'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _root == null || _scanning ? null : _scan,
              child: Text(
                _scanning ? 'Scanning...' : 'Test Scan',
              ),
            ),
            const SizedBox(height: 24),
            if (_scanning)
              const LinearProgressIndicator(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Songs found: ${_songs.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildSongList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongList() {
    if (_songs.isEmpty) {
      return const Center(
        child: Text('No songs scanned yet.'),
      );
    }
    final songsToDisplay = _songs.take(100).toList();
    return ListView.builder(
      itemCount: songsToDisplay.length,
      itemBuilder: (context, index) {
        final song = songsToDisplay[index];
        return ListTile(
          dense: true,
          leading: Text('${index + 1}'),
          title: Text(
            song.relativePath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}