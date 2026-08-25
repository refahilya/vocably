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
}
