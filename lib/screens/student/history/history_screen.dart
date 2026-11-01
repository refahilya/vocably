import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/learning_session.dart';
import '../../../providers/history_providers.dart';
import '../../../providers/learning_session_controller.dart';
import '../../../theme/theme.dart';
import '../../../utils/normalize_word.dart';
import '../../../utils/session_date_format.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
import '../../../widgets/mastery_badge.dart';
import '../learning_flow/story_reading_screen.dart';
import 'session_detail_screen.dart';

/// Real Riwayat destination (`SPEC.md` §3.6, `DESIGN_REFERENCE.md` §3.3)
/// — replaces `HistoryPlaceholder` (Milestone 6). Two tabs, "Per Kata" and
/// "Per Sesi", reading `learningProgress`/`learningSessions`
/// respectively. **Both collections are empty in every real run of this
/// milestone** — nothing writes to either until Milestone 7's 3-phase
/// flow exists — so both tabs' populated-state UI can only be exercised
/// via tests with fake services (see `test/screens/history_screen_test.dart`)
/// until then; the empty-state UI is what a real signed-in student will
/// actually see.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the auto-dispose difficult-word selection alive for as long as
    // Riwayat is open, so it survives filter/tab switches and the round
    // trip through the learning flow, and is discarded when the student
    // leaves Riwayat. Listening (not watching) avoids rebuilding the tabs
    // on every toggle.
    ref.listen(historyDifficultSelectionProvider(profile.uid), (_, _) {});

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const ColoredBox(
            color: AppColors.surface,
            child: AppContent(
              maxWidth: AppContentWidth.list,
              child: TabBar(
                tabs: [Tab(text: 'Per Kata'), Tab(text: 'Per Sesi')],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PerKataTab(studentId: profile.uid),
                _PerSesiTab(studentId: profile.uid),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(message: 'Gagal memuat riwayat.', onRetry: onRetry);
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text, {this.icon = Icons.history});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppStateMessage(icon: icon, title: text);
  }
}

/// A word in the history: mastery mark, word, translation.
class _WordTile extends StatelessWidget {
  const _WordTile({required this.item});

