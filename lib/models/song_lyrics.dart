class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}

class SongLyrics {
  const SongLyrics({required this.text, this.lines = const []});

  final String text;
  final List<LyricLine> lines;

  bool get isSynchronized => lines.isNotEmpty;

  static SongLyrics? parse(String? source) {
    final input = source?.trim();
    if (input == null || input.isEmpty) {
      return null;
    }

    final timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]');
    final synchronized = <LyricLine>[];
    final plain = <String>[];

    for (final rawLine in input.split(RegExp(r'\r?\n'))) {
      final matches = timestamp.allMatches(rawLine).toList();
      final lyricText = rawLine.replaceAll(timestamp, '').trim();

      if (matches.isEmpty) {
        if (!_isLrcMetadata(rawLine) && rawLine.trim().isNotEmpty) {
          plain.add(rawLine.trim());
        }
        continue;
      }

      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fractionText = match.group(3) ?? '';
        final milliseconds = switch (fractionText.length) {
          1 => int.parse(fractionText) * 100,
          2 => int.parse(fractionText) * 10,
          3 => int.parse(fractionText),
          _ => 0,
        };

        synchronized.add(
          LyricLine(
            time: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            ),
            text: lyricText,
          ),
        );
      }
    }

    synchronized.sort((a, b) => a.time.compareTo(b.time));

    if (synchronized.isNotEmpty) {
      return SongLyrics(
        text: synchronized.map((line) => line.text).join('\n'),
        lines: List.unmodifiable(synchronized),
      );
    }

    final text = plain.isEmpty ? input : plain.join('\n');
    return SongLyrics(text: text);
  }

  static bool _isLrcMetadata(String line) {
    return RegExp(
      r'^\[(ar|al|ti|au|by|offset|re|ve|length):.*\]$',
      caseSensitive: false,
    ).hasMatch(line.trim());
  }
}

SongLyrics? chooseLyrics({String? sidecar, String? embedded}) {
  final parsedSidecar = SongLyrics.parse(sidecar);
  final parsedEmbedded = SongLyrics.parse(embedded);

  if (parsedSidecar?.isSynchronized ?? false) {
    return parsedSidecar;
  }
  if (parsedEmbedded?.isSynchronized ?? false) {
    return parsedEmbedded;
  }

  return parsedSidecar ?? parsedEmbedded;
}
