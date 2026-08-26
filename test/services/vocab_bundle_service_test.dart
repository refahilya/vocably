import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/services/vocab_bundle_service.dart';

/// In-memory [AssetBundle] fake — lets [VocabBundleService.loadLevel] be
/// tested without any real file on disk or a Flutter binding. Only
/// [load] is genuinely abstract on [AssetBundle]; everything else
/// (`loadString`, etc.) has a default implementation that calls it.
class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final content = _assets[key];
    if (content == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    final bytes = utf8.encode(content);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

/// Test double for the `loadLevelWithDelta` resilience tests below —
/// overrides just [fetchDelta] (the Firestore-dependent half) so its
/// failure/success can be controlled directly, without needing a real
/// or fake Firestore instance for what's otherwise a pure
/// bundle-vs-delta merge behavior.
class _ThrowingDeltaVocabBundleService extends VocabBundleService {
  _ThrowingDeltaVocabBundleService({required super.assetBundle});

  @override
  Future<List<VocabBundleEntry>> fetchDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) {
    throw Exception('simulated Firestore failure (e.g. missing index)');
  }
}

class _StubDeltaVocabBundleService extends VocabBundleService {
  _StubDeltaVocabBundleService({
    required super.assetBundle,
    required this.stubDelta,
  });

  final List<VocabBundleEntry> stubDelta;

  @override
  Future<List<VocabBundleEntry>> fetchDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async => stubDelta;
}

Map<String, dynamic> bundleEntryJson({
  required String word,
  String cefrLevel = 'A1',
  List<Map<String, dynamic>>? meanings,
  List<String>? topics,
}) {
  return {
    'word': word,
    'meanings': meanings ?? [
      {'pos': 'noun', 'translation': 'terjemahan'},
    ],
    'posList': ['noun'],
    'cefrLevel': cefrLevel,
    'topics': topics ?? ['Umum'],
  };
}

