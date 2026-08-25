import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';

void main() {
  Map<String, dynamic> validEntry({
    String word = 'souvenir',
    List<Map<String, dynamic>>? meanings,
    String cefrLevel = 'B1',
    List<String>? topics,
  }) {
    return {
      'word': word,
      'meanings': meanings ??
          [
            {'pos': 'noun', 'translationId': 'oleh-oleh'},
            {'pos': 'verb', 'translationId': 'mengenang'},
          ],
      // Present in real bundle files (DATA_MODEL.md §11.2), deliberately
      // ignored on read — see the dedicated test below.
      'posList': ['noun', 'verb'],
      'cefrLevel': cefrLevel,
      'topics': topics ?? ['Perjalanan', 'Belanja'],
    };
  }

  group('VocabBundleEntry.fromMap', () {
    test('parses a valid single entry', () {
      final entry = VocabBundleEntry.fromMap(validEntry());

      expect(entry.word, 'souvenir');
      expect(entry.cefrLevel, 'B1');
      expect(entry.topics, ['Perjalanan', 'Belanja']);
      expect(entry.meanings, hasLength(2));
    });

    test('supports multiple meanings, reusing VocabMeaning', () {
      final entry = VocabBundleEntry.fromMap(validEntry());

      expect(entry.meanings[0], isA<VocabMeaning>());
      expect(entry.meanings[0].pos, 'noun');
      expect(entry.meanings[0].translationId, 'oleh-oleh');
      expect(entry.meanings[1].pos, 'verb');
      expect(entry.meanings[1].translationId, 'mengenang');
    });

    test('supports multiple topics', () {
      final entry = VocabBundleEntry.fromMap(validEntry());

      expect(entry.topics, containsAll(['Perjalanan', 'Belanja']));
      expect(entry.topics, hasLength(2));
    });

    test('posList is derived fresh from meanings, not trusted from source data', () {
      final data = validEntry()..['posList'] = ['this-should-be-ignored'];

      final entry = VocabBundleEntry.fromMap(data);

      expect(entry.posList, ['noun', 'verb']);
    });

    test('primaryMeaning exposes meanings[0]', () {
      final entry = VocabBundleEntry.fromMap(validEntry());

      expect(identical(entry.primaryMeaning, entry.meanings.first), isTrue);
      expect(entry.primaryMeaning.pos, 'noun');
    });

    test('parsing does not require or depend on any Firestore-only field', () {
      // No source/addedByTeacherId/createdAt/updatedAt anywhere in the
      // input — the real bundle shape (DATA_MODEL.md §11.2) never has
      // them, and parsing must not depend on their presence.
      final data = validEntry();
      expect(data.containsKey('source'), isFalse);
      expect(data.containsKey('addedByTeacherId'), isFalse);
      expect(data.containsKey('createdAt'), isFalse);
      expect(data.containsKey('updatedAt'), isFalse);

      expect(() => VocabBundleEntry.fromMap(data), returnsNormally);
    });

    test('toMap produces exactly the 5 documented bundle fields', () {
      final entry = VocabBundleEntry.fromMap(validEntry());

      final map = entry.toMap();

      expect(
        map.keys,
        containsAll(['word', 'meanings', 'posList', 'cefrLevel', 'topics']),
      );
      expect(map.containsKey('source'), isFalse);
      expect(map.containsKey('addedByTeacherId'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('updatedAt'), isFalse);
    });

    test('throws for a missing "word"', () {
      final data = validEntry()..remove('word');
      expect(() => VocabBundleEntry.fromMap(data), throwsA(isA<Error>()));
    });

    test('throws for a missing "meanings"', () {
      final data = validEntry()..remove('meanings');
      expect(() => VocabBundleEntry.fromMap(data), throwsA(isA<Error>()));
    });

    test('throws FormatException for an empty "meanings" array', () {
      final data = validEntry(meanings: []);
      expect(() => VocabBundleEntry.fromMap(data), throwsFormatException);
    });

    test('throws for a malformed meaning element (not a map)', () {
      final data = validEntry();
      data['meanings'] = ['not-a-map'];
      expect(() => VocabBundleEntry.fromMap(data), throwsA(isA<Error>()));
    });

    test('throws for a missing "cefrLevel"', () {
      final data = validEntry()..remove('cefrLevel');
      expect(() => VocabBundleEntry.fromMap(data), throwsA(isA<Error>()));
    });

    test('throws for a missing "topics"', () {
      final data = validEntry()..remove('topics');
      expect(() => VocabBundleEntry.fromMap(data), throwsA(isA<Error>()));
    });
  });

  group('VocabBundleEntry.listFromJson', () {
    test('returns an empty list for an empty JSON array', () {
      expect(VocabBundleEntry.listFromJson(const []), isEmpty);
    });

    test('parses multiple valid entries', () {
      final entries = VocabBundleEntry.listFromJson([
        validEntry(word: 'apple', cefrLevel: 'A1', topics: ['Makanan']),
        validEntry(word: 'run', cefrLevel: 'A2', topics: ['Aktivitas']),
      ]);

      expect(entries, hasLength(2));
      expect(entries[0].word, 'apple');
      expect(entries[1].word, 'run');
    });

    test('skips a malformed entry but keeps the valid ones around it', () {
      final entries = VocabBundleEntry.listFromJson([
        validEntry(word: 'apple'),
        {'word': 'broken'}, // missing meanings/cefrLevel/topics
        validEntry(word: 'run'),
      ]);

      expect(entries, hasLength(2));
      expect(entries.map((e) => e.word), ['apple', 'run']);
    });

    test('an entry with an empty meanings array is skipped, not fatal', () {
      final entries = VocabBundleEntry.listFromJson([
        validEntry(word: 'apple'),
        validEntry(word: 'no-meanings', meanings: []),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.word, 'apple');
    });

    test('an entry that is not even a map is skipped, not fatal', () {
      final entries = VocabBundleEntry.listFromJson([
        validEntry(word: 'apple'),
        'not-a-map-at-all',
        42,
        null,
        validEntry(word: 'run'),
      ]);

      expect(entries, hasLength(2));
      expect(entries.map((e) => e.word), ['apple', 'run']);
    });
  });
}
