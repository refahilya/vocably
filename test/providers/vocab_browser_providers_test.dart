import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/providers/vocab_browser_providers.dart';
import 'package:vocably/utils/vocab_browse_filter.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  VocabBrowserFilter notifier() =>
      container.read(vocabBrowserFilterProvider.notifier);

  group('VocabBrowserFilter — page reset (Milestone 4 pagination)', () {
    test('starts at page 0', () {
      expect(container.read(vocabBrowserFilterProvider).page, 0);
    });

    test('goToPage moves to the requested page', () {
      notifier().goToPage(3);
      expect(container.read(vocabBrowserFilterProvider).page, 3);
    });

    test('selectLevel resets page to 0', () {
      notifier().goToPage(3);
      notifier().selectLevel('B1');
      expect(container.read(vocabBrowserFilterProvider).page, 0);
      expect(container.read(vocabBrowserFilterProvider).cefrLevel, 'B1');
    });

    test('selectMode resets page to 0', () {
      notifier().goToPage(2);
      notifier().selectMode(VocabBrowseMode.topic);
      expect(container.read(vocabBrowserFilterProvider).page, 0);
      expect(container.read(vocabBrowserFilterProvider).mode, VocabBrowseMode.topic);
    });

    test('selectTopic resets page to 0', () {
      notifier().goToPage(2);
      notifier().selectTopic('Perjalanan');
      expect(container.read(vocabBrowserFilterProvider).page, 0);
      expect(container.read(vocabBrowserFilterProvider).selectedTopic, 'Perjalanan');
    });

    test('selectPos resets page to 0', () {
      notifier().goToPage(2);
      notifier().selectPos('verb');
      expect(container.read(vocabBrowserFilterProvider).page, 0);
      expect(container.read(vocabBrowserFilterProvider).selectedPos, 'verb');
    });

    test('clearing topic (selectTopic(null)) also resets page to 0', () {
      notifier().selectTopic('Perjalanan');
      notifier().goToPage(2);
      notifier().selectTopic(null);
      expect(container.read(vocabBrowserFilterProvider).page, 0);
      expect(container.read(vocabBrowserFilterProvider).selectedTopic, isNull);
    });

    test('goToPage does not disturb level/mode/topic/pos selection', () {
      notifier().selectLevel('B2');
      notifier().selectMode(VocabBrowseMode.pos);
      notifier().selectPos('adjective');
      notifier().goToPage(4);

      final state = container.read(vocabBrowserFilterProvider);
      expect(state.cefrLevel, 'B2');
      expect(state.mode, VocabBrowseMode.pos);
      expect(state.selectedPos, 'adjective');
      expect(state.page, 4);
    });
  });
}
