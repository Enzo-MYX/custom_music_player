import 'dart:math';

class ShuffleOrder {
  ShuffleOrder({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<int> _indices = const [];
  int _position = -1;

  List<int> get indices => List.unmodifiable(_indices);

  int get length => _indices.length;

  int get position => _position;

  int? get currentIndex {
    if (_position < 0 || _position >= _indices.length) {
      return null;
    }

    return _indices[_position];
  }

  bool get canGoPrevious => _position > 0;

  bool get canGoNext => _position >= 0 && _position < _indices.length - 1;

  void reset(int songCount, {int? avoidFirstIndex}) {
    if (songCount < 0) {
      throw ArgumentError.value(
        songCount,
        'songCount',
        'Song count cannot be negative.',
      );
    }

    _indices = List<int>.generate(songCount, (index) => index)
      ..shuffle(_random);

    if (_indices.length > 1 &&
        avoidFirstIndex != null &&
        _indices.first == avoidFirstIndex) {
      final replacementPosition = _indices.indexWhere(
        (index) => index != avoidFirstIndex,
      );

      final replacementIndex = _indices[replacementPosition];

      _indices[replacementPosition] = _indices.first;
      _indices[0] = replacementIndex;
    }

    _position = _indices.isEmpty ? -1 : 0;
  }

  int? movePrevious() {
    if (!canGoPrevious) {
      return null;
    }

    _position--;
    return currentIndex;
  }

  int? moveNext() {
    if (!canGoNext) {
      return null;
    }

    _position++;
    return currentIndex;
  }
}
