import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/utils/story_markers.dart';

void main() {
  group('parseStoryMarkers', () {
    test('splits plain text and markers in order, no gaps/overlap', () {
      const text =
          'Yesterday I [[run|ran]] to the park and bought two [[souvenir|souvenirs]].';

      final segments = parseStoryMarkers(text);

      expect(segments, [
        const PlainStorySegment('Yesterday I '),
        const MarkedStorySegment(targetWord: 'run', surfaceForm: 'ran'),
        const PlainStorySegment(' to the park and bought two '),
        const MarkedStorySegment(targetWord: 'souvenir', surfaceForm: 'souvenirs'),
        const PlainStorySegment('.'),
      ]);
    });

    test('text with no markers returns a single plain segment', () {
      const text = 'No target words here.';
      expect(parseStoryMarkers(text), [const PlainStorySegment(text)]);
    });

    test('empty string returns an empty list', () {
      expect(parseStoryMarkers(''), isEmpty);
    });

    test('text starting and ending with a marker has no empty plain segments', () {
      const text = '[[run|ran]] fast [[jump|jumped]]';
      final segments = parseStoryMarkers(text);

      expect(segments, [
        const MarkedStorySegment(targetWord: 'run', surfaceForm: 'ran'),
        const PlainStorySegment(' fast '),
        const MarkedStorySegment(targetWord: 'jump', surfaceForm: 'jumped'),
      ]);
    });

    test('handles a multi-word target word (phrase) unchanged', () {
      const text = 'She had to [[wake up|woken up]] early.';
      final segments = parseStoryMarkers(text);

      expect(segments, [
        const PlainStorySegment('She had to '),
        const MarkedStorySegment(targetWord: 'wake up', surfaceForm: 'woken up'),
        const PlainStorySegment(' early.'),
      ]);
    });

    test('a repeated target word produces two separate marker segments', () {
      const text = '[[run|Run]], then [[run|run]] again.';
      final segments = parseStoryMarkers(text);

      expect(
        segments.whereType<MarkedStorySegment>().map((s) => s.targetWord),
        ['run', 'run'],
      );
    });
  });

  group('stripStoryMarkers', () {
    test('replaces every marker with its surface form, keeps plain text as-is', () {
      const text =
          'Yesterday I [[run|ran]] to the park and bought two [[souvenir|souvenirs]].';

      expect(
        stripStoryMarkers(text),
        'Yesterday I ran to the park and bought two souvenirs.',
      );
    });

    test('text with no markers is returned unchanged', () {
      const text = 'No target words here.';
      expect(stripStoryMarkers(text), text);
    });

    test('empty string returns empty string', () {
      expect(stripStoryMarkers(''), '');
    });
  });
}
