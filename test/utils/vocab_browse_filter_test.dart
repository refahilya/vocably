import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/utils/vocab_browse_filter.dart';

void main() {
  VocabBundleEntry entry({
    required String word,
    List<Map<String, dynamic>>? meanings,
    List<String>? topics,
    String cefrLevel = 'A1',
  }) {
    return VocabBundleEntry.fromMap({
      'word': word,
      'meanings': meanings ?? [
        {'pos': 'noun', 'translationId': 'x'},
      ],
      'posList': [],
      'cefrLevel': cefrLevel,
      'topics': topics ?? const ['Umum'],
    });
  }

  group('sortAlphabetically', () {
    test('sorts by normalized word, case-insensitively', () {
      final input = [
        entry(word: 'Zebra'),
        entry(word: 'apple'),
        entry(word: 'Mango'),
      ];

      final sorted = sortAlphabetically(input);

      expect(sorted.map((e) => e.word), ['apple', 'Mango', 'Zebra']);
    });

    test('does not mutate the input list', () {
      final input = [entry(word: 'Zebra'), entry(word: 'apple')];
      final originalOrder = input.map((e) => e.word).toList();

      sortAlphabetically(input);

      expect(input.map((e) => e.word).toList(), originalOrder);
    });

    test('an empty list stays empty', () {
      expect(sortAlphabetically(const []), isEmpty);
    });
  });

  group('filterByTopic', () {
    test('keeps only words whose topics contain the given topic', () {
      final input = [
        entry(word: 'apple', topics: ['Makanan']),
        entry(word: 'run', topics: ['Aktivitas']),
        entry(word: 'souvenir', topics: ['Perjalanan', 'Makanan']),
      ];

      final result = filterByTopic(input, 'Makanan');

      expect(result.map((e) => e.word), ['apple', 'souvenir']);
    });

    test('a topic with no matches returns an empty list', () {
      final input = [entry(word: 'apple', topics: ['Makanan'])];

      expect(filterByTopic(input, 'Tidak Ada'), isEmpty);
    });
  });

  group('filterByPos', () {
    test('keeps only words that have a meaning with the given pos', () {
      final input = [
        entry(
          word: 'souvenir',
          meanings: [
            {'pos': 'noun', 'translationId': 'a'},
            {'pos': 'verb', 'translationId': 'b'},
          ],
        ),
        entry(
          word: 'apple',
          meanings: [
            {'pos': 'noun', 'translationId': 'c'},
          ],
        ),
      ];

      final nouns = filterByPos(input, 'noun');
      final verbs = filterByPos(input, 'verb');

      expect(nouns.map((e) => e.word), ['souvenir', 'apple']);
      expect(verbs.map((e) => e.word), ['souvenir']);
    });

    test('a pos with no matches returns an empty list', () {
      final input = [
        entry(
          word: 'apple',
          meanings: [
            {'pos': 'noun', 'translationId': 'c'},
          ],
        ),
      ];

      expect(filterByPos(input, 'verb'), isEmpty);
    });
  });

  group('distinctTopics / distinctPosValues', () {
    test('distinctTopics collects every topic actually present, sorted, no duplicates', () {
      final input = [
        entry(word: 'apple', topics: ['Makanan', 'Umum']),
        entry(word: 'souvenir', topics: ['Perjalanan', 'Makanan']),
      ];

      expect(distinctTopics(input), ['Makanan', 'Perjalanan', 'Umum']);
    });

    test('distinctPosValues collects every pos actually present, sorted, no duplicates', () {
      final input = [
        entry(
          word: 'souvenir',
          meanings: [
            {'pos': 'verb', 'translationId': 'a'},
            {'pos': 'noun', 'translationId': 'b'},
          ],
        ),
        entry(
          word: 'apple',
          meanings: [
            {'pos': 'noun', 'translationId': 'c'},
          ],
        ),
      ];

      expect(distinctPosValues(input), ['noun', 'verb']);
    });

    test('an empty entry list produces empty distinct lists', () {
      expect(distinctTopics(const []), isEmpty);
      expect(distinctPosValues(const []), isEmpty);
    });
  });

  group('applyVocabBrowseFilter', () {
    final data = [
      entry(word: 'Zebra', topics: ['Hewan']),
      entry(
        word: 'apple',
        topics: ['Makanan'],
        meanings: [
          {'pos': 'noun', 'translationId': 'a'},
        ],
      ),
      entry(
        word: 'run',
        topics: ['Aktivitas'],
        meanings: [
          {'pos': 'verb', 'translationId': 'b'},
        ],
      ),
    ];

    test('alphabetical mode returns everything, sorted', () {
      final result = applyVocabBrowseFilter(data, mode: VocabBrowseMode.alphabetical);

      expect(result.map((e) => e.word), ['apple', 'run', 'Zebra']);
    });

    test('topic mode with a selection narrows and still sorts', () {
      final result = applyVocabBrowseFilter(
        data,
        mode: VocabBrowseMode.topic,
        selectedTopic: 'Hewan',
      );

      expect(result.map((e) => e.word), ['Zebra']);
    });

    test('topic mode with nothing selected yet returns everything unnarrowed', () {
      final result = applyVocabBrowseFilter(data, mode: VocabBrowseMode.topic);

      expect(result, hasLength(3));
    });

    test('pos mode with a selection narrows and still sorts', () {
      final result = applyVocabBrowseFilter(
        data,
        mode: VocabBrowseMode.pos,
        selectedPos: 'verb',
      );

      expect(result.map((e) => e.word), ['run']);
    });

    test('a selection that matches nothing returns an empty list, not an error', () {
      final result = applyVocabBrowseFilter(
        data,
        mode: VocabBrowseMode.topic,
        selectedTopic: 'Tidak Ada Topik Seperti Ini',
      );

      expect(result, isEmpty);
    });

    test('filtering does not mutate the original list', () {
      final originalOrder = data.map((e) => e.word).toList();

      applyVocabBrowseFilter(data, mode: VocabBrowseMode.pos, selectedPos: 'verb');

      expect(data.map((e) => e.word).toList(), originalOrder);
    });
  });
}
