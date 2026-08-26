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
        {'pos': 'noun', 'translation': 'x'},
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
            {'pos': 'noun', 'translation': 'a'},
            {'pos': 'verb', 'translation': 'b'},
          ],
        ),
        entry(
          word: 'apple',
          meanings: [
            {'pos': 'noun', 'translation': 'c'},
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
            {'pos': 'noun', 'translation': 'c'},
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
            {'pos': 'verb', 'translation': 'a'},
            {'pos': 'noun', 'translation': 'b'},
          ],
        ),
        entry(
          word: 'apple',
          meanings: [
            {'pos': 'noun', 'translation': 'c'},
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
          {'pos': 'noun', 'translation': 'a'},
        ],
      ),
      entry(
        word: 'run',
        topics: ['Aktivitas'],
        meanings: [
          {'pos': 'verb', 'translation': 'b'},
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

  group('paginate', () {
    List<int> range(int n) => List.generate(n, (i) => i);

    test('0 results: 0 total pages, empty items, no crash', () {
      final result = paginate<int>(const [], page: 0);
      expect(result.items, isEmpty);
      expect(result.totalPages, 0);
      expect(result.pageIndex, 0);
    });

    test('fewer than a full page (30 of 50): a single page containing all of them', () {
      final result = paginate(range(30), page: 0);
      expect(result.items, range(30));
      expect(result.totalPages, 1);
      expect(result.pageIndex, 0);
    });

    test('exactly one page size (50): a single page, not an empty trailing second page', () {
      final result = paginate(range(50), page: 0);
      expect(result.items, hasLength(50));
      expect(result.totalPages, 1);
    });

    test('more than one page (120 items -> 3 pages of 50/50/20)', () {
      final items = range(120);
      final page0 = paginate(items, page: 0);
      final page1 = paginate(items, page: 1);
      final page2 = paginate(items, page: 2);

      expect(page0.totalPages, 3);
      expect(page0.items, hasLength(50));
      expect(page0.items.first, 0);
      expect(page1.items, hasLength(50));
      expect(page1.items.first, 50);
      // last page smaller than the page size
      expect(page2.items, hasLength(20));
      expect(page2.items.first, 100);
      expect(page2.items.last, 119);
    });

    test('requesting a page past the last one clamps to the last page (acts as "Next" disabled)', () {
      final result = paginate(range(120), page: 99);
      expect(result.pageIndex, 2);
      expect(result.items, hasLength(20));
    });

    test('requesting a negative page clamps to page 0 (acts as "Previous" disabled)', () {
      final result = paginate(range(120), page: -5);
      expect(result.pageIndex, 0);
      expect(result.items.first, 0);
    });

    test('next/previous navigation walks pages in order without gaps or overlap', () {
      final items = range(120);
      final seen = <int>[];
      for (var page = 0; page < paginate(items, page: 0).totalPages; page++) {
        seen.addAll(paginate(items, page: page).items);
      }
      expect(seen, items);
    });

    test('does not mutate the original list', () {
      final items = range(120);
      final originalCopy = [...items];

      paginate(items, page: 1);

      expect(items, originalCopy);
    });

    test('a custom page size is respected', () {
      final result = paginate(range(10), page: 0, pageSize: 4);
      expect(result.totalPages, 3); // 4, 4, 2
      expect(result.items, hasLength(4));
    });
  });
}
