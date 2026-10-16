import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_progress.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/history_providers.dart';

VocabBundleEntry _entry(String word) {
  return VocabBundleEntry(
    word: word,
    meanings: const [VocabMeaning(pos: 'verb', translation: 'terjemahan')],
    cefrLevel: 'A1',
    topics: const [],
  );
}

HistoryWordEntry _row({required String status, VocabBundleEntry? entry}) {
  return HistoryWordEntry(
    progress: LearningProgress(
      studentId: 'student-1',
      wordId: entry?.word ?? 'unknown',
      learnedStatus: LearnedStatus.sudahDipelajari,
      masteryStatus: status,
      firstLearnedAt: DateTime(2026, 1, 1),
      lastUpdatedAt: DateTime(2026, 1, 2),
      lastSessionId: 'session-1',
    ),
    entry: entry,
  );
}

void main() {
  group('applyHistoryFilter', () {
    final mastered = _row(status: MasteryStatus.mastered, entry: _entry('run'));
    final difficult = _row(status: MasteryStatus.difficult, entry: _entry('souvenir'));
    final all = [mastered, difficult];

    test('HistoryMasteryFilter.all returns everything unchanged', () {
      expect(applyHistoryFilter(all, HistoryMasteryFilter.all), all);
    });

    test('HistoryMasteryFilter.mastered keeps only mastered rows', () {
      expect(applyHistoryFilter(all, HistoryMasteryFilter.mastered), [mastered]);
    });

    test('HistoryMasteryFilter.difficult keeps only difficult rows', () {
      expect(applyHistoryFilter(all, HistoryMasteryFilter.difficult), [difficult]);
    });

    test('an empty input list stays empty for every filter', () {
      for (final filter in HistoryMasteryFilter.values) {
        expect(applyHistoryFilter(const [], filter), isEmpty);
      }
    });

    test('a filter that matches nothing returns an empty list, not an error', () {
      expect(applyHistoryFilter([mastered], HistoryMasteryFilter.difficult), isEmpty);
    });
  });

  group('HistoryFilter notifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('defaults to HistoryMasteryFilter.all', () {
      expect(container.read(historyFilterProvider), HistoryMasteryFilter.all);
    });

    test('select updates the state', () {
      container.read(historyFilterProvider.notifier).select(HistoryMasteryFilter.difficult);
      expect(container.read(historyFilterProvider), HistoryMasteryFilter.difficult);
    });
  });

  group('difficult-word eligibility helpers', () {
    HistoryWordEntry rowFor(String wordId, String status, {bool resolved = true}) {
      return HistoryWordEntry(
        progress: LearningProgress(
          studentId: 'student-1',
          wordId: wordId,
          learnedStatus: LearnedStatus.sudahDipelajari,
          masteryStatus: status,
          firstLearnedAt: DateTime(2026, 1, 1),
          lastUpdatedAt: DateTime(2026, 1, 2),
          lastSessionId: 'session-1',
        ),
        entry: resolved ? _entry(wordId) : null,
      );
    }

    final rows = [
      rowFor('run', MasteryStatus.mastered),
      rowFor('souvenir', MasteryStatus.difficult),
      rowFor('attack', MasteryStatus.difficult),
      rowFor('ghostword', MasteryStatus.difficult, resolved: false),
    ];

    test('difficultWordIds keeps every difficult row, including unresolved ones', () {
      expect(difficultWordIds(rows), {'souvenir', 'attack', 'ghostword'});
      expect(difficultWordIds(const []), isEmpty);
    });

    test('effectiveDifficultSelection is the selection ∩ current difficult rows, in list order', () {
      expect(
        effectiveDifficultSelection(
          selected: {'attack', 'run', 'ghostword', 'not-in-history'},
          entries: rows,
        ),
        ['attack', 'ghostword'],
      );
    });

    test('a selected word that became mastered is excluded; others are kept', () {
      final after = [
        rowFor('run', MasteryStatus.mastered),
        rowFor('souvenir', MasteryStatus.mastered),
        rowFor('attack', MasteryStatus.difficult),
      ];
      expect(
        effectiveDifficultSelection(selected: {'souvenir', 'attack'}, entries: after),
        ['attack'],
      );
    });

    test('an empty selection or an empty list yields nothing', () {
      expect(effectiveDifficultSelection(selected: const {}, entries: rows), isEmpty);
      expect(effectiveDifficultSelection(selected: {'attack'}, entries: const []), isEmpty);
    });
  });

  group('HistoryDifficultSelection notifier', () {
    late ProviderContainer container;
    late List<HistoryWordEntry> current;

    HistoryWordEntry rowFor(String wordId, String status) {
      return HistoryWordEntry(
        progress: LearningProgress(
          studentId: 'student-1',
          wordId: wordId,
          learnedStatus: LearnedStatus.sudahDipelajari,
          masteryStatus: status,
          firstLearnedAt: DateTime(2026, 1, 1),
          lastUpdatedAt: DateTime(2026, 1, 2),
          lastSessionId: 'session-1',
        ),
        entry: _entry(wordId),
      );
    }

    setUp(() {
      current = [
        rowFor('souvenir', MasteryStatus.difficult),
        rowFor('attack', MasteryStatus.difficult),
      ];
      container = ProviderContainer(
        overrides: [
          historyWordEntriesProvider('student-1').overrideWith((ref) async => current),
        ],
      );
      addTearDown(container.dispose);
    });

    Set<String> selection() => container.read(historyDifficultSelectionProvider('student-1'));
    HistoryDifficultSelection notifier() =>
        container.read(historyDifficultSelectionProvider('student-1').notifier);

    test('starts empty', () {
      final sub = container.listen(historyDifficultSelectionProvider('student-1'), (_, _) {});
      addTearDown(sub.close);
      expect(selection(), isEmpty);
    });

    test('toggle selects and deselects, keyed by normalized word', () {
      final sub = container.listen(historyDifficultSelectionProvider('student-1'), (_, _) {});
      addTearDown(sub.close);
      notifier().toggle(' Souvenir ');
      expect(selection(), {'souvenir'});
      notifier().toggle('souvenir');
      expect(selection(), isEmpty);
    });

    test('selectAll adds without duplicates; clear empties', () {
      final sub = container.listen(historyDifficultSelectionProvider('student-1'), (_, _) {});
      addTearDown(sub.close);
      notifier().toggle('attack');
      notifier().selectAll(['souvenir', 'attack', 'ATTACK']);
      expect(selection(), {'souvenir', 'attack'});
      notifier().clear();
      expect(selection(), isEmpty);
    });

    test(
      'when History data updates, words no longer difficult are pruned and '
      'still-difficult selections are kept',
      () async {
        final sub = container.listen(historyDifficultSelectionProvider('student-1'), (_, _) {});
        addTearDown(sub.close);
        await container.read(historyWordEntriesProvider('student-1').future);
        notifier().selectAll(['souvenir', 'attack']);

        current = [
          rowFor('souvenir', MasteryStatus.mastered),
          rowFor('attack', MasteryStatus.difficult),
        ];
        container.invalidate(historyWordEntriesProvider('student-1'));
        await container.read(historyWordEntriesProvider('student-1').future);

        expect(selection(), {'attack'});
      },
    );

    test('a record that disappears entirely is pruned too', () async {
      final sub = container.listen(historyDifficultSelectionProvider('student-1'), (_, _) {});
      addTearDown(sub.close);
      await container.read(historyWordEntriesProvider('student-1').future);
      notifier().selectAll(['souvenir', 'attack']);

      current = [rowFor('attack', MasteryStatus.difficult)];
      container.invalidate(historyWordEntriesProvider('student-1'));
      await container.read(historyWordEntriesProvider('student-1').future);

      expect(selection(), {'attack'});
    });
  });
}
