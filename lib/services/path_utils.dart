class PathUtils {
  const PathUtils._();

  /// Normalizes a relative path used by the library system.
  ///
  /// Paths are always:
  /// - relative to the configured root
  /// - separated using '/'
  /// - free of leading/trailing '/'
  /// - free of '.' components
  ///
  /// '..' is rejected because library paths must never escape
  /// the configured root.
  static String normalize(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) {
      return '';
    }

    // Android SAF paths should use '/' regardless of platform.
    normalized = normalized.replaceAll('\\', '/');

    final parts = normalized.split('/');
    final result = <String>[];

    for (final part in parts) {
      if (part.isEmpty || part == '.') {
        continue;
      }
      if (part == '..') {
        throw ArgumentError(
          'A library path cannot contain "..": $path',
        );
      }
      result.add(part);
    }

    return result.join('/');
  }

  /// Returns the individual components of a normalized path.
  static List<String> components(String path) {
    final normalized = normalize(path);

    if (normalized.isEmpty) {
      return const [];
    }

    return normalized.split('/');
  }

  /// Returns true if [child] is the same path as [parent] or
  /// is somewhere below [parent].
  ///
  /// Examples:
  ///
  /// isWithin('Anime', 'Anime') == true
  /// isWithin('Anime', 'Anime/Live') == true
  /// isWithin('Anime', 'Anime/Live/song.mp3') == true
  /// isWithin('Anime', 'Anime2') == false
  static bool isWithin(String parent, String child) {
    final normalizedParent = normalize(parent);
    final normalizedChild = normalize(child);

    if (normalizedParent.isEmpty) {
      return true;
    }
    if (normalizedChild == normalizedParent) {
      return true;
    }

    return normalizedChild.startsWith(
      '$normalizedParent/',
    );
  }

  /// Returns the path relative to [parent].
  ///
  /// Throws if [child] isn't inside [parent].
  static String relativeTo(String parent, String child) {
    final normalizedParent = normalize(parent);
    final normalizedChild = normalize(child);

    if (!isWithin(
      normalizedParent,
      normalizedChild,
    )) {
      throw ArgumentError(
        '"$child" is not inside "$parent".',
      );
    }
    if (normalizedParent.isEmpty) {
      return normalizedChild;
    }
    if (normalizedChild == normalizedParent) {
      return '';
    }

    return normalizedChild.substring(
      normalizedParent.length + 1,
    );
  }

  /// Returns the parent directory of a path.
  ///
  /// The parent of the root is the root itself.
  static String parent(String path) {
    final normalized = normalize(path);

    if (normalized.isEmpty) {
      return '';
    }
    final lastSlash = normalized.lastIndexOf('/');
    if (lastSlash == -1) {
      return '';
    }

    return normalized.substring(0, lastSlash);
  }

  /// Returns the final component of a path.
  static String basename(String path) {
    final normalized = normalize(path);

    if (normalized.isEmpty) {
      return '';
    }
    final lastSlash = normalized.lastIndexOf('/');
    if (lastSlash == -1) {
      return normalized;
    }

    return normalized.substring(lastSlash + 1);
  }
}