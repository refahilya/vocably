/// Shared parser for the `[[kataTarget|bentukTerpakai]]` markers a
/// generated story comes back with (`DATA_MODEL.md` §4, `CLAUDE.md` §4:
/// "Jangan pernah mencari kata target di teks cerita dengan pencarian
/// string... Taruh parser-nya di `utils/` dan pakai fungsi yang sama di
/// Fase 1, Fase 2, dan tampilan riwayat.").
///
/// Milestone 6 is the first consumer — Riwayat "Per Sesi" replays a
/// stored `learningSessions.storyContent` read-only, so it only needs the
/// two building blocks below (segment the marked text; strip markers for
/// plain display). Milestone 7's Fase 1 (tap-to-open-dictionary highlight)
/// and Fase 2 (cloze blanks, "only the first occurrence of each word
/// becomes a blank") are built on top of the same [parseStoryMarkers]
/// output — this file deliberately stops at parsing, and does not
/// implement any cloze/highlight-specific behavior itself.
library;

/// One piece of a parsed story: either plain text the student reads as-is,
/// or a target-word marker that was originally written as
/// `[[targetWord|surfaceForm]]`.
sealed class StorySegment {
  const StorySegment();
}

/// Plain text between (or around) markers — rendered as-is, never
/// highlighted, never tappable.
class PlainStorySegment extends StorySegment {
  const PlainStorySegment(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is PlainStorySegment && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'PlainStorySegment($text)';
}

/// One target-word marker.
///
/// [targetWord] is the base form the story generation request was given
/// (already `normalizeWord()`-ed on the way in, per `DATA_MODEL.md` §4) —
/// use this to open the dictionary or match against a target-word list.
/// [surfaceForm] is the natural inflected form the AI actually wrote in
/// the sentence (e.g. "ran" for target word "run") — this is what gets
/// displayed/highlighted, never [targetWord].
class MarkedStorySegment extends StorySegment {
  const MarkedStorySegment({
    required this.targetWord,
    required this.surfaceForm,
  });

  final String targetWord;
  final String surfaceForm;

  @override
  bool operator ==(Object other) =>
      other is MarkedStorySegment &&
      other.targetWord == targetWord &&
      other.surfaceForm == surfaceForm;

  @override
  int get hashCode => Object.hash(targetWord, surfaceForm);

  @override
  String toString() =>
      'MarkedStorySegment(targetWord: $targetWord, surfaceForm: $surfaceForm)';
}

/// Matches `[[targetWord|surfaceForm]]`. Deliberately excludes `|` and `]`
/// from both captured groups rather than being maximally permissive — a
/// well-formed marker never contains either character, and excluding them
/// keeps a malformed/truncated marker from silently swallowing the rest of
/// the story into one capture group.
final RegExp _markerPattern = RegExp(r'\[\[([^\|\]]+)\|([^\]]+)\]\]');

/// Splits [markedText] (a `storyContent`-shaped string) into an ordered
/// list of [PlainStorySegment]/[MarkedStorySegment] pieces. Pure, no I/O —
/// safe to call on any string, including one with zero markers (returns a
/// single [PlainStorySegment] with the whole text) or an empty string
/// (returns an empty list).
List<StorySegment> parseStoryMarkers(String markedText) {
  final segments = <StorySegment>[];
  var cursor = 0;

  for (final match in _markerPattern.allMatches(markedText)) {
    if (match.start > cursor) {
      segments.add(
        PlainStorySegment(markedText.substring(cursor, match.start)),
      );
    }
    segments.add(
      MarkedStorySegment(
        targetWord: match.group(1)!,
        surfaceForm: match.group(2)!,
      ),
    );
    cursor = match.end;
  }

  if (cursor < markedText.length) {
    segments.add(PlainStorySegment(markedText.substring(cursor)));
  }

  return segments;
}

/// Renders [markedText] as plain, marker-free text — every
/// `[[targetWord|surfaceForm]]` replaced by just `surfaceForm` (the form
/// that actually reads naturally in the sentence). `CLAUDE.md` §4: "Selalu
/// strip penanda sebelum menampilkan teks polos" — this is that stripping
/// step, kept in one place so every screen that needs plain text (not
/// highlighted segments) calls the same function.
String stripStoryMarkers(String markedText) {
  final buffer = StringBuffer();
  for (final segment in parseStoryMarkers(markedText)) {
    buffer.write(switch (segment) {
      PlainStorySegment(:final text) => text,
      MarkedStorySegment(:final surfaceForm) => surfaceForm,
    });
  }
  return buffer.toString();
}

/// Strips internal markers (e.g. `[[word|translation]]` or `[[translation]]`)
/// from a translation string so the end-user sees only plain readable Indonesian text.
String stripTranslationMarkers(String translation) {
  return translation.replaceAllMapped(
    RegExp(r'\[\[(?:[^|\]]+\|)?([^\]]+)\]\]'),
    (match) => match.group(1)!,
  );
}
