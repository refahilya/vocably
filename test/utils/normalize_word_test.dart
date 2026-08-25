import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/utils/normalize_word.dart';

void main() {
  group('normalizeWord', () {
    test('trims leading and trailing whitespace', () {
      expect(normalizeWord('  apple  '), 'apple');
    });

    test('lowercases the word', () {
      expect(normalizeWord('Apple'), 'apple');
      expect(normalizeWord('SOUVENIR'), 'souvenir');
    });

    test('trims and lowercases together', () {
      expect(normalizeWord('  Apple  '), 'apple');
    });

    test('preserves internal spaces for multi-word phrases', () {
      expect(normalizeWord('Wake Up'), 'wake up');
      expect(normalizeWord('  Look After  '), 'look after');
    });

    test('does not collapse repeated internal whitespace (undocumented behavior, not invented)', () {
      expect(normalizeWord('look   after'), 'look   after');
    });

    test('preserves internal punctuation such as commas (e.g. "a, an")', () {
      expect(normalizeWord('A, An'), 'a, an');
      expect(normalizeWord('  A, An  '), 'a, an');
    });

    test('already-normalized input is returned unchanged', () {
      expect(normalizeWord('apple'), 'apple');
      expect(normalizeWord('wake up'), 'wake up');
    });

    test('handles an empty string', () {
      expect(normalizeWord(''), '');
    });

    test('handles a whitespace-only string', () {
      expect(normalizeWord('   '), '');
    });

    test('is idempotent — applying it twice equals applying it once', () {
      const inputs = ['  Apple  ', 'Wake Up', 'A, An', '', '   ', 'already-normalized'];
      for (final input in inputs) {
        final once = normalizeWord(input);
        final twice = normalizeWord(once);
        expect(twice, once, reason: 'normalizeWord("$input") was not idempotent');
      }
    });
  });
}
