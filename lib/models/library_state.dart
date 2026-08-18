import 'app_settings.dart';
import 'music_library.dart';
import 'song.dart';

class LibraryState {
  final AppSettings settings;
  final String? selectedLibraryName;
  final List<Song> songs;
  final bool scanning;

  const LibraryState({
    required this.settings,
    required this.selectedLibraryName,
    required this.songs,
    required this.scanning,
  });

  const LibraryState.initial()
      : settings = const AppSettings.empty(),
        selectedLibraryName = null,
        songs = const [],
        scanning = false;

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
    List<Song>? songs,
    bool? scanning,
  }) {
    return LibraryState(
      settings: settings ?? this.settings,
      selectedLibraryName:
      selectedLibraryName ?? this.selectedLibraryName,
      songs: songs ?? this.songs,
      scanning: scanning ?? this.scanning,
    );
  }
}