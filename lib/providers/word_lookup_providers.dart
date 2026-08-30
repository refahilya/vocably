import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/vocab_bundle_entry.dart';
import '../utils/cefr_levels.dart';
import 'vocab_bundle_providers.dart';

part 'word_lookup_providers.g.dart';

/// Resolves [wordId] (already `normalizeWord()`-ed) to its full
/// [VocabBundleEntry] by checking each of [kCefrLevels] in turn — the
/// same "no single `cefrLevel` to scope to" problem
/// `history_providers.dart`'s `historyWordEntriesProvider` already solved
/// for Riwayat's "Per Kata" tab, factored out here so Fase 1's
/// tap-a-target-word-to-open-its-dictionary-entry
/// (`SPEC.md` §5.1) can reuse the exact same lookup instead of
/// re-implementing it. Reuses [vocabLevelProvider]'s cache, so a level
/// already loaded elsewhere costs nothing extra here.
@riverpod
Future<VocabBundleEntry?> resolveWordAcrossLevels(Ref ref, String wordId) async {
  for (final level in kCefrLevels) {
    final entries = await ref.watch(vocabLevelProvider(level).future);
    for (final entry in entries) {
      if (entry.word == wordId) return entry;
    }
  }
  return null;
}
