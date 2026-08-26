import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/dictionary_entry.dart';

void main() {
  group('DictionaryEntry.fromJsonArray', () {
    test('parses phonetic text, audio flag, and meanings by POS', () {
      final entry = DictionaryEntry.fromJsonArray([
        {
          'word': 'hello',
          'phonetic': 'həˈloʊ',
          'phonetics': [
            {'text': 'həˈloʊ', 'audio': ''},
            {'text': 'hɛˈloʊ', 'audio': 'https://example.com/hello-us.mp3'},
          ],
          'meanings': [
            {
              'partOfSpeech': 'exclamation',
              'definitions': [
                {
                  'definition': 'Used as a greeting.',
                  'example': 'hello there, Katie!',
                },
              ],
            },
          ],
        },
      ], word: 'hello');

      expect(entry.word, 'hello');
      expect(entry.phoneticText, 'həˈloʊ');
      expect(entry.hasAudio, isTrue);
      expect(entry.meaningsByPos.keys, contains('exclamation'));
      expect(
        entry.meaningsByPos['exclamation']!.single.definition,
        'Used as a greeting.',
      );
      expect(
        entry.meaningsByPos['exclamation']!.single.example,
        'hello there, Katie!',
      );
    });

    test('merges meanings for the same POS across multiple entries', () {
      final entry = DictionaryEntry.fromJsonArray([
        {
          'meanings': [
            {
              'partOfSpeech': 'noun',
              'definitions': [
                {'definition': 'First noun sense.'},
              ],
            },
          ],
        },
        {
          'meanings': [
            {
              'partOfSpeech': 'noun',
              'definitions': [
                {'definition': 'Second noun sense.'},
              ],
            },
          ],
        },
      ], word: 'bank');

      expect(entry.meaningsByPos['noun'], hasLength(2));
    });

    test('falls back to phonetics[].text when top-level phonetic is absent', () {
      final entry = DictionaryEntry.fromJsonArray([
        {
          'phonetics': [
            {'text': '/fəˈnɛtɪk/'},
          ],
        },
      ], word: 'word');

      expect(entry.phoneticText, '/fəˈnɛtɪk/');
    });

    test('hasAudio is false when no phonetics carry a non-empty audio URL', () {
      final entry = DictionaryEntry.fromJsonArray([
        {
          'phonetics': [
            {'text': 'x', 'audio': ''},
          ],
        },
      ], word: 'word');

      expect(entry.hasAudio, isFalse);
    });

    test('skips a definition entry with no "definition" string', () {
      final entry = DictionaryEntry.fromJsonArray([
        {
          'meanings': [
            {
              'partOfSpeech': 'verb',
              'definitions': [
                {'example': 'no definition field here'},
              ],
            },
          ],
        },
      ], word: 'word');

      expect(entry.meaningsByPos.containsKey('verb'), isFalse);
    });

    test('skips a meaning entry with no partOfSpeech', () {
      final entry = DictionaryEntry.fromJsonArray([
        {
          'meanings': [
            {
              'definitions': [
                {'definition': 'orphaned definition'},
              ],
            },
          ],
        },
      ], word: 'word');

      expect(entry.meaningsByPos, isEmpty);
    });

    test('tolerates malformed entries (non-map items, missing lists)', () {
      final entry = DictionaryEntry.fromJsonArray([
        'not a map',
        {'phonetics': 'not a list'},
        {'meanings': 'not a list'},
        <String, dynamic>{},
      ], word: 'word');

      expect(entry.word, 'word');
      expect(entry.phoneticText, isNull);
      expect(entry.hasAudio, isFalse);
      expect(entry.meaningsByPos, isEmpty);
    });

    test('empty input array produces an entry with no data', () {
      final entry = DictionaryEntry.fromJsonArray([], word: 'word');

      expect(entry.phoneticText, isNull);
      expect(entry.hasAudio, isFalse);
      expect(entry.meaningsByPos, isEmpty);
    });
  });

  group('DictionaryEntry.definitionsForPos', () {
    test('finds an exact POS match directly, no alias needed', () {
      final entry = DictionaryEntry.fromJsonArray([
        {
          'meanings': [
            {
              'partOfSpeech': 'noun',
              'definitions': [
                {'definition': 'a round fruit'},
              ],
            },
          ],
        },
      ], word: 'apple');

      expect(entry.definitionsForPos('noun')!.single.definition, 'a round fruit');
    });

    test(
      'regression: "modal" (Vocably/Oxford tag) finds DictionaryAPI\'s '
      '"verb" meanings — confirmed against the real API that words like '
      '"can"/"must" are tagged "verb", never "modal", so an exact-match '
      'lookup used to silently show "not available" even though the '
      'API actually had the definition',
      () {
        final entry = DictionaryEntry.fromJsonArray([
          {
            'meanings': [
              {
                'partOfSpeech': 'verb',
                'definitions': [
                  {'definition': 'used to express ability'},
                ],
              },
            ],
          },
        ], word: 'can');

        // Vocably's own data tags "can" as "modal" — DictionaryAPI never
        // returns that key, only "verb".
        expect(entry.meaningsByPos.containsKey('modal'), isFalse);
        expect(
          entry.definitionsForPos('modal')!.single.definition,
          'used to express ability',
        );
      },
    );

    test('"number" (Vocably) finds DictionaryAPI\'s "numeral"', () {
      final entry = DictionaryEntry.fromJsonArray([
        {
          'meanings': [
            {
              'partOfSpeech': 'numeral',
              'definitions': [
                {'definition': 'the number 1'},
              ],
            },
          ],
        },
      ], word: 'one');

      expect(entry.definitionsForPos('number')!.single.definition, 'the number 1');
    });

    test('"exclamation" (Vocably) finds DictionaryAPI\'s "interjection"', () {
      final entry = DictionaryEntry.fromJsonArray([
        {
          'meanings': [
            {
              'partOfSpeech': 'interjection',
              'definitions': [
                {'definition': 'used to express surprise'},
              ],
            },
          ],
        },
      ], word: 'oh');

      expect(
        entry.definitionsForPos('exclamation')!.single.definition,
        'used to express surprise',
      );
    });

    test(
      '"determiner" (Vocably) tries "pronoun" then "adjective", in order',
      () {
        final pronounOnly = DictionaryEntry.fromJsonArray([
          {
            'meanings': [
              {
                'partOfSpeech': 'pronoun',
                'definitions': [
                  {'definition': 'used to indicate something nearby'},
                ],
              },
            ],
          },
        ], word: 'this');
        expect(pronounOnly.definitionsForPos('determiner'), isNotNull);

        final adjectiveOnly = DictionaryEntry.fromJsonArray([
          {
            'meanings': [
              {
                'partOfSpeech': 'adjective',
                'definitions': [
                  {'definition': 'every one of two or more'},
                ],
              },
            ],
          },
        ], word: 'every');
        expect(adjectiveOnly.definitionsForPos('determiner'), isNotNull);
      },
    );

    test('returns null when neither the exact tag nor any alias matches anything', () {
      final entry = DictionaryEntry.fromJsonArray([
        {
          'meanings': [
            {
              'partOfSpeech': 'adverb',
              'definitions': [
                {'definition': 'unrelated'},
              ],
            },
          ],
        },
      ], word: 'the');

      // "article" has no known alias — genuinely unavailable, not a
      // mismatch this method should paper over.
      expect(entry.definitionsForPos('article'), isNull);
    });

    test('never returns an empty-but-non-null list from an alias', () {
      final entry = DictionaryEntry.fromJsonArray([], word: 'word');
      expect(entry.definitionsForPos('modal'), isNull);
    });
  });
}
