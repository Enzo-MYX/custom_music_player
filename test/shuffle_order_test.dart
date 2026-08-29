import 'dart:math';

import 'package:custom_music_player/services/shuffle_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shuffle contains every song index exactly once', () {
    final order = ShuffleOrder(random: Random(42));

    order.reset(100);

    expect(order.indices.length, 100);
    expect(order.indices.toSet().length, 100);
    expect(
      order.indices.toSet(),
      Set<int>.from(List<int>.generate(100, (index) => index)),
    );
  });

  test('reset selects the first shuffled song', () {
    final order = ShuffleOrder(random: Random(42));

    order.reset(10);

    expect(order.position, 0);
    expect(order.currentIndex, order.indices.first);
  });

  test('next and previous move through shuffled order', () {
    final order = ShuffleOrder(random: Random(42));

    order.reset(10);

    final firstIndex = order.currentIndex;
    final secondIndex = order.moveNext();

    expect(secondIndex, order.indices[1]);
    expect(order.position, 1);
    expect(order.movePrevious(), firstIndex);
    expect(order.position, 0);
  });

  test('navigation stops at both ends of the order', () {
    final order = ShuffleOrder(random: Random(42));

    order.reset(2);

    expect(order.movePrevious(), isNull);
    expect(order.moveNext(), isNotNull);
    expect(order.moveNext(), isNull);
  });

  test('empty library produces no current index', () {
    final order = ShuffleOrder(random: Random(42));

    order.reset(0);

    expect(order.indices, isEmpty);
    expect(order.position, -1);
    expect(order.currentIndex, isNull);
    expect(order.canGoPrevious, isFalse);
    expect(order.canGoNext, isFalse);
  });

  test('new cycle can avoid immediately repeating final song', () {
    final order = ShuffleOrder(random: Random(42));

    order.reset(10, avoidFirstIndex: 4);

    expect(order.currentIndex, isNot(4));
    expect(
      order.indices.toSet(),
      Set<int>.from(List<int>.generate(10, (index) => index)),
    );
  });

  test('one-song library may repeat its only song', () {
    final order = ShuffleOrder(random: Random(42));

    order.reset(1, avoidFirstIndex: 0);

    expect(order.currentIndex, 0);
  });

  test('negative song count is rejected', () {
    final order = ShuffleOrder();

    expect(() => order.reset(-1), throwsArgumentError);
  });
}
