import 'package:flutter_test/flutter_test.dart';

import 'package:custom_music_player/services/path_utils.dart';

void main() {
  group('PathUtils.normalize', () {
    test('removes unnecessary slashes', () {
      expect(
        PathUtils.normalize('/Anime/Live/'),
        'Anime/Live',
      );
    });

    test('removes dot components', () {
      expect(
        PathUtils.normalize('./Anime/./Live'),
        'Anime/Live',
      );
    });

    test('converts backslashes', () {
      expect(
        PathUtils.normalize(r'Anime\Live\Song.mp3'),
        'Anime/Live/Song.mp3',
      );
    });

    test('empty path represents root', () {
      expect(
        PathUtils.normalize('/'),
        '',
      );
    });

    test('rejects parent traversal', () {
      expect(
            () => PathUtils.normalize('../Anime'),
        throwsArgumentError,
      );

      expect(
            () => PathUtils.normalize('Anime/../../Music'),
        throwsArgumentError,
      );
    });
  });

  group('PathUtils.isWithin', () {
    test('a path is inside itself', () {
      expect(
        PathUtils.isWithin(
          'Anime',
          'Anime',
        ),
        isTrue,
      );
    });

    test('child directory is inside parent', () {
      expect(
        PathUtils.isWithin(
          'Anime',
          'Anime/Live',
        ),
        isTrue,
      );
    });

    test('file is inside parent directory', () {
      expect(
        PathUtils.isWithin(
          'Anime',
          'Anime/Live/song.mp3',
        ),
        isTrue,
      );
    });

    test('similarly named directory is not a child', () {
      expect(
        PathUtils.isWithin(
          'Anime',
          'Anime2/song.mp3',
        ),
        isFalse,
      );
    });

    test('root contains everything', () {
      expect(
        PathUtils.isWithin(
          '',
          'Anime/Live/song.mp3',
        ),
        isTrue,
      );
    });
  });

  group('PathUtils.relativeTo', () {
    test('returns child relative to parent', () {
      expect(
        PathUtils.relativeTo(
          'Anime',
          'Anime/Live/song.mp3',
        ),
        'Live/song.mp3',
      );
    });

    test('same directory produces empty path', () {
      expect(
        PathUtils.relativeTo(
          'Anime',
          'Anime',
        ),
        '',
      );
    });

    test('root produces the original normalized path', () {
      expect(
        PathUtils.relativeTo(
          '',
          'Anime/Live/song.mp3',
        ),
        'Anime/Live/song.mp3',
      );
    });

    test('rejects paths outside parent', () {
      expect(
            () => PathUtils.relativeTo(
          'Anime',
          'Music/song.mp3',
        ),
        throwsArgumentError,
      );
    });
  });

  group('PathUtils.parent', () {
    test('returns parent directory', () {
      expect(
        PathUtils.parent('Anime/Live/song.mp3'),
        'Anime/Live',
      );
    });

    test('root-level entry has root as parent', () {
      expect(
        PathUtils.parent('song.mp3'),
        '',
      );
    });

    test('root has itself as parent', () {
      expect(
        PathUtils.parent(''),
        '',
      );
    });
  });

  group('PathUtils.basename', () {
    test('returns filename', () {
      expect(
        PathUtils.basename(
          'Anime/Live/song.mp3',
        ),
        'song.mp3',
      );
    });

    test('works for root-level files', () {
      expect(
        PathUtils.basename('song.mp3'),
        'song.mp3',
      );
    });
  });
}