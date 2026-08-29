import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/target_word_set.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/dashboard_providers.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/services/target_word_set_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';

class _FakeTargetWordSetService extends TargetWordSetService {
  List<TargetWordSet> sets = [];

  @override
  Future<List<TargetWordSet>> fetchActiveForStudent(String studentId) async => sets;
}

/// Serves canned per-level bundles instead of real asset/Firestore I/O —
/// same role as `test/services/vocab_bundle_service_test.dart`'s stub
/// subclasses, reused here because [targetWordEntriesProvider] resolves
/// through [vocabLevelProvider], which calls
/// `VocabBundleService.loadLevelWithDelta`.
class _FakeVocabBundleService extends VocabBundleService {
  Map<String, List<VocabBundleEntry>> byLevel = {};

  @override
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async {
    return byLevel[cefrLevel] ?? const [];
  }
}

VocabBundleEntry _entry(String word, {String cefrLevel = 'A1'}) {
  return VocabBundleEntry(
    word: word,
    meanings: const [VocabMeaning(pos: 'verb', translation: 'terjemahan')],
    cefrLevel: cefrLevel,
    topics: const [],
  );
}

TargetWordSet _set({
  required String id,
  required List<String> wordIds,
  required String cefrLevel,
}) {
  return TargetWordSet(
    id: id,
    teacherId: 'teacher-1',
    wordIds: wordIds,
    cefrLevel: cefrLevel,
    startAt: DateTime(2020, 1, 1),
    endAt: DateTime(2099, 12, 31),
    targetStudentIds: const ['__all__'],
    createdAt: DateTime(2020, 1, 1),
  );
}

void main() {
  group('targetWordEntriesProvider', () {
    test('resolves wordIds against the active set\'s own cefrLevel bundle', () async {
      final targetWordSetService = _FakeTargetWordSetService()
        ..sets = [_set(id: 'set-1', wordIds: ['run', 'souvenir'], cefrLevel: 'A1')];
      final bundleService = _FakeVocabBundleService()
        ..byLevel = {
          'A1': [_entry('run'), _entry('souvenir'), _entry('other')],
        };

      final container = ProviderContainer(
        overrides: [
          targetWordSetServiceProvider.overrideWithValue(targetWordSetService),
          vocabBundleServiceProvider.overrideWithValue(bundleService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(targetWordEntriesProvider('student-1').future);

      expect(result.map((e) => e.word), containsAll(['run', 'souvenir']));
      expect(result, hasLength(2));
    });

    test('no active sets resolves to an empty list', () async {
      final container = ProviderContainer(
        overrides: [
          targetWordSetServiceProvider.overrideWithValue(_FakeTargetWordSetService()),
          vocabBundleServiceProvider.overrideWithValue(_FakeVocabBundleService()),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(targetWordEntriesProvider('student-1').future);
      expect(result, isEmpty);
    });

    test('a wordId with no bundle match is silently skipped, not a broken entry', () async {
      final targetWordSetService = _FakeTargetWordSetService()
        ..sets = [_set(id: 'set-1', wordIds: ['run', 'ghost-word'], cefrLevel: 'A1')];
      final bundleService = _FakeVocabBundleService()
        ..byLevel = {
          'A1': [_entry('run')],
        };

      final container = ProviderContainer(
        overrides: [
          targetWordSetServiceProvider.overrideWithValue(targetWordSetService),
          vocabBundleServiceProvider.overrideWithValue(bundleService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(targetWordEntriesProvider('student-1').future);
      expect(result.map((e) => e.word), ['run']);
    });

    test('the same word targeted by two active sets is de-duplicated', () async {
      final targetWordSetService = _FakeTargetWordSetService()
        ..sets = [
          _set(id: 'set-1', wordIds: ['run'], cefrLevel: 'A1'),
          _set(id: 'set-2', wordIds: ['run'], cefrLevel: 'A1'),
        ];
      final bundleService = _FakeVocabBundleService()
        ..byLevel = {
          'A1': [_entry('run')],
        };

      final container = ProviderContainer(
        overrides: [
          targetWordSetServiceProvider.overrideWithValue(targetWordSetService),
          vocabBundleServiceProvider.overrideWithValue(bundleService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(targetWordEntriesProvider('student-1').future);
      expect(result, hasLength(1));
    });
  });
}
