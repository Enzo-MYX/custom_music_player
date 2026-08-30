import 'dart:convert';

import 'package:saf/saf.dart';

import '../models/app_settings.dart';
import '../models/built_library_cache.dart';
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

  Future<bool> loadFolderBrowserRecursive() {
    return _storage.loadFolderBrowserRecursive();
  }

  Future<void> saveFolderBrowserRecursive(bool enabled) {
    return _storage.saveFolderBrowserRecursive(enabled);
  }

  Future<void> load() async {
    var settings = await _storage.load();
    final cache = await _storage.loadBuiltLibrary();

    final savedSelection = settings.selectedLibraryName;
    final savedSelectionExists = savedSelection != null &&
        settings.libraries.any(
              (library) => library.name == savedSelection,
        );

    final String? selectedLibraryName;

    if (savedSelectionExists) {
      selectedLibraryName = savedSelection;
    } else if (settings.libraries.isNotEmpty) {
      selectedLibraryName = settings.libraries.first.name;
    } else {
      selectedLibraryName = null;
    }

    // Repair a missing or stale saved selection.
    if (selectedLibraryName != savedSelection) {
      settings = AppSettings(
        rootUri: settings.rootUri,
        libraries: settings.libraries,
        selectedLibraryName: selectedLibraryName,
      );

      await _storage.save(settings);
    }

    String? builtLibraryName;
    List<Song> songs = const [];

    if (cache != null && _isCacheValid(cache, settings)) {
      builtLibraryName = cache.libraryName;
      songs = cache.songs;
    } else if (cache != null) {
      await _storage.clearBuiltLibrary();
    }

    _state = LibraryState(
      settings: settings,
      selectedLibraryName: selectedLibraryName,
      builtLibraryName: builtLibraryName,
      songs: songs,
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
      selectedLibraryName: _state.selectedLibraryName,
    );

    await _storage.save(newSettings);
    await _storage.clearBuiltLibrary();

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
      throw ArgumentError(
        'Library "$name" does not exist.',
      );
    }
    if (_state.selectedLibraryName == name) {
      return;
    }

    final newSettings = AppSettings(
      rootUri: _state.settings.rootUri,
      libraries: _state.settings.libraries,
      selectedLibraryName: name,
    );

    await _storage.save(newSettings);

    _state = LibraryState(
      settings: newSettings,
      selectedLibraryName: name,
      builtLibraryName: _state.builtLibraryName,
      songs: _state.songs,
      scanning: false,
    );
  }

  Future<void> addLibrary(MusicLibrary library) async {
    if (_state.settings.libraries.any(
          (existing) => existing.name == library.name,
    )) {
      throw ArgumentError(
        'A library named "${library.name}" already exists.',
      );
    }

    final newLibraries = [
      ..._state.settings.libraries,
      library,
    ];

    final wasUnselected = _state.selectedLibraryName == null;
    final newSelectedName =
        _state.selectedLibraryName ?? library.name;

    final newSettings = AppSettings(
      rootUri: _state.settings.rootUri,
      libraries: newLibraries,
      selectedLibraryName: newSelectedName,
    );
    await _storage.save(newSettings);

    _state = LibraryState(
      settings: newSettings,
      selectedLibraryName: newSelectedName,
      builtLibraryName:
      wasUnselected ? null : _state.builtLibraryName,
      songs: wasUnselected ? const [] : _state.songs,
      scanning: false,
    );
  }

  Future<void> updateLibrary(MusicLibrary library) async {
    final exists = _state.settings.libraries.any(
          (existing) => existing.name == library.name,
    );
    if (!exists) {
      throw ArgumentError(
        'A library named "${library.name}" does not exist.',
      );
    }

    final newLibraries =
    _state.settings.libraries.map((existing) {
      if (existing.name != library.name) {
        return existing;
      }
      return library;
    }).toList();
    final newSettings = AppSettings(
      rootUri: _state.settings.rootUri,
      libraries: newLibraries,
      selectedLibraryName: _state.selectedLibraryName,
    );
    await _storage.save(newSettings);

    final invalidatesBuiltLibrary =
        library.name == _state.builtLibraryName;

    if (invalidatesBuiltLibrary) {
      await _storage.clearBuiltLibrary();
    }

    _state = LibraryState(
      settings: newSettings,
      selectedLibraryName: _state.selectedLibraryName,
      builtLibraryName: invalidatesBuiltLibrary
          ? null
          : _state.builtLibraryName,
      songs: invalidatesBuiltLibrary
          ? const []
          : _state.songs,
      scanning: false,
    );
  }

  Future<void> renameLibrary(
      String oldName,
      String newName,
      ) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Library name cannot be empty.',
      );
    }
    if (oldName != trimmedName &&
        _state.settings.libraries.any(
              (library) => library.name == trimmedName,
        )) {
      throw ArgumentError(
        'A library named "$trimmedName" already exists.',
      );
    }

    final newLibraries =
    _state.settings.libraries.map((library) {
      if (library.name != oldName) {
        return library;
      }

      return MusicLibrary(
        name: trimmedName,
        buildMode: library.buildMode,
        commands: library.commands,
      );
    }).toList();

    final newSelectedName =
    _state.selectedLibraryName == oldName
        ? trimmedName
        : _state.selectedLibraryName;

    final newBuiltName =
    _state.builtLibraryName == oldName
        ? trimmedName
        : _state.builtLibraryName;

    final newSettings = AppSettings(
      rootUri: _state.settings.rootUri,
      libraries: newLibraries,
      selectedLibraryName: newSelectedName,
    );

    await _storage.save(newSettings);

    if (_state.builtLibraryName == oldName &&
        newBuiltName != null) {
      await _persistBuiltLibrary(
        settings: newSettings,
        libraryName: newBuiltName,
        songs: _state.songs,
      );
    }

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

    String? newSelectedName;

    if (newLibraries.isNotEmpty) {
      final previousSelectionStillExists =
          _state.selectedLibraryName != name &&
              newLibraries.any(
                    (library) =>
                library.name == _state.selectedLibraryName,
              );

      newSelectedName = previousSelectionStillExists
          ? _state.selectedLibraryName
          : newLibraries.first.name;
    }

    final newSettings = AppSettings(
      rootUri: _state.settings.rootUri,
      libraries: newLibraries,
      selectedLibraryName: newSelectedName,
    );
    await _storage.save(newSettings);

    final deletedBuiltLibrary =
        _state.builtLibraryName == name;
    if (deletedBuiltLibrary) {
      await _storage.clearBuiltLibrary();
    }
    _state = LibraryState(
      settings: newSettings,
      selectedLibraryName: newSelectedName,
      builtLibraryName: deletedBuiltLibrary
          ? null
          : _state.builtLibraryName,
      songs: deletedBuiltLibrary
          ? const []
          : _state.songs,
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
      final builtLibraryName = _state.selectedLibraryName!;

      await _persistBuiltLibrary(
        settings: _state.settings,
        libraryName: builtLibraryName,
        songs: songs,
      );
      _state = LibraryState(
        settings: _state.settings,
        selectedLibraryName: _state.selectedLibraryName,
        builtLibraryName: builtLibraryName,
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

  String _librarySignature(MusicLibrary library) {
    return jsonEncode(library.toJson());
  }

  MusicLibrary? _findLibrary(
      AppSettings settings,
      String name,
      ) {
    for (final library in settings.libraries) {
      if (library.name == name) {
        return library;
      }
    }

    return null;
  }

  bool _isCacheValid(
      BuiltLibraryCache cache,
      AppSettings settings,
      ) {
    if (cache.rootUri != settings.rootUri) {
      return false;
    }

    final library = _findLibrary(
      settings,
      cache.libraryName,
    );

    if (library == null) {
      return false;
    }

    return cache.librarySignature ==
        _librarySignature(library);
  }

  Future<void> _persistBuiltLibrary({
    required AppSettings settings,
    required String libraryName,
    required List<Song> songs,
  }) async {
    final library = _findLibrary(
      settings,
      libraryName,
    );

    if (library == null) {
      await _storage.clearBuiltLibrary();
      return;
    }

    await _storage.saveBuiltLibrary(
      BuiltLibraryCache(
        rootUri: settings.rootUri,
        libraryName: libraryName,
        librarySignature: _librarySignature(library),
        songs: songs,
      ),
    );
  }
}
