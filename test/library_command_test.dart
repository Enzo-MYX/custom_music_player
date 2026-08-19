import 'package:flutter_test/flutter_test.dart';

import 'package:custom_music_player/models/library_command.dart';

void main() {
  test('include command has plus display', () {
    const command = LibraryCommand(
      include: true,
      path: 'Anime/Live/',
    );

    expect(
      command.displayText,
      '+ Anime/Live',
    );
  });

  test('exclude command has minus display', () {
    const command = LibraryCommand(
      include: false,
      path: 'Anime/Remixes',
    );

    expect(
      command.displayText,
      '- Anime/Remixes',
    );
  });
}