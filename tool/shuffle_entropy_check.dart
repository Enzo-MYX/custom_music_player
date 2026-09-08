import 'dart:math';

import 'package:custom_music_player/services/shuffle_order.dart';

const int _defaultArraySize = 37;
const int _defaultRunCount = 8;
const double _minimumNormalizedEntropy = 0.65;

void main(List<String> arguments) {
  final arraySize = arguments.isEmpty
      ? _defaultArraySize
      : int.parse(arguments.first);
  final runCount = arguments.length < 2
      ? _defaultRunCount
      : int.parse(arguments[1]);

  if (arraySize <= 10) {
    throw ArgumentError.value(
      arraySize,
      'arraySize',
      'Must be greater than 10.',
    );
  }
  if (runCount < 5 || runCount > 10) {
    throw ArgumentError.value(runCount, 'runCount', 'Must be from 5 to 10.');
  }

  final positionsByValue = List.generate(arraySize, (_) => <int>[]);

  for (var run = 0; run < runCount; run++) {
    final shuffle = ShuffleOrder()..reset(arraySize);
    final output = shuffle.indices;
    _verifyPermutation(output, arraySize);

    for (var position = 0; position < output.length; position++) {
      positionsByValue[output[position]].add(position);
    }
  }

  final entropy =
      positionsByValue
          .map(
            (positions) => _normalizedEntropy(positions, arraySize, runCount),
          )
          .reduce((sum, value) => sum + value) /
      arraySize;

  print(
    'Shuffle entropy: ${entropy.toStringAsFixed(4)} '
    '(size=$arraySize, runs=$runCount)',
  );

  if (entropy < _minimumNormalizedEntropy) {
    throw StateError(
      'Normalized shuffle entropy ${entropy.toStringAsFixed(4)} is below '
      'the $_minimumNormalizedEntropy threshold.',
    );
  }
}

void _verifyPermutation(List<int> output, int size) {
  if (output.length != size ||
      output.toSet().length != size ||
      output.any((value) => value < 0 || value >= size)) {
    throw StateError('Shuffle output is not a permutation of the input array.');
  }
}

double _normalizedEntropy(List<int> positions, int size, int runCount) {
  final counts = <int, int>{};
  for (final position in positions) {
    counts.update(position, (count) => count + 1, ifAbsent: () => 1);
  }

  var entropy = 0.0;
  for (final count in counts.values) {
    final probability = count / runCount;
    entropy -= probability * (log(probability) / ln2);
  }

  // With only 5-10 observations, no value can occupy more than runCount
  // distinct positions. Normalize against that attainable maximum instead of
  // log2(size), so different arrays larger than ten remain comparable.
  final maximumEntropy = log(min(size, runCount)) / ln2;
  return maximumEntropy == 0 ? 0 : entropy / maximumEntropy;
}
