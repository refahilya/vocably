import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/learning_session.dart';
import '../../../models/vocab_bundle_entry.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/learning_session_controller.dart';
import '../../../theme/theme.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
import '../learning_flow/story_reading_screen.dart';
import '../vocab_browser/word_detail_screen.dart';

/// "Target Kata Hari Ini" → tap → this list (`DESIGN_REFERENCE.md` §5.1:
/// "Tap → daftar kata target (list, bukan grid chip, karena urutannya
/// ditentukan guru)").
///
/// The CTA starts the 3-phase flow (`sourceType: targetGuru`,
/// `DATA_MODEL.md` §4) — Milestone 7.
class TargetWordListScreen extends ConsumerWidget {
  const TargetWordListScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(targetWordEntriesProvider(studentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Target Kata Hari Ini')),
      body: entriesAsync.when(
        loading: () => const AppLoading(),
        error: (error, stackTrace) => AppErrorState(
          message: 'Gagal memuat target kata.',
          onRetry: () => ref.invalidate(targetWordEntriesProvider(studentId)),
        ),
        data: (entries) =>
            _TargetWordListBody(studentId: studentId, entries: entries),
      ),
    );
  }
}

class _TargetWordListBody extends ConsumerWidget {
  const _TargetWordListBody({required this.studentId, required this.entries});

  final String studentId;
  final List<VocabBundleEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      // DESIGN_REFERENCE.md §5.8: "Guru belum men-set target kata".
      return const AppStateMessage(
        icon: Icons.track_changes,
        title: 'Belum ada target kata dari guru.',
        body: 'Coba jelajahi kosakata sendiri lewat menu Level.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: AppScrollPage(
            maxWidth: AppContentWidth.reading,
            child: AppSheet(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const Divider(),
                    _TargetWordRow(entry: entries[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
        AppBottomBar(
          maxWidth: AppContentWidth.reading,
          child: FilledButton(
            onPressed: () {
              ref
                  .read(learningFlowControllerProvider.notifier)
                  .startFlow(
                    studentId: studentId,
                    wordIds: [for (final entry in entries) entry.word],
                    sourceType: LearningSessionSourceType.targetGuru,
                  );
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoryReadingScreen()),
              );
            },
            child: const Text('📖 Belajar Kata Ini dengan Cerita'),
          ),
        ),
      ],
    );
  }
}

class _TargetWordRow extends StatelessWidget {
  const _TargetWordRow({required this.entry});

  final VocabBundleEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WordDetailScreen(entry: entry)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.word, style: AppTextStyles.wordRow),
                  Text(
                    entry.primaryMeaning.translation ?? '—',
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
