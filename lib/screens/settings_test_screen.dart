import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/build_mode.dart';
import '../models/library_command.dart';
import '../models/music_library.dart';
import '../services/settings_storage.dart';

class SettingsTestScreen extends StatefulWidget {
  const SettingsTestScreen({super.key});

  @override
  State<SettingsTestScreen> createState() =>
      _SettingsTestScreenState();
}

class _SettingsTestScreenState
    extends State<SettingsTestScreen> {
  final SettingsStorage _storage = SettingsStorage();

  AppSettings _settings = const AppSettings.empty();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _storage.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _createTestLibrary() async {
    final library = MusicLibrary(
      name: 'Test Library',
      buildMode: LibraryBuildMode.includeAll,
      commands: const [
        LibraryCommand(
          include: false,
          path: 'Live',
        ),
        LibraryCommand(
          include: true,
          path: 'Live/Favourites',
        ),
      ],
    );

    final libraries = [
      ..._settings.libraries,
      library,
    ];

    final newSettings = AppSettings(
      rootUri: _settings.rootUri,
      libraries: libraries,
    );

    await _storage.save(newSettings);

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = newSettings;
    });
  }

  Future<void> _clearSettings() async {
    const emptySettings = AppSettings.empty();

    await _storage.save(emptySettings);

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = emptySettings;
    });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Root URI:',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            Text(
              _settings.rootUri ?? 'None',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 24),

            Text(
              'Libraries: ${_settings.libraries.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: _settings.libraries.length,
                itemBuilder: (context, index) {
                  final library = _settings.libraries[index];

                  return ListTile(
                    title: Text(library.name),
                    subtitle: Text(
                      '${library.buildMode.name} • '
                          '${library.commands.length} commands',
                    ),
                  );
                },
              ),
            ),

            ElevatedButton(
              onPressed: _createTestLibrary,
              child: const Text('Add Test Library'),
            ),

            const SizedBox(height: 8),

            OutlinedButton(
              onPressed: _clearSettings,
              child: const Text('Clear Settings'),
            ),
          ],
        ),
      ),
    );
  }
}