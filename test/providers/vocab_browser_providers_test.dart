import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/providers/vocab_browser_providers.dart';
import 'package:vocably/utils/cefr_levels.dart';
import 'package:vocably/utils/vocab_browse_filter.dart';

void main() {
  late ProviderContainer container;
  late VocabBrowserFilterProvider provider;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    provider = vocabBrowserFilterProvider(VocabBrowserVisit('A1'));
  });

  VocabBrowserFilter notifier() =>
      container.read(provider.notifier);

  group('VocabBrowserFilter — page reset (Milestone 4 pagination)', () {
    test('starts at page 0', () {
      expect(container.read(provider).page, 0);
    });

    test('goToPage moves to the requested page', () {
      notifier().goToPage(3);
      expect(container.read(provider).page, 3);
    });

    test('selectLevel resets page to 0', () {
      notifier().goToPage(3);
      notifier().selectLevel('B1');
      expect(container.read(provider).page, 0);
      expect(container.read(provider).cefrLevel, 'B1');
    });

    test('selectMode resets page to 0', () {
      notifier().goToPage(2);
      notifier().selectMode(VocabBrowseMode.topic);
      expect(container.read(provider).page, 0);
      expect(container.read(provider).mode, VocabBrowseMode.topic);
    });

    test('selectTopic resets page to 0', () {
      notifier().goToPage(2);
      notifier().selectTopic('Perjalanan');
      expect(container.read(provider).page, 0);
      expect(container.read(provider).selectedTopic, 'Perjalanan');
    });

    test('selectPos resets page to 0', () {
      notifier().goToPage(2);
      notifier().selectPos('verb');
      expect(container.read(provider).page, 0);
      expect(container.read(provider).selectedPos, 'verb');
    });

    test('clearing topic (selectTopic(null)) also resets page to 0', () {
      notifier().selectTopic('Perjalanan');
      notifier().goToPage(2);
      notifier().selectTopic(null);
      expect(container.read(provider).page, 0);
      expect(container.read(provider).selectedTopic, isNull);
    });

    test('goToPage does not disturb level/mode/topic/pos selection', () {
      notifier().selectLevel('B2');
      notifier().selectMode(VocabBrowseMode.pos);
      notifier().selectPos('adjective');
      notifier().goToPage(4);

      final state = container.read(provider);
      expect(state.cefrLevel, 'B2');
      expect(state.mode, VocabBrowseMode.pos);
      expect(state.selectedPos, 'adjective');
      expect(state.page, 4);
    });
  });

  group('VocabBrowserFilter — one filter per visit', () {
    for (final level in kCefrLevels) {
      test('a visit starts at its level, in Abjad, on page 0 ($level)', () {
        final state = container.read(
          vocabBrowserFilterProvider(VocabBrowserVisit(level)),
        );
        expect(state.cefrLevel, level);
        expect(state.mode, VocabBrowseMode.alphabetical);
        expect(state.selectedTopic, isNull);
        expect(state.selectedPos, isNull);
        expect(state.page, 0);
      });
    }

    test('two visits to the same level do not share a filter', () {
      final first = vocabBrowserFilterProvider(VocabBrowserVisit('B1'));
      final second = vocabBrowserFilterProvider(VocabBrowserVisit('B1'));
      final subscription = container.listen(first, (_, _) {});
      addTearDown(subscription.close);

      container.read(first.notifier)
        ..selectLevel('C1')
        ..selectMode(VocabBrowseMode.pos);

      final fresh = container.read(second);
      expect(fresh.cefrLevel, 'B1');
      expect(fresh.mode, VocabBrowseMode.alphabetical);
    });

    test('a visit keeps its filter while something is watching it', () async {
      final visit = vocabBrowserFilterProvider(VocabBrowserVisit('B2'));
      final subscription = container.listen(visit, (_, _) {});
      addTearDown(subscription.close);

      container.read(visit.notifier).goToPage(2);
      await container.pump();

      expect(container.read(visit).page, 2);
    });

    test('a visit nothing watches any more is released', () async {
      final visit = vocabBrowserFilterProvider(VocabBrowserVisit('B2'));
      final subscription = container.listen(visit, (_, _) {});
      container.read(visit.notifier).goToPage(2);

      subscription.close();
      await container.pump();

      expect(container.exists(visit), isFalse);
    });
  });
}
