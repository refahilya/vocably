import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/target_word_set.dart';
import '../models/vocab_bundle_entry.dart';
import '../services/target_word_set_service.dart';
import 'vocab_bundle_providers.dart';

part 'dashboard_providers.g.dart';

@riverpod
TargetWordSetService targetWordSetService(Ref ref) => TargetWordSetService();

/// The `targetWordSets` currently active for [studentId] (`DATA_MODEL.md`
/// §5's query, run as-is — see `TargetWordSetService`). Empty until
/// Milestone 8 builds "Set Target Kata" and a guru actually creates one.
@riverpod
Future<List<TargetWordSet>> activeTargetWordSets(Ref ref, String studentId) {
  return ref.watch(targetWordSetServiceProvider).fetchActiveForStudent(studentId);
}

/// Resolves every currently-active target word (across however many
/// active sets exist) to its full [VocabBundleEntry], for the "Target
/// Kata Hari Ini" card.
///
/// Each [TargetWordSet] is scoped to one `cefrLevel` (`DATA_MODEL.md`
/// §5's own framing — a guru picks words starting from one level), so
/// resolution loads that one level's bundle per set (reusing
/// [vocabLevelProvider]'s cache — repeated levels across multiple active
/// sets don't reload) and matches each `wordId` against it by exact
/// (already-normalized) string equality. A `wordId` that no longer
/// resolves (e.g. a word later removed from the bank — not possible
/// today since `vocabWords` has no delete path, but not assumed away
/// either) is silently skipped rather than shown as a broken entry.
/// Results are de-duplicated by word, since more than one active set
/// could target the same word.
@riverpod
Future<List<VocabBundleEntry>> targetWordEntries(Ref ref, String studentId) async {
  final sets = await ref.watch(activeTargetWordSetsProvider(studentId).future);
  if (sets.isEmpty) return const [];

  final resolved = <String, VocabBundleEntry>{};
  for (final set in sets) {
    final levelEntries = await ref.watch(vocabLevelProvider(set.cefrLevel).future);
    for (final wordId in set.wordIds) {
      if (resolved.containsKey(wordId)) continue;
      for (final entry in levelEntries) {
        if (entry.word == wordId) {
          resolved[wordId] = entry;
          break;
        }
      }
    }
  }

  return resolved.values.toList();
}
