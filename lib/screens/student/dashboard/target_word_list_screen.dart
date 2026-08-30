import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/learning_session.dart';
import '../../../models/vocab_bundle_entry.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/learning_session_controller.dart';
import '../../../theme/theme.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Gagal memuat target kata.'),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(targetWordEntriesProvider(studentId)),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (entries) => _TargetWordListBody(studentId: studentId, entries: entries),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Belum ada target kata dari guru. Coba jelajahi kosakata sendiri '
            'lewat menu Level.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                title: Text(entry.word),
                subtitle: Text(entry.primaryMeaning.translation ?? '—'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WordDetailScreen(entry: entry)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
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
          ),
        ),
      ],
    );
  }
}