  final HistoryWordEntry item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: _wordTileDecoration,
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.lg,
            child: MasteryBadge(masteryStatus: item.progress.masteryStatus),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.entry?.word ?? item.progress.wordId,
                  style: AppTextStyles.wordRow,
                ),
                Text(
                  item.entry?.primaryMeaning.translation ?? '—',
                  style: AppTextStyles.bodyMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final _wordTileDecoration = BoxDecoration(
  color: AppColors.surface,
  border: Border.all(color: AppColors.line),
  borderRadius: BorderRadius.circular(AppRadius.medium),
);

/// "Per Kata" tab (`SPEC.md` §3.6): filterable-by-mastery word list. Under
/// the `difficult` filter, rows are selectable and "Pelajari Kembali"
/// starts the 3-phase flow with only the selected words.
class _PerKataTab extends ConsumerWidget {
  const _PerKataTab({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(historyWordEntriesProvider(studentId));
    final filter = ref.watch(historyFilterProvider);

    return entriesAsync.when(
      loading: () => const AppLoading(),
      // Never let this be a silent failure (a real bug: this used to
      // discard `error`/`stackTrace` entirely, so a genuine Firestore
      // failure — a bad document shape, a rules mismatch — was
      // impossible to diagnose from a running app; "Gagal memuat
      // riwayat." was the only trace it ever left, anywhere). The
      // student-facing text stays exactly the same friendly message
      // (`DESIGN_REFERENCE.md` §5.8: never a raw error to the student) —
      // only the developer-facing `debugPrint` (visible in the browser/
      // terminal console, same pattern `VocabBundleService.
      // loadLevelWithDelta` already uses) is new.
      error: (error, stackTrace) {
        debugPrint('historyWordEntriesProvider("$studentId") failed: $error\n$stackTrace');
        return _ErrorRetry(
          onRetry: () => ref.invalidate(historyWordEntriesProvider(studentId)),
        );
      },
      data: (all) {
        final filtered = applyHistoryFilter(all, filter);

        return Column(
          children: [
            AppContent(
              maxWidth: AppContentWidth.list,
              vertical: AppSpacing.md,
              child: SegmentedButton<HistoryMasteryFilter>(
                segments: const [
                  ButtonSegment(value: HistoryMasteryFilter.all, label: Text('Semua')),
                  ButtonSegment(
                    value: HistoryMasteryFilter.mastered,
                    label: Text('Mastered'),
                  ),
                  ButtonSegment(
                    value: HistoryMasteryFilter.difficult,
                    label: Text('Difficult'),
                  ),
                ],
                selected: {filter},
                onSelectionChanged: (selection) =>
                    ref.read(historyFilterProvider.notifier).select(selection.first),
              ),
            ),
            Expanded(
              child: all.isEmpty
                  // DESIGN_REFERENCE.md §5.8: "Riwayat masih kosong".
                  ? const _EmptyMessage('Belum ada kata yang dipelajari')
                  : filtered.isEmpty
                  ? _EmptyMessage(
                      filter == HistoryMasteryFilter.difficult
                          // §5.8: nada positif, ini kabar baik.
                          ? 'Tidak ada kata yang perlu diulang'
                          : 'Tidak ada kata dengan label ini.',
                      icon: filter == HistoryMasteryFilter.difficult
                          ? Icons.check_circle_outline
                          : Icons.filter_alt_outlined,
                    )
                  : filter == HistoryMasteryFilter.difficult
                  ? _DifficultSelectionList(studentId: studentId, entries: filtered)
                  : _PerKataList(entries: filtered),
            ),
          ],
        );
      },
    );
  }
}

/// Semua / Mastered: a plain, read-only word list.
class _PerKataList extends StatelessWidget {
  const _PerKataList({required this.entries});

  final List<HistoryWordEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AppContent(
      maxWidth: AppContentWidth.list,
      child: AppResponsiveList(
        itemCount: entries.length,
        minItemWidth: 300,
        maxColumns: 2,
        gap: AppSpacing.sm,
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        itemBuilder: (context, index) => _WordTile(item: entries[index]),
      ),
    );
  }
}

/// Difficult: selectable rows, a live count, "Pilih Semua" / "Batalkan
/// Pilihan", and "Pelajari Kembali (N kata)" (`SPEC.md` §3.6). This
/// supersedes Milestone 7 Decision 2, under which every difficult word was
/// relearned. Nothing is selected initially, and there's no session-size
/// cap. Unresolved rows (no bundle entry) keep their raw-ID display and
/// stay selectable.
class _DifficultSelectionList extends ConsumerWidget {
  const _DifficultSelectionList({required this.studentId, required this.entries});

  final String studentId;

  /// The current difficult rows (already filtered).
  final List<HistoryWordEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(historyDifficultSelectionProvider(studentId));
    final notifier = ref.read(historyDifficultSelectionProvider(studentId).notifier);
    final effective = effectiveDifficultSelection(selected: selection, entries: entries);
    final eligibleIds = difficultWordIds(entries);
    final count = effective.length;

    return Column(
      children: [
        AppContent(
          maxWidth: AppContentWidth.list,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              Text('$count kata dipilih', style: AppTextStyles.body),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  TextButton(
                    onPressed: count == eligibleIds.length
                        ? null
                        : () => notifier.selectAll(eligibleIds),
                    child: const Text('Pilih Semua'),
                  ),
                  TextButton(
                    onPressed: count == 0 ? null : notifier.clear,
                    child: const Text('Batalkan Pilihan'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AppContent(
            maxWidth: AppContentWidth.list,
            child: AppResponsiveList(
              itemCount: entries.length,
              minItemWidth: 300,
              maxColumns: 2,
              gap: AppSpacing.sm,
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = entries[index];
                final id = normalizeWord(item.progress.wordId);
                return Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: AppColors.line),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CheckboxListTile(
                    value: selection.contains(id),
                    onChanged: (_) => notifier.toggle(id),
                    secondary: MasteryBadge(masteryStatus: item.progress.masteryStatus),
                    title: Text(
                      item.entry?.word ?? item.progress.wordId,
                      style: AppTextStyles.wordRow,
                    ),
                    subtitle: Text(
                      item.entry?.primaryMeaning.translation ?? '—',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        AppBottomBar(
          maxWidth: AppContentWidth.list,
          child: FilledButton(
            onPressed: count == 0 ? null : () => _startRelearn(context, ref),
            child: Text(count == 0 ? 'Pelajari Kembali' : 'Pelajari Kembali ($count kata)'),
          ),
        ),
      ],
    );
  }

  /// Starts the flow with the effective selection, recomputed from the
  /// latest History data so a stale tap can't submit an ineligible word.
  /// When the flow's route is popped (finished, cancelled, or abandoned),
  /// the History data is re-fetched: the flow may have changed mastery or
  /// added a session. The selection provider then prunes words that are no
  /// longer difficult. Starting a flow writes nothing by itself.
  Future<void> _startRelearn(BuildContext context, WidgetRef ref) async {
    final latest = ref.read(historyWordEntriesProvider(studentId)).value ?? entries;
    final wordIds = effectiveDifficultSelection(
      selected: ref.read(historyDifficultSelectionProvider(studentId)),
      entries: latest,
    );
    if (wordIds.isEmpty) return;

    ref
        .read(learningFlowControllerProvider.notifier)
        .startFlow(
          studentId: studentId,
          wordIds: wordIds,
          sourceType: LearningSessionSourceType.pelajariUlangDifficult,
        );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StoryReadingScreen()));

    if (!context.mounted) return;
    ref.invalidate(learningProgressListProvider(studentId));
    ref.invalidate(learningSessionListProvider(studentId));
  }
}

/// "Per Sesi" tab (`SPEC.md` §3.6): one card per `learningSessions`
/// document, most recent first, tap → [SessionDetailScreen]'s read-only
/// story replay.
class _PerSesiTab extends ConsumerWidget {
  const _PerSesiTab({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(learningSessionListProvider(studentId));

    return sessionsAsync.when(
      loading: () => const AppLoading(),
      // See the identical comment in _PerKataTab above — same fix, same
      // reason: this used to swallow `error`/`stackTrace` completely.
      error: (error, stackTrace) {
        debugPrint('learningSessionListProvider("$studentId") failed: $error\n$stackTrace');
        return _ErrorRetry(
          onRetry: () => ref.invalidate(learningSessionListProvider(studentId)),
        );
      },
      data: (sessions) {
        if (sessions.isEmpty) {
          return const _EmptyMessage('Belum ada kata yang dipelajari');
        }
        return AppContent(
          maxWidth: AppContentWidth.list,
          child: AppResponsiveList(
            itemCount: sessions.length,
            minItemWidth: 340,
            maxColumns: 2,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemBuilder: (context, index) => _SessionCard(session: sessions[index]),
          ),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final LearningSession session;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatSessionTimestamp(session.startedAt),
                      style: AppTextStyles.bodyStrong,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge(text: '${session.wordIds.length} kata'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final wordId in session.wordIds)
                    AppBadge(text: wordId, tone: AppTone.info),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
