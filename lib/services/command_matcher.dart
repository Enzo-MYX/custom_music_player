import '../models/build_mode.dart';
import '../models/library_command.dart';
import '../services/path_utils.dart';

class LibraryCommandMatcher {
  final LibraryBuildMode buildMode;
  final _CommandNode _root = _CommandNode();

  LibraryCommandMatcher({
    required this.buildMode,
    required List<LibraryCommand> commands,
  }) {
    for (final command in commands) {
      _insert(command);
    }
  }

  void _insert(LibraryCommand command) {
    final parts = PathUtils.components(command.path);
    var node = _root;
    for (final part in parts) {
      node = node.children.putIfAbsent(
        part,
            () => _CommandNode(),
      );
    }
    node.include = command.include;
  }

  bool shouldInclude(String path) {
    final parts = PathUtils.components(path);
    var node = _root;
    // The root's rule is the default if one exists.
    bool? mostSpecificRule = node.include;
    for (final part in parts) {
      final next = node.children[part];
      if (next == null) {
        break;
      }
      node = next;
      if (node.include != null) {
        mostSpecificRule = node.include;
      }
    }

    return mostSpecificRule ??
        (buildMode == LibraryBuildMode.includeAll);
  }
}

class _CommandNode {
  final Map<String, _CommandNode> children = {};
  bool? include;
}