import 'music_library.dart';
import 'build_mode.dart';

const defaultIgnoreLibrary = MusicLibrary(
  name: 'Ignored files',
  buildMode: LibraryBuildMode.includeNone,
  commands: [],
);

class AppSettings {
  final String? rootUri;
  final List<MusicLibrary> libraries;
  final String? selectedLibraryName;
  final MusicLibrary ignoreLibrary;

  const AppSettings({
    required this.rootUri,
    required this.libraries,
    this.selectedLibraryName,
    this.ignoreLibrary = defaultIgnoreLibrary,
  });

  const AppSettings.empty()
    : rootUri = null,
      libraries = const [],
      selectedLibraryName = null,
      ignoreLibrary = defaultIgnoreLibrary;

  Map<String, dynamic> toJson() {
    return {
      'rootUri': rootUri,
      'libraries': libraries.map((library) => library.toJson()).toList(),
      'selectedLibraryName': selectedLibraryName,
      'ignoreLibrary': ignoreLibrary.toJson(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final librariesJson = json['libraries'] as List<dynamic>? ?? [];
    return AppSettings(
      rootUri: json['rootUri'] as String?,
      libraries: librariesJson
          .map(
            (library) => MusicLibrary.fromJson(
              Map<String, dynamic>.from(library as Map),
            ),
          )
          .toList(),
      selectedLibraryName: json['selectedLibraryName'] as String?,
      ignoreLibrary: json['ignoreLibrary'] is Map
          ? MusicLibrary.fromJson(
              Map<String, dynamic>.from(json['ignoreLibrary'] as Map),
            )
          : defaultIgnoreLibrary,
    );
  }
}
