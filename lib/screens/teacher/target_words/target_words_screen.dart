import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/target_word_set.dart';
import '../../../providers/teacher_target_word_providers.dart';
import '../../../theme/theme.dart';
import 'set_target_word_screen.dart';

/// Guru "Target Kata" screen (`SPEC.md` §4.1, `DESIGN_REFERENCE.md` §5.4).
/// Displays existing target word sets created by the teacher and provides
/// a "+ Set Target Baru" CTA.
class TargetWordsScreen extends ConsumerWidget {
  const TargetWordsScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(teacherTargetWordSetsProvider(profile.uid));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top action header
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Kata',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Target kata untuk siswa',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SetTargetWordScreen(profile: profile),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Set Target Baru'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          // Content body
          Expanded(
            child: setsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gagal memuat daftar target kata.'),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(
                        teacherTargetWordSetsProvider(profile.uid),
                      ),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (sets) {
                if (sets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.track_changes,
                            size: 64,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Belum ada target kata yang dibuat.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Klik "+ Set Target Baru" untuk menentukan kata target bagi siswa.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: sets.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final set = sets[index];
                    return _TargetWordSetCard(set: set);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetWordSetCard extends StatelessWidget {
  const _TargetWordSetCard({required this.set});

  final TargetWordSet set;

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isUpcoming = now.isBefore(set.startAt);
    final isExpired = now.isAfter(set.endAt);
    final isNoEndDate = set.endAt.year >= 2099;

    final String statusLabel;
    final Color statusColor;
    final Color statusTextColor;

    if (isUpcoming) {
      statusLabel = 'Mendatang';
      statusColor = Colors.blue.shade50;
      statusTextColor = Colors.blue.shade800;
    } else if (isExpired) {
      statusLabel = 'Selesai';
      statusColor = Colors.grey.shade200;
      statusTextColor = Colors.grey.shade700;
    } else {
      statusLabel = 'Aktif';
      statusColor = Colors.green.shade50;
      statusTextColor = Colors.green.shade800;
    }

    final dateRangeText = isNoEndDate
        ? '${_formatDate(set.startAt)} – Tanpa batas akhir'
        : '${_formatDate(set.startAt)} – ${_formatDate(set.endAt)}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Level, word count, status
            Row(
              children: [
                Chip(
                  label: Text(set.cefrLevel),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${set.wordIds.length} kata',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Date range
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  dateRangeText,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Words chips
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 4,
              children: [
                for (final word in set.wordIds)
                  Chip(
                    label: Text(word),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
