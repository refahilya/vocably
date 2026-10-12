import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/utils/cloze_blanks.dart';

void main() {
  group('buildClozeSegments', () {
    test('a simple story with two distinct target words', () {
      final segments = buildClozeSegments(
        'Yesterday I [[run|ran]] to the park and bought a [[souvenir|souvenir]].',
      );

      expect(segments, [
        const ClozePlainSegment('Yesterday I '),
        const ClozeBlankSegment('run'),
        const ClozePlainSegment(' to the park and bought a '),
        const ClozeBlankSegment('souvenir'),
        const ClozePlainSegment('.'),
      ]);
    });

    test(
      'only the FIRST occurrence of a repeated target word becomes a blank; the '
      'rest are classified as ClozeHighlightSegment (DATA_MODEL.md §4) — a defensive '
      'fallback only, since Stage 1/2 already reject a repeated marker before this '
      'point is ever reached in the live app (Milestone 7 Phase 2 Stage 4)',
      () {
        final segments = buildClozeSegments(
          'I [[run|ran]] yesterday. Today I will [[run|run]] again.',
        );

        expect(segments, [
          const ClozePlainSegment('I '),
          const ClozeBlankSegment('run'),
          const ClozePlainSegment(' yesterday. Today I will '),
          const ClozeHighlightSegment('run'),
          const ClozePlainSegment(' again.'),
        ]);
      },
    );

    test('a story with no markers is a single plain segment', () {
      final segments = buildClozeSegments('Just a plain sentence.');
      expect(segments, [const ClozePlainSegment('Just a plain sentence.')]);
    });

    test('an empty story produces no segments', () {
      expect(buildClozeSegments(''), isEmpty);
    });
  });

  group('blankTargetWords', () {
    test('lists blanks in first-appearance order, excluding repeats', () {
      final segments = buildClozeSegments(
        '[[souvenir|souvenirs]] and [[run|running]] and [[souvenir|souvenir]] again.',
      );
      expect(blankTargetWords(segments), ['souvenir', 'run']);
    });
  });

  group('shuffleClozeOptions', () {
    test('contains all expected target words exactly once', () {
      final input = ['harvest', 'fragile', 'wander', 'shelter', 'whisper'];
      final shuffled = shuffleClozeOptions(input);

      expect(shuffled.length, input.length);
      expect(shuffled.toSet(), input.toSet());
    });

    test('does not mutate the original input list', () {
      final input = ['harvest', 'fragile', 'wander', 'shelter', 'whisper'];
      final originalCopy = List<String>.from(input);
      shuffleClozeOptions(input);

      expect(input, originalCopy);
    });

    test('handles empty and single-element lists without error', () {
      expect(shuffleClozeOptions([]), isEmpty);
      expect(shuffleClozeOptions(['harvest']), ['harvest']);
    });

    test('produces deterministic permutation when seeded Random is provided', () {
      final input = ['harvest', 'fragile', 'wander', 'shelter', 'whisper'];
      final seeded1 = shuffleClozeOptions(input, Random(42));
      final seeded2 = shuffleClozeOptions(input, Random(42));

      expect(seeded1, seeded2);
      expect(seeded1.toSet(), input.toSet());
    });
  });

  group('storyMarkersMatchWordIds', () {
    test('a story marking exactly the requested words, each once, matches', () {
      expect(
        storyMarkersMatchWordIds(
          'Yesterday I [[run|ran]] to the park and bought a [[souvenir|souvenir]].',
          ['run', 'souvenir'],
        ),
        isTrue,
      );
    });

    test('a missing target word (never marked) does not match', () {
      expect(
        storyMarkersMatchWordIds('Yesterday I [[run|ran]] to the park.', ['run', 'souvenir']),
        isFalse,
      );
    });

    test('an extra/hallucinated marker for a word that was not requested does not match', () {
      expect(
        storyMarkersMatchWordIds(
          'I [[run|ran]] to the park and grabbed a [[souvenir|souvenir]].',
          ['run'], // "souvenir" was never requested
        ),
        isFalse,
      );
    });

    test('a duplicate marker for the same requested word does not match', () {
      expect(
        storyMarkersMatchWordIds(
          'I [[run|ran]] to the park, then [[run|ran]] home.',
          ['run'],
        ),
        isFalse,
      );
    });

    test('a spelling/case mismatch in the marker does not match', () {
      expect(
        storyMarkersMatchWordIds('Yesterday I [[Run|ran]] to the park.', ['run']),
        isFalse,
      );
    });

    test('a story with no markers at all does not match a non-empty word list', () {
      expect(storyMarkersMatchWordIds('Just a plain sentence.', ['run']), isFalse);
    });
  });

  group('gradeClozeAnswers', () {
    test('grades each blank against its own target word', () {
      final segments = buildClozeSegments('I [[run|ran]] and bought a [[souvenir|souvenir]].');

      final grading = gradeClozeAnswers(segments, {'run': 'run', 'souvenir': 'run'});

      expect(grading, {'run': true, 'souvenir': false});
    });

    test('an unanswered blank (null/absent) grades as incorrect, not a crash', () {
      final segments = buildClozeSegments('I [[run|ran]] today.');

      expect(gradeClozeAnswers(segments, {}), {'run': false});
      expect(gradeClozeAnswers(segments, {'run': null}), {'run': false});
    });

    test('grades correctly when target words appear in a different order from canonical list', () {
      final segments = buildClozeSegments(
        'I bought a [[souvenir|souvenir]]. Then I [[run|ran]] home.',
      );
      // Canonical list was ['run', 'souvenir'], but story order is ['souvenir', 'run']
      final blanks = blankTargetWords(segments);
      expect(blanks, ['souvenir', 'run']);

      final grading = gradeClozeAnswers(segments, {
        'souvenir': 'souvenir',
        'run': 'run',
      });
      expect(grading, {'souvenir': true, 'run': true});
    });
  });
}
