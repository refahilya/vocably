import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vocab_bundle_entry.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../theme/theme.dart';
import '../vocab_browser/word_detail_screen.dart';

/// "Target Kata Hari Ini" → tap → this list (`DESIGN_REFERENCE.md` §5.1:
/// "Tap → daftar kata target (list, bukan grid chip, karena urutannya
/// ditentukan guru)").
///
/// **The CTA is deliberately present but inert** — "Belajar Kata Ini
/// dengan Cerita" starts the 3-phase flow, which is Milestone 7. Keeping
/// the button visible (disabled, with an explanatory caption) rather than
/// omitting it keeps the screen honest about what's coming without
/// implying the feature works today.
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
        data: (entries) => _TargetWordListBody(entries: entries),
      ),
    );
  }
}

class _TargetWordListBody extends StatelessWidget {
  const _TargetWordListBody({required this.entries});

  final List<VocabBundleEntry> entries;

  @override
  Widget build(BuildContext context) {
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
                  // Milestone 7 (Storyfier core) wires this up.
                  onPressed: null,
                  child: const Text('📖 Belajar Kata Ini dengan Cerita'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Segera hadir di Milestone berikutnya.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
