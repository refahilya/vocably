import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/learning_session.dart';
import '../../../providers/history_providers.dart';
import '../../../providers/learning_session_controller.dart';
import '../../../theme/theme.dart';
import '../../../utils/session_date_format.dart';
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
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.black54,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'Per Kata'), Tab(text: 'Per Sesi')],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gagal memuat riwayat.'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

/// "Per Kata" tab (`SPEC.md` §3.6): filterable-by-mastery word list, with
/// a "Pelajari Kembali" action surfaced only under the `difficult` filter
/// — present but inert, since it launches Milestone 7's 3-phase flow.
class _PerKataTab extends ConsumerWidget {
  const _PerKataTab({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(historyWordEntriesProvider(studentId));
    final filter = ref.watch(historyFilterProvider);

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
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
                    )
                  : _PerKataList(
                      studentId: studentId,
                      entries: filtered,
                      showRelearnAction: filter == HistoryMasteryFilter.difficult,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PerKataList extends ConsumerWidget {
  const _PerKataList({
    required this.studentId,
    required this.entries,
    required this.showRelearnAction,
  });

  final String studentId;
  final List<HistoryWordEntry> entries;
  final bool showRelearnAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = entries[index];
              return ListTile(
                leading: MasteryBadge(masteryStatus: item.progress.masteryStatus),
                title: Text(item.entry?.word ?? item.progress.wordId),
                subtitle: Text(item.entry?.primaryMeaning.translation ?? '—'),
              );
            },
          ),
        ),
        // "Pelajari Kembali" (`SPEC.md` §3.6) relearns **every** word
        // currently shown under the `difficult` filter — per the project
        // owner's Milestone 7 Decision 2, no per-word checkbox selection
        // was added; the mastery filter itself is the selection.
        if (showRelearnAction)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref
                      .read(learningFlowControllerProvider.notifier)
                      .startFlow(
                        studentId: studentId,
                        wordIds: [for (final item in entries) item.progress.wordId],
                        sourceType: LearningSessionSourceType.pelajariUlangDifficult,
                      );
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const StoryReadingScreen()));
                },
                child: const Text('Pelajari Kembali'),
              ),
            ),
          ),
      ],
    );
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: sessions.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => _SessionCard(session: sessions[index]),
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
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session)),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.disabled),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    formatSessionTimestamp(session.startedAt),
                    style: AppTextStyles.body,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('${session.wordIds.length} kata', style: AppTextStyles.caption),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final wordId in session.wordIds)
                  Chip(label: Text(wordId), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
