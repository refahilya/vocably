import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/providers/word_lookup_providers.dart';
import 'package:vocably/services/vocab_bundle_service.dart';

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

VocabBundleEntry _entry(String word, String level) {
  return VocabBundleEntry.fromMap({
    'word': word,
    'meanings': [
      {'pos': 'verb', 'translation': 'terjemahan'},
    ],
    'posList': [],
    'cefrLevel': level,
    'topics': [],
  });
}

void main() {
  test('finds a word by checking each CEFR level in turn — used by Fase 1\'s tap-to-dictionary', () async {
    final container = ProviderContainer(
      overrides: [
        vocabBundleServiceProvider.overrideWithValue(
          _FakeVocabBundleService()
            ..byLevel = {
              'B1': [_entry('souvenir', 'B1')],
            },
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(resolveWordAcrossLevelsProvider('souvenir').future);

    expect(result?.word, 'souvenir');
    expect(result?.cefrLevel, 'B1');
  });

  test('a word that exists in no level resolves to null, not an error', () async {
    final container = ProviderContainer(
      overrides: [vocabBundleServiceProvider.overrideWithValue(_FakeVocabBundleService())],
    );
    addTearDown(container.dispose);

    final result = await container.read(resolveWordAcrossLevelsProvider('doesnotexist').future);

    expect(result, isNull);
  });
}
