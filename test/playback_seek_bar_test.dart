import 'dart:async';

import 'package:custom_music_player/screens/playback_seek_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('playback duration formatting', () {
    test('formats minutes and seconds', () {
      expect(formatPlaybackDuration(const Duration(seconds: 5)), '0:05');
      expect(
        formatPlaybackDuration(const Duration(minutes: 12, seconds: 9)),
        '12:09',
      );
    });

    test('includes hours for long tracks', () {
      expect(
        formatPlaybackDuration(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '1:02:03',
      );
    });
  });

  testWidgets('updates locally while dragging and seeks once on release', (
    tester,
  ) async {
    final durationController = StreamController<Duration?>();
    final positionController = StreamController<Duration>();
    final seeks = <Duration>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackSeekBar(
            durationStream: durationController.stream,
            positionStream: positionController.stream,
            onSeek: (position) async => seeks.add(position),
          ),
        ),
      ),
    );

    durationController.add(const Duration(seconds: 100));
    positionController.add(const Duration(seconds: 10));
    await tester.pump();

    final slider = find.byType(Slider);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(1000, 0));
    await tester.pump();

    expect(seeks.length, 0);
    expect(find.text('1:40 / 1:40'), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(seeks, [const Duration(seconds: 100)]);

    await durationController.close();
    await positionController.close();
  });

  testWidgets('disables seeking until a positive duration is known', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackSeekBar(
            durationStream: Stream<Duration?>.value(Duration.zero),
            positionStream: Stream<Duration>.value(Duration.zero),
            onSeek: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<Slider>(find.byType(Slider)).onChanged == null, true);
    expect(find.text('0:00 / 0:00'), findsOneWidget);
  });
}
