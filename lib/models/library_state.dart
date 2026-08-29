import 'app_settings.dart';
import 'music_library.dart';
import 'song.dart';

class LibraryState {
  static const Object _notProvided = Object();

  final AppSettings settings;
  final String? selectedLibraryName;
  final String? builtLibraryName;
  final List<Song> songs;
  final bool scanning;

  const LibraryState({
    required this.settings,
    required this.selectedLibraryName,
    required this.builtLibraryName,
    required this.songs,
    required this.scanning,
  });

  const LibraryState.initial()
    : settings = const AppSettings.empty(),
      selectedLibraryName = null,
      builtLibraryName = null,
      songs = const [],
      scanning = false;

  bool get needsRebuild {
    final selectedName = selectedLibraryName;
    return selectedName != null && builtLibraryName != selectedName;
  }

  MusicLibrary? get selectedLibrary {
    final name = selectedLibraryName;
    if (name == null) {
      return null;
    }
    for (final library in settings.libraries) {
      if (library.name == name) {
        return library;
      }
    }
    return null;
  }

  LibraryState copyWith({
    AppSettings? settings,
    String? selectedLibraryName,
    Object? builtLibraryName = _notProvided,
    List<Song>? songs,
    bool? scanning,
  }) {
    return LibraryState(
      settings: settings ?? this.settings,
      selectedLibraryName: selectedLibraryName ?? this.selectedLibraryName,
      builtLibraryName: identical(builtLibraryName, _notProvided)
          ? this.builtLibraryName
          : builtLibraryName as String?,
      songs: songs ?? this.songs,
      scanning: scanning ?? this.scanning,
    );
  }
}
