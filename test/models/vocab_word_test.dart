import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/vocab_word.dart';

void main() {
  group('VocabMeaning', () {
    test('fromMap/toMap round-trip preserves pos and translationId', () {
      final meaning = VocabMeaning.fromMap({
        'pos': 'noun',
        'translationId': 'oleh-oleh',
      });

      expect(meaning.pos, 'noun');
      expect(meaning.translationId, 'oleh-oleh');
      expect(meaning.toMap(), {'pos': 'noun', 'translationId': 'oleh-oleh'});
    });

    test('translationId can be null (not yet generated)', () {
      final meaning = VocabMeaning.fromMap({'pos': 'verb', 'translationId': null});

      expect(meaning.translationId, isNull);
      expect(meaning.toMap()['translationId'], isNull);
    });
  });

  group('VocabWord', () {
    final createdAt = DateTime(2026, 1, 1, 10, 0);
    final updatedAt = DateTime(2026, 1, 2, 11, 30);

    Map<String, dynamic> firestoreData({List<Map<String, dynamic>>? meanings}) {
      return {
        'word': 'souvenir',
        'meanings': meanings ??
            [
              {'pos': 'noun', 'translationId': 'oleh-oleh'},
              {'pos': 'verb', 'translationId': 'mengenang'},
            ],
        // Present in real documents, but deliberately ignored on read —
        // see the dedicated test below.
        'posList': ['noun', 'verb'],
        'cefrLevel': 'B1',
        'topics': ['Perjalanan', 'Belanja'],
        'source': 'oxford3000',
        'addedByTeacherId': null,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
    }

    test('fromFirestore parses every documented field', () {
      final word = VocabWord.fromFirestore(firestoreData());

      expect(word.word, 'souvenir');
      expect(word.meanings, hasLength(2));
      expect(word.cefrLevel, 'B1');
      expect(word.topics, ['Perjalanan', 'Belanja']);
      expect(word.source, 'oxford3000');
      expect(word.addedByTeacherId, isNull);
      expect(word.createdAt, createdAt);
      expect(word.updatedAt, updatedAt);
    });

    test('supports multiple meanings with independent pos and translationId', () {
      final word = VocabWord.fromFirestore(firestoreData());

      expect(word.meanings[0].pos, 'noun');
      expect(word.meanings[0].translationId, 'oleh-oleh');
      expect(word.meanings[1].pos, 'verb');
      expect(word.meanings[1].translationId, 'mengenang');
    });

    test('meanings[0] is exposed as primaryMeaning', () {
      final word = VocabWord.fromFirestore(firestoreData());

      expect(identical(word.primaryMeaning, word.meanings.first), isTrue);
      expect(word.primaryMeaning.pos, 'noun');
    });

    test('posList is derived fresh from meanings, not trusted from source data', () {
      // Deliberately inconsistent stored posList vs. meanings, to prove
      // the getter recomputes rather than passing through whatever the
      // source map happened to contain.
      final data = firestoreData()..['posList'] = ['this-should-be-ignored'];

      final word = VocabWord.fromFirestore(data);

      expect(word.posList, ['noun', 'verb']);
    });

    test('supports multiple topics', () {
      final word = VocabWord.fromFirestore(firestoreData());

      expect(word.topics, containsAll(['Perjalanan', 'Belanja']));
      expect(word.topics, hasLength(2));
    });

    test('addedByTeacherId is populated when source is guru', () {
      final data = firestoreData()
        ..['source'] = 'guru'
        ..['addedByTeacherId'] = 'teacher-uid-1';

      final word = VocabWord.fromFirestore(data);

      expect(word.source, 'guru');
      expect(word.addedByTeacherId, 'teacher-uid-1');
    });

    test('a meaning with a null translationId parses without error', () {
      final data = firestoreData(
        meanings: [
          {'pos': 'noun', 'translationId': null},
        ],
      );

      final word = VocabWord.fromFirestore(data);

      expect(word.meanings, hasLength(1));
      expect(word.meanings.single.translationId, isNull);
    });

    test('toMap -> fromFirestore round-trips to an equivalent VocabWord', () {
      final original = VocabWord.fromFirestore(firestoreData());

      final roundTripped = VocabWord.fromFirestore(original.toMap());

      expect(roundTripped.word, original.word);
      expect(roundTripped.cefrLevel, original.cefrLevel);
      expect(roundTripped.topics, original.topics);
      expect(roundTripped.source, original.source);
      expect(roundTripped.addedByTeacherId, original.addedByTeacherId);
      expect(roundTripped.createdAt, original.createdAt);
      expect(roundTripped.updatedAt, original.updatedAt);
      expect(roundTripped.posList, original.posList);
      expect(roundTripped.meanings, hasLength(original.meanings.length));
      for (var i = 0; i < original.meanings.length; i++) {
        expect(roundTripped.meanings[i].pos, original.meanings[i].pos);
        expect(
          roundTripped.meanings[i].translationId,
          original.meanings[i].translationId,
        );
      }
    });

    test('requires at least one meaning', () {
      expect(
        () => VocabWord(
          word: 'x',
          meanings: const [],
          cefrLevel: 'A1',
          topics: const [],
          source: 'oxford3000',
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
