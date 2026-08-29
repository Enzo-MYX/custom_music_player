import 'package:saf/saf.dart';

import '../models/app_settings.dart';
import '../models/library_state.dart';
import '../models/music_library.dart';
import '../models/song.dart';
import 'library_scanner.dart';
import 'settings_storage.dart';

class LibraryManager {
  final SettingsStorage _storage;
  final LibraryScanner _scanner;
  final Saf _saf;

  LibraryState _state = const LibraryState.initial();

  LibraryManager({SettingsStorage? storage, LibraryScanner? scanner, Saf? saf})
    : _storage = storage ?? SettingsStorage(),
      _scanner = scanner ?? LibraryScanner(),
      _saf = saf ?? Saf();

  LibraryState get state => _state;

  Future<void> load() async {
    final settings = await _storage.load();
    String? selectedLibraryName;
    if (settings.libraries.isNotEmpty) {
      selectedLibraryName = settings.libraries.first.name;
    }
    _state = LibraryState(
      settings: settings,
      selectedLibraryName: selectedLibraryName,
      builtLibraryName: null,
      songs: const [],
      scanning: false,
    );
  }

  Future<void> setRoot(SafDocumentFile root) async {
    final rootUri = root.uri;
    final treeUri = rootUri.contains('/document/')
        ? rootUri.substring(0, rootUri.indexOf('/document/'))
        : rootUri;
    final newSettings = AppSettings(
      rootUri: treeUri,
      libraries: _state.settings.libraries,
    );

    await _storage.save(newSettings);

    _state = LibraryState(
      settings: newSettings,
      selectedLibraryName: _state.selectedLibraryName,
      builtLibraryName: null,
      songs: const [],
      scanning: false,
    );
  }

  Future<SafDocumentFile?> getRoot() async {
    final rootUri = _state.settings.rootUri;
    if (rootUri == null) {
      return null;
    }
    final grants = await _saf.persistedPermissions();
    for (final grant in grants) {
      if (grant.uri == rootUri) {
        return await _saf.stat(rootUri);
      }
    }
    return null;
  }

  Future<void> selectLibrary(String name) async {
    final exists = _state.settings.libraries.any(
      (library) => library.name == name,
    );
    if (!exists) {
      throw ArgumentError('Library "$name" does not exist.');
    }
    if (_state.selectedLibraryName == name) {
      return;
    }
    _state = LibraryState(
      settings: _state.settings,
      selectedLibraryName: name,
      builtLibraryName: null,
      songs: const [],
      scanning: false,
    );
  }

  Future<void> addLibrary(MusicLibrary library) async {
    if (_state.settings.libraries.any(
      (existing) => existing.name == library.name,
    )) {
      throw ArgumentError('A library named "${library.name}" already exists.');
    }
    final newLibraries = [..._state.settings.libraries, library];
    final newSettings = AppSettings(
      rootUri: _state.settings.rootUri,
      libraries: newLibraries,
    );
    await _storage.save(newSettings);

    final wasUnselected = _state.selectedLibraryName == null;
    _state = LibraryState(
      settings: newSettings,
      selectedLibraryName: _state.selectedLibraryName ?? library.name,
      builtLibraryName: wasUnselected ? null : _state.builtLibraryName,
      songs: wasUnselected ? const [] : _state.songs,
      scanning: false,
    );
  }

  Future<void> updateLibrary(MusicLibrary library) async {
    final exists = _state.settings.libraries.any(
      (existing) => existing.name == library.name,
    );
    if (!exists) {
      throw ArgumentError('A library named "${library.name}" does not exist.');
    }
    final newLibraries = _state.settings.libraries.map((existing) {
      if (existing.name != library.name) {
        return existing;
      }
      return library;
    }).toList();
    final newSettings = AppSettings(
      rootUri: _state.settings.rootUri,
      libraries: newLibraries,
    );
    await _storage.save(newSettings);
    final updatesSelected = library.name == _state.selectedLibraryName;
    _state = LibraryState(
      settings: newSettings,
      selectedLibraryName: _state.selectedLibraryName,
      builtLibraryName: updatesSelected ? null : _state.builtLibraryName,
      songs: updatesSelected ? const [] : _state.songs,
      scanning: false,
    );
  }

  Future<void> renameLibrary(String oldName, String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Library name cannot be empty.');
    }
    if (oldName != trimmedName &&
        _state.settings.libraries.any(
          (library) => library.name == trimmedName,
        )) {
      throw ArgumentError('A library named "$trimmedName" already exists.');
    }
    final newLibraries = _state.settings.libraries.map((library) {
      if (library.name != oldName) {
        return library;
      }

      return MusicLibrary(
        name: trimmedName,
        buildMode: library.buildMode,
        commands: library.commands,
      );
    }).toList();

    final newSettings = AppSettings(
      rootUri: _state.settings.rootUri,
      libraries: newLibraries,
    );

    await _storage.save(newSettings);

    final newSelectedName = _state.selectedLibraryName == oldName
        ? trimmedName
        : _state.selectedLibraryName;
    final newBuiltName = _state.builtLibraryName == oldName
        ? trimmedName
        : _state.builtLibraryName;

    _state = LibraryState(
      settings: newSettings,
      selectedLibraryName: newSelectedName,
      builtLibraryName: newBuiltName,
      songs: _state.songs,
      scanning: false,
    );
  }

  Future<void> deleteLibrary(String name) async {
    final newLibraries = _state.settings.libraries
        .where((library) => library.name != name)
        .toList();
    final newSettings = AppSettings(
      rootUri: _state.settings.rootUri,
      libraries: newLibraries,
    );
    await _storage.save(newSettings);

    String? newSelectedName;
    if (newLibraries.isNotEmpty) {
      if (_state.selectedLibraryName != name) {
        newSelectedName = _state.selectedLibraryName;
      } else {
        newSelectedName = newLibraries.first.name;
      }
    }

    final deletedSelected = _state.selectedLibraryName == name;
    _state = LibraryState(
      settings: newSettings,
      selectedLibraryName: newSelectedName,
      builtLibraryName: deletedSelected ? null : _state.builtLibraryName,
      songs: deletedSelected ? const [] : _state.songs,
      scanning: false,
    );
  }

  Future<List<Song>> rebuildSelectedLibrary() async {
    final library = _state.selectedLibrary;
    if (library == null) {
      throw StateError('No library is selected.');
    }
    final root = await getRoot();
    if (root == null) {
      throw StateError('No valid root directory is selected.');
    }

    _state = LibraryState(
      settings: _state.settings,
      selectedLibraryName: _state.selectedLibraryName,
      builtLibraryName: null,
      songs: const [],
      scanning: true,
    );
    try {
      final songs = await _scanner.rebuild(root, library);
      _state = LibraryState(
        settings: _state.settings,
        selectedLibraryName: _state.selectedLibraryName,
        builtLibraryName: _state.selectedLibraryName,
        songs: songs,
        scanning: false,
      );
      return songs;
    } catch (_) {
      _state = LibraryState(
        settings: _state.settings,
        selectedLibraryName: _state.selectedLibraryName,
        builtLibraryName: null,
        songs: const [],
        scanning: false,
      );
      rethrow;
    }
  }
}
