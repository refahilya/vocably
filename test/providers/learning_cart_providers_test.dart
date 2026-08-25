import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/providers/learning_cart_providers.dart';

void main() {
  VocabBundleEntry entry(String word) {
    return VocabBundleEntry.fromMap({
      'word': word,
      'meanings': [
        {'pos': 'noun', 'translationId': 'terjemahan'},
      ],
      'posList': [],
      'cefrLevel': 'A1',
      'topics': ['Umum'],
    });
  }

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('LearningCart', () {
    test('starts empty', () {
      expect(container.read(learningCartProvider), isEmpty);
    });

    test('add() adds a word to the cart', () {
      container.read(learningCartProvider.notifier).add(entry('apple'));

      final cart = container.read(learningCartProvider);
      expect(cart, hasLength(1));
      expect(cart.values.single.word, 'apple');
    });

    test('add() is a no-op for a word already in the cart (no duplicates)', () {
      final notifier = container.read(learningCartProvider.notifier);

      notifier.add(entry('apple'));
      notifier.add(entry('apple'));

      expect(container.read(learningCartProvider), hasLength(1));
    });

    test('duplicate prevention is normalization-sensitive (case/whitespace)', () {
      final notifier = container.read(learningCartProvider.notifier);

      notifier.add(entry('Apple'));
      notifier.add(entry('  apple  '));

      expect(container.read(learningCartProvider), hasLength(1));
    });

    test('adding a second, different word grows the cart', () {
      final notifier = container.read(learningCartProvider.notifier);

      notifier.add(entry('apple'));
      notifier.add(entry('run'));

      expect(container.read(learningCartProvider), hasLength(2));
    });

    test('remove() removes a word from the cart', () {
      final notifier = container.read(learningCartProvider.notifier);
      notifier.add(entry('apple'));
      notifier.add(entry('run'));

      notifier.remove('apple');

      final cart = container.read(learningCartProvider);
      expect(cart, hasLength(1));
      expect(cart.values.single.word, 'run');
    });

    test('remove() for a word not in the cart is a no-op', () {
      final notifier = container.read(learningCartProvider.notifier);
      notifier.add(entry('apple'));

      notifier.remove('not-in-cart');

      expect(container.read(learningCartProvider), hasLength(1));
    });

    test('remove() is normalization-sensitive', () {
      final notifier = container.read(learningCartProvider.notifier);
      notifier.add(entry('Apple'));

      notifier.remove('apple');

      expect(container.read(learningCartProvider), isEmpty);
    });

    test('contains() reflects membership, normalization-sensitive', () {
      final notifier = container.read(learningCartProvider.notifier);
      notifier.add(entry('Apple'));

      expect(notifier.contains('apple'), isTrue);
      expect(notifier.contains('APPLE'), isTrue);
      expect(notifier.contains('  Apple  '), isTrue);
      expect(notifier.contains('run'), isFalse);
    });

    test('contains() on an empty cart is always false', () {
      final notifier = container.read(learningCartProvider.notifier);

      expect(notifier.contains('anything'), isFalse);
    });

    test('toggle() adds when absent and removes when present', () {
      final notifier = container.read(learningCartProvider.notifier);
      final apple = entry('apple');

      notifier.toggle(apple);
      expect(notifier.contains('apple'), isTrue);

      notifier.toggle(apple);
      expect(notifier.contains('apple'), isFalse);
    });

    test('clear() empties the cart', () {
      final notifier = container.read(learningCartProvider.notifier);
      notifier.add(entry('apple'));
      notifier.add(entry('run'));

      notifier.clear();

      expect(container.read(learningCartProvider), isEmpty);
    });
  });
}
