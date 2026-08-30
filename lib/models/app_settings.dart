import 'music_library.dart';

class AppSettings {
  final String? rootUri;
  final List<MusicLibrary> libraries;
  final String? selectedLibraryName;

  const AppSettings({
    required this.rootUri,
    required this.libraries,
    this.selectedLibraryName,
  });

  const AppSettings.empty()
      : rootUri = null,
        libraries = const [],
        selectedLibraryName = null;

  Map<String, dynamic> toJson() {
    return {
      'rootUri': rootUri,
      'libraries': libraries.map((library) => library.toJson()).toList(),
      'selectedLibraryName': selectedLibraryName,
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
    );
  }
}