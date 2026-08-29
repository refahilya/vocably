import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/learning_progress.dart';
import '../models/learning_session.dart';
import '../models/vocab_bundle_entry.dart';
import '../services/learning_progress_service.dart';
import '../services/learning_session_service.dart';
import '../utils/cefr_levels.dart';
import 'vocab_bundle_providers.dart';

part 'history_providers.g.dart';

@riverpod
LearningProgressService learningProgressService(Ref ref) => LearningProgressService();

@riverpod
LearningSessionService learningSessionService(Ref ref) => LearningSessionService();

/// Every `learningProgress` row for [studentId], unsorted (see
/// [LearningProgressService]'s doc comment on why sorting/filtering is
/// left to callers). Empty until Milestone 7 starts writing this
/// collection.
@riverpod
Future<List<LearningProgress>> learningProgressList(Ref ref, String studentId) {
  return ref.watch(learningProgressServiceProvider).fetchForStudent(studentId);
}

/// Every `learningSessions` row for [studentId], sorted by `startedAt`
/// **descending** — most recent session first, matching Riwayat "Per
/// Sesi"'s expected order. Empty until Milestone 7 starts writing this
/// collection.
@riverpod
Future<List<LearningSession>> learningSessionList(Ref ref, String studentId) async {
  final sessions = await ref.watch(learningSessionServiceProvider).fetchForStudent(studentId);
  final sorted = [...sessions]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return sorted;
}

/// One "Per Kata" row: a [LearningProgress] paired with its resolved
/// [VocabBundleEntry] (word text + primary translation), if still
/// resolvable.
class HistoryWordEntry {
  const HistoryWordEntry({required this.progress, required this.entry});

  final LearningProgress progress;

  /// `null` if [progress.wordId] doesn't match any word in any CEFR
  /// bundle — handled as a degraded-but-not-broken row by the UI (shows
  /// the raw wordId), not filtered out, since the progress record is
  /// still real data.
  final VocabBundleEntry? entry;
}

/// Resolves every "Per Kata" row for [studentId].
///
/// Unlike [targetWordEntriesProvider] (Dashboard), a [LearningProgress]
/// row carries no `cefrLevel` of its own — a student's learned words can
/// span any level. Resolution therefore checks each of [kCefrLevels] in
/// turn until a match is found, reusing [vocabLevelProvider]'s cache (a
/// level already loaded for browsing costs nothing extra here). This is
/// at most 6 cached lookups per word, and — since nothing writes
/// `learningProgress` before Milestone 7 — resolves against an empty list
/// in every real run of this milestone.
@riverpod
Future<List<HistoryWordEntry>> historyWordEntries(Ref ref, String studentId) async {
  final progressList = await ref.watch(learningProgressListProvider(studentId).future);
  if (progressList.isEmpty) return const [];

  final results = <HistoryWordEntry>[];
  for (final progress in progressList) {
    VocabBundleEntry? found;
    for (final level in kCefrLevels) {
      final levelEntries = await ref.watch(vocabLevelProvider(level).future);
      for (final entry in levelEntries) {
        if (entry.word == progress.wordId) {
          found = entry;
          break;
        }
      }
      if (found != null) break;
    }
    results.add(HistoryWordEntry(progress: progress, entry: found));
  }
  return results;
}

/// "Per Kata" tab's mastery filter (`SPEC.md` §3.6: "Bisa difilter/di-sort
/// berdasarkan label tersebut") — screen-local UI state, same
/// `@riverpod class` pattern as `VocabBrowserFilter`.
enum HistoryMasteryFilter { all, mastered, difficult }

@riverpod
class HistoryFilter extends _$HistoryFilter {
  @override
  HistoryMasteryFilter build() => HistoryMasteryFilter.all;

  void select(HistoryMasteryFilter filter) => state = filter;
}

/// Applies [HistoryFilter] to a resolved "Per Kata" list — pure, no
/// Riverpod dependency, mirrors `applyVocabBrowseFilter`'s "filter is a
/// plain function over already-fetched data" shape.
List<HistoryWordEntry> applyHistoryFilter(
  List<HistoryWordEntry> entries,
  HistoryMasteryFilter filter,
) {
  return switch (filter) {
    HistoryMasteryFilter.all => entries,
    HistoryMasteryFilter.mastered => [
        for (final e in entries)
          if (e.progress.masteryStatus == MasteryStatus.mastered) e,
      ],
    HistoryMasteryFilter.difficult => [
        for (final e in entries)
          if (e.progress.masteryStatus == MasteryStatus.difficult) e,
      ],
  };
}
