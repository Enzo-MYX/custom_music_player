import 'music_library.dart';

class AppSettings {
  final String? rootUri;
  final List<MusicLibrary> libraries;

  const AppSettings({
    required this.rootUri,
    required this.libraries,
  });

  const AppSettings.empty()
      : rootUri = null,
        libraries = const [];

  Map<String, dynamic> toJson() {
    return {
      'rootUri': rootUri,
      'libraries': libraries
          .map((library) => library.toJson())
          .toList(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final librariesJson = json['libraries'] as List<dynamic>? ?? [];
    return AppSettings(
      rootUri: json['rootUri'] as String?,
      libraries: librariesJson
          .map(
            (library) => MusicLibrary.fromJson(
          library as Map<String, dynamic>,
        ),
      ).toList(),
    );
  }
}