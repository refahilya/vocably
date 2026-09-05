import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/vocab_browser_providers.dart';
import '../../../theme/theme.dart';
import '../../../utils/cefr_levels.dart';
import '../placement_test/placement_test_placeholder_screen.dart';
import '../research_assessment/research_assessment_placeholder_screen.dart';
import '../vocab_browser/vocab_browser_screen.dart';
import 'target_word_list_screen.dart';

/// Real "Belajar" dashboard (`SPEC.md` §3.2, `DESIGN_REFERENCE.md` §5.1) —
/// replaces `DashboardPlaceholder` (Milestone 6). Two cards ("Target Kata
/// Hari Ini", "Level") plus a visually-separated Pre-Test/Post-Test entry
/// section below, matching §5.1's layout exactly. No `Scaffold`/`AppBar`
/// here — `AppNavShell` owns those, same convention every destination
/// body has followed since Milestone 3.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TargetWordCard(studentId: profile.uid),
          const SizedBox(height: AppSpacing.md),
          _LevelCard(profile: profile),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          const _PreTestPostTestSection(),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton(
              onPressed: () => ref.read(authServiceProvider).signOut(),
              child: const Text('Keluar'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared card shell — icon + title header, then whatever [child] the
/// caller needs. Wrapped in [Material]/[InkWell] so an optional [onTap]
/// gets a proper ink splash without fighting any interactive content
/// nested inside [child] (see [_LevelCard], which nests its own
/// per-pill taps and deliberately passes no [onTap] here).
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.large),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.disabled),
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// "Target Kata Hari Ini" card (`DESIGN_REFERENCE.md` §5.1). The whole
/// card is tappable — resolving/loading/empty states are all handled by
/// [TargetWordListScreen] itself, so this card only needs a one-line
/// summary for each [AsyncValue] state.
class _TargetWordCard extends ConsumerWidget {
  const _TargetWordCard({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(targetWordEntriesProvider(studentId));

    final subtitle = entriesAsync.when(
      loading: () => 'Memuat...',
      error: (error, stackTrace) => 'Gagal memuat target kata.',
      data: (entries) => entries.isEmpty
          ? 'Belum ada target kata dari guru'
          : '${entries.length} kata dari Guru',
    );

    return _DashboardCard(
      icon: Icons.track_changes,
      title: 'Target Kata Hari Ini',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TargetWordListScreen(studentId: studentId),
        ),
      ),
      child: Text(subtitle, style: AppTextStyles.body),
    );
  }
}

/// "Level" card (`DESIGN_REFERENCE.md` §5.1/§5.7) — 6 CEFR pills, the
/// active level (if any) called out, C2 always visually muted, plus the
/// permanent Placement Test entry point link.
class _LevelCard extends ConsumerWidget {
  const _LevelCard({required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLevel = profile.cefrLevel != null;

    return _DashboardCard(
      icon: Icons.leaderboard,
      title: 'Level',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasLevel
                ? 'Level kamu saat ini: ${profile.cefrLevel}'
                : 'Kamu belum mengambil tes penempatan.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final level in kCefrLevels)
                _LevelPill(
                  level: level,
                  isActive: profile.cefrLevel == level,
                  onTap: () {
                    ref
                        .read(vocabBrowserFilterProvider.notifier)
                        .selectLevel(level);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VocabBrowserScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PlacementTestPlaceholderScreen(),
                ),
              ),
              child: Text(
                profile.placementTestCompleted == true
                    ? 'Ambil Ulang Placement Test'
                    : 'Ambil Placement Test',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One CEFR pill. C2 is always visually muted (`SPEC.md` §3.2: "cakupan
/// data... hanya A1–C1... C2 tetap ditampilkan sebagai pilihan" +
/// `DESIGN_REFERENCE.md` §5.1: "Pill C2 ditampilkan dengan style
/// pudar/disabled ringan") — still tappable either way, leading into
/// `VocabBrowserScreen`'s own empty-state handling for that level.
class _LevelPill extends StatelessWidget {
  const _LevelPill({
    required this.level,
    required this.isActive,
    required this.onTap,
  });

  final String level;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMuted = level == 'C2';
    final background = isMuted
        ? AppColors.disabledBackground
        : (isActive ? AppColors.primary : AppColors.background);
    final foreground = isMuted
        ? AppColors.disabled
        : (isActive ? Colors.white : AppColors.primary);
    final borderColor = isMuted
        ? AppColors.disabled
        : (isActive ? AppColors.primary : AppColors.disabled);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Semantics(
        button: true,
        selected: isActive,
        label: level,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            level,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Pre-Test/Post-Test entry section (`SPEC.md` §3.7,
/// `DESIGN_REFERENCE.md` §5.5) — visually separated below the two main
/// cards, "Segera" styling (neutral, not navy solid) since the research
/// instrument itself is fully TBD. Still a real entry point — tapping
/// either opens [ResearchAssessmentPlaceholderScreen] rather than doing
/// nothing, so it's honest about "not built yet" instead of appearing
/// broken.
class _PreTestPostTestSection extends StatelessWidget {
  const _PreTestPostTestSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AssessmentBanner(
            assessmentType: 'preTest',
            label: 'Pre-Test',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AssessmentBanner(
            assessmentType: 'postTest',
            label: 'Post-Test',
          ),
        ),
      ],
    );
  }
}

class _AssessmentBanner extends StatelessWidget {
  const _AssessmentBanner({required this.assessmentType, required this.label});

  final String assessmentType;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResearchAssessmentPlaceholderScreen(
            assessmentType: assessmentType,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.disabledBackground,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const _SegeraBadge(),
          ],
        ),
      ),
    );
  }
}

class _SegeraBadge extends StatelessWidget {
  const _SegeraBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.disabled,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        'Segera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