void main() {
  group('VocabBundleService.loadLevel', () {
    test('parses a valid bundle file into VocabBundleEntry list', () async {
      final bundle = _FakeAssetBundle({
        'assets/vocab/vocab_a1.json': jsonEncode([
          bundleEntryJson(word: 'apple'),
          bundleEntryJson(word: 'run'),
        ]),
      });
      final service = VocabBundleService(assetBundle: bundle);

      final entries = await service.loadLevel('A1');

      expect(entries, hasLength(2));
      expect(entries.map((e) => e.word), ['apple', 'run']);
    });

    test('is case-insensitive on cefrLevel when building the asset key', () async {
      final bundle = _FakeAssetBundle({
        'assets/vocab/vocab_b1.json': jsonEncode([bundleEntryJson(word: 'souvenir', cefrLevel: 'B1')]),
      });
      final service = VocabBundleService(assetBundle: bundle);

      final entries = await service.loadLevel('B1');

      expect(entries, hasLength(1));
      expect(entries.single.word, 'souvenir');
    });

    test('returns an empty list when the level file does not exist (e.g. C2)', () async {
      final bundle = _FakeAssetBundle({}); // nothing registered at all
      final service = VocabBundleService(assetBundle: bundle);

      final entries = await service.loadLevel('C2');

      expect(entries, isEmpty);
    });

    test('returns an empty list for a genuinely empty bundle array', () async {
      final bundle = _FakeAssetBundle({
        'assets/vocab/vocab_c2.json': jsonEncode(<Map<String, dynamic>>[]),
      });
      final service = VocabBundleService(assetBundle: bundle);

      final entries = await service.loadLevel('C2');

      expect(entries, isEmpty);
    });

    test('malformed entries inside an otherwise-valid file are skipped, not fatal', () async {
      final bundle = _FakeAssetBundle({
        'assets/vocab/vocab_a1.json': jsonEncode([
          bundleEntryJson(word: 'apple'),
          {'word': 'broken'}, // missing meanings/cefrLevel/topics
          bundleEntryJson(word: 'run'),
        ]),
      });
      final service = VocabBundleService(assetBundle: bundle);

      final entries = await service.loadLevel('A1');

      expect(entries, hasLength(2));
      expect(entries.map((e) => e.word), ['apple', 'run']);
    });
  });

  group('VocabBundleService.loadLevelWithDelta', () {
    test(
      'degrades gracefully to bundle-only data when fetchDelta throws '
      '(regression: the real Firestore project was missing the '
      'cefrLevel+updatedAt composite index the delta query needs, which '
      'used to fail the entire level even though the bundle loaded fine)',
      () async {
        final bundle = _FakeAssetBundle({
          'assets/vocab/vocab_a1.json': jsonEncode([
            bundleEntryJson(word: 'apple'),
            bundleEntryJson(word: 'run'),
          ]),
        });
        final service = _ThrowingDeltaVocabBundleService(assetBundle: bundle);

        final result = await service.loadLevelWithDelta(
          cefrLevel: 'A1',
          bundleGeneratedAt: DateTime(2020),
        );

        expect(result.map((e) => e.word), containsAll(['apple', 'run']));
        expect(result, hasLength(2));
      },
    );

    test('still merges in the delta normally when fetchDelta succeeds', () async {
      final bundle = _FakeAssetBundle({
        'assets/vocab/vocab_a1.json': jsonEncode([bundleEntryJson(word: 'apple')]),
      });
      final service = _StubDeltaVocabBundleService(
        assetBundle: bundle,
        stubDelta: [
          VocabBundleEntry.fromMap(bundleEntryJson(word: 'banana')),
        ],
      );

      final result = await service.loadLevelWithDelta(
        cefrLevel: 'A1',
        bundleGeneratedAt: DateTime(2020),
      );

      expect(result.map((e) => e.word), containsAll(['apple', 'banana']));
    });
  });

  group('VocabBundleEntry.fromVocabWord', () {
    test('narrows a full VocabWord down to the bundle-shape fields', () {
      final word = VocabWord.fromFirestore({
        'word': 'souvenir',
        'meanings': [
          {'pos': 'noun', 'translation': 'oleh-oleh'},
        ],
        'cefrLevel': 'B1',
        'topics': ['Perjalanan'],
        'source': 'guru',
        'addedByTeacherId': 'teacher-1',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final entry = VocabBundleEntry.fromVocabWord(word);

      expect(entry.word, 'souvenir');
      expect(entry.cefrLevel, 'B1');
      expect(entry.topics, ['Perjalanan']);
      expect(entry.meanings.single.pos, 'noun');
      expect(entry.meanings.single.translation, 'oleh-oleh');
    });
  });

  group('mergeBundleWithDelta', () {
    VocabBundleEntry entry(String word, {String cefrLevel = 'A1', String? translation}) {
      return VocabBundleEntry.fromMap(
        bundleEntryJson(
          word: word,
          cefrLevel: cefrLevel,
          meanings: [
            {'pos': 'noun', 'translation': translation ?? 'original'},
          ],
        ),
      );
    }

    test('a delta word not present in the bundle is added', () {
      final bundle = [entry('apple')];
      final delta = [entry('banana')];

      final result = mergeBundleWithDelta(bundle, delta);

      expect(result.map((e) => e.word), containsAll(['apple', 'banana']));
      expect(result, hasLength(2));
    });

    test('a word present in both is replaced by the delta version, not duplicated', () {
      final bundle = [entry('apple', translation: 'stale')];
      final delta = [entry('apple', translation: 'fresh')];

      final result = mergeBundleWithDelta(bundle, delta);

      expect(result, hasLength(1));
      expect(result.single.word, 'apple');
      expect(result.single.meanings.single.translation, 'fresh');
    });

    test('matching is normalized — differing case still counts as the same word', () {
      final bundle = [entry('Apple', translation: 'stale')];
      final delta = [entry('apple', translation: 'fresh')];

      final result = mergeBundleWithDelta(bundle, delta);

      expect(result, hasLength(1));
      expect(result.single.meanings.single.translation, 'fresh');
    });

    test('an empty delta leaves the bundle unchanged', () {
      final bundle = [entry('apple'), entry('run')];

      final result = mergeBundleWithDelta(bundle, const []);

      expect(result.map((e) => e.word), ['apple', 'run']);
    });

    test('an empty bundle with a non-empty delta returns just the delta', () {
      final delta = [entry('apple'), entry('run')];

      final result = mergeBundleWithDelta(const [], delta);

      expect(result.map((e) => e.word), ['apple', 'run']);
    });

    test('both empty returns an empty list', () {
      expect(mergeBundleWithDelta(const [], const []), isEmpty);
    });
  });
}
