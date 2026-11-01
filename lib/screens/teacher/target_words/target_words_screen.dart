import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/target_word_set.dart';
import '../../../providers/teacher_target_word_providers.dart';
import '../../../theme/theme.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppContent(
          maxWidth: AppContentWidth.page,
          vertical: AppSpacing.md,
          child: AppSectionHeader(
            title: 'Target Kata',
            subtitle: 'Target kata untuk siswa',
            titleStyle: AppTextStyles.pageTitle,
            trailing: FilledButton.icon(
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
          ),
        ),
        Expanded(
          child: setsAsync.when(
            loading: () => const AppLoading(),
            error: (error, _) => AppErrorState(
              message: 'Gagal memuat daftar target kata.',
              onRetry: () =>
                  ref.invalidate(teacherTargetWordSetsProvider(profile.uid)),
            ),
            data: (sets) {
              if (sets.isEmpty) {
                return const AppStateMessage(
                  icon: Icons.track_changes,
                  title: 'Belum ada target kata yang dibuat.',
                  body:
                      'Klik "+ Set Target Baru" untuk menentukan kata target bagi siswa.',
                );
              }

              return AppContent(
                maxWidth: AppContentWidth.page,
                child: AppResponsiveList(
                  itemCount: sets.length,
                  minItemWidth: 360,
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  itemBuilder: (context, index) =>
                      _TargetWordSetCard(set: sets[index]),
                ),
              );
            },
          ),
        ),
      ],
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
    final AppTone statusTone;

    if (isUpcoming) {
      statusLabel = 'Mendatang';
      statusTone = AppTone.info;
    } else if (isExpired) {
      statusLabel = 'Selesai';
      statusTone = AppTone.neutral;
    } else {
      statusLabel = 'Aktif';
      statusTone = AppTone.success;
    }

    final dateRangeText = isNoEndDate
        ? '${_formatDate(set.startAt)} – Tanpa batas akhir'
        : '${_formatDate(set.startAt)} – ${_formatDate(set.endAt)}';

    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppBadge.solid(text: set.cefrLevel),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${set.wordIds.length} kata',
                  style: AppTextStyles.bodyStrong,
                ),
              ),
              AppBadge(text: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(dateRangeText, style: AppTextStyles.caption),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final word in set.wordIds) AppBadge(text: word),
            ],
          ),
        ],
      ),
    );
  }
}
