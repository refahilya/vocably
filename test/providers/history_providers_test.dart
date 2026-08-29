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
}
