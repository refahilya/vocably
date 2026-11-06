import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/app_user.dart';
import '../../../models/research_attempt.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/research_assessment_providers.dart';
import '../../../providers/research_treatment_providers.dart';
import '../../../services/research_assessment_service.dart';
import '../../../theme/theme.dart';
import '../../../utils/cefr_levels.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
import '../placement_test/placement_test_screen.dart';
import '../research_assessment/research_assessment_screen.dart';
import '../vocab_browser/vocab_browser_screen.dart';
import 'target_word_list_screen.dart';

/// Real "Belajar" dashboard (`SPEC.md` §3.2, `DESIGN_REFERENCE.md` §5.1):
/// "Target Kata Hari Ini" as the primary action, the "Level" ladder beside
/// it on wide windows and below it on phones, and a visually separated
/// Pre-Test/Post-Test section. No `Scaffold`/`AppBar` here — `AppNavShell`
/// owns those, same convention every destination body has followed since
/// Milestone 3.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.profile});

  final AppUser profile;

  /// Width from which the two main panels sit side by side.
  static const double _twoColumnWidth = 700;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScrollPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Halo, ${profile.name}', style: AppTextStyles.pageTitle),
          const SizedBox(height: AppSpacing.md),
          _ResearchSessionCards(studentId: profile.uid),
          LayoutBuilder(
            builder: (context, constraints) {
              final target = _TargetWordCard(studentId: profile.uid);
              final level = _LevelCard(profile: profile);
              if (constraints.maxWidth < _twoColumnWidth) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    target,
                    const SizedBox(height: AppSpacing.md),
                    level,
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: target),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 6, child: level),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Tes penelitian', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          _PreTestPostTestSection(uid: profile.uid),
        ],
      ),
    );
  }
}

/// Official research treatment sessions open for this student right now
/// (`DATA_MODEL.md` §6e, `DESIGN_REFERENCE.md` §5.1): only shown while the
/// researcher has a session open in class with this student marked present.
/// It carries the highlighter because it is what the class is doing now.
/// Also records, in the background, any finished session whose completion
/// could not be recorded when it ended.
class _ResearchSessionCards extends ConsumerWidget {
  const _ResearchSessionCards({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(researchTreatmentReconcileProvider(studentId));
    final now = DateTime.now();
    // A session whose window has closed disappears (the listener gets no
    // event when time passes; any rebuild drops it).
    final offers = [
      for (final o in ref.watch(researchSessionOffersProvider(studentId)).value ?? const <ResearchSessionOffer>[])
        if (now.isBefore(o.set.endAt)) o,
    ];
    if (offers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final offer in offers) ...[
          _ResearchSessionCard(studentId: studentId, offer: offer),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _ResearchSessionCard extends StatelessWidget {
  const _ResearchSessionCard({required this.studentId, required this.offer});

  final String studentId;
  final ResearchSessionOffer offer;

  @override
  Widget build(BuildContext context) {
    final until = DateFormat('HH.mm').format(offer.set.endAt);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: offer.completed ? AppColors.line : AppColors.marker, width: 2),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final container = ProviderScope.containerOf(context, listen: false);
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TargetWordListScreen(studentId: studentId, research: offer),
            ),
          );
          container.invalidate(researchSessionOffersProvider(studentId));
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.school_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sesi Riset ke-${offer.info.session}', style: AppTextStyles.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      offer.completed
                          ? 'Sudah selesai'
                          : '${offer.set.wordIds.length} kata, dibuka sampai pukul $until',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              offer.completed
                  ? const AppBadge(text: 'Selesai', tone: AppTone.success)
                  : const Icon(Icons.arrow_forward, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Target Kata Hari Ini" (`DESIGN_REFERENCE.md` §5.1): the one navy block on
/// the page, because today's words are what a student opens the app for. The
/// whole block is tappable — resolving/loading/empty states are all handled
/// by [TargetWordListScreen] itself, so this only needs a one-line summary
/// for each [AsyncValue] state.
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

    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TargetWordListScreen(studentId: studentId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.track_changes,
                color: AppColors.marker,
                size: 28,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Target Kata Hari Ini',
                style: AppTextStyles.statusTitle.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.onNavyMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_forward, color: Colors.white),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Level" (`DESIGN_REFERENCE.md` §5.1/§5.7): the six CEFR levels as a rising
/// ladder, because they are ordered and the student's place on it is the
/// point. The active level is `users.resultLevel` from the latest scored
/// Placement Test attempt — never a score, and never the research band
/// (`DATA_MODEL.md` §1). Also holds the permanent Placement Test entry point.
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final level = profile.resultLevel;
    final activeIndex = level == null ? -1 : kCefrLevels.indexOf(level);

    return AppSheet(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              const Text('Level', style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            level != null
                ? 'Level kamu saat ini: $level'
                : 'Kamu belum mengambil tes penempatan.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.smd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < kCefrLevels.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _LevelStep(
                    level: kCefrLevels[i],
                    rung: i,
                    isActive: i == activeIndex,
                    isReached: i < activeIndex,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            VocabBrowserScreen(initialLevel: kCefrLevels[i]),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlacementTestScreen(uid: profile.uid),
              ),
            ),
            child: Text(
              profile.placementTestCompleted == true
                  ? 'Lihat Tes Penempatan'
                  : 'Ambil Tes Penempatan',
            ),
          ),
        ],
      ),
    );
  }
}

/// One rung of the level ladder. C2 is always visually muted (`SPEC.md` §3.2:
/// "cakupan data... hanya A1–C1... C2 tetap ditampilkan sebagai pilihan") —
/// still tappable either way, leading into `VocabBrowserScreen`'s own
/// empty-state handling for that level.
class _LevelStep extends StatelessWidget {
  const _LevelStep({
    required this.level,
    required this.rung,
    required this.isActive,
    required this.isReached,
    required this.onTap,
  });

  final String level;
  final int rung;
  final bool isActive;
  final bool isReached;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMuted = level == 'C2';
    final background = isMuted
        ? AppColors.disabledBackground
        : isActive
        ? AppColors.primary
        : isReached
        ? AppColors.primaryTintStrong
        : AppColors.primaryTint;
    final foreground = isMuted
        ? AppColors.inkFaint
        : isActive
        ? Colors.white
        : AppColors.primary;

    return Semantics(
      button: true,
      selected: isActive,
      label: level,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.small),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48 + rung * 9,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                // Only the text is hidden from screen readers: the label above
                // already says it, and the tap action must stay reachable.
                child: ExcludeSemantics(
                  child: Text(
                    level,
                    style: AppTextStyles.bodyStrong.copyWith(color: foreground),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pre-Test/Post-Test entry section (`SPEC.md` §3.7,
/// `DESIGN_REFERENCE.md` §5.5) — visually separated below the two main
/// cards. Each banner shows the stage's real status for this student, read
/// from the server (participant record + authorized attempt), and opens
/// [ResearchAssessmentScreen], which explains every state. The status is
/// refreshed when the student comes back from the test.
class _PreTestPostTestSection extends StatelessWidget {
  const _PreTestPostTestSection({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AssessmentBanner(
            uid: uid,
            stage: ResearchStage.preTest,
            label: 'Pre-Test',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AssessmentBanner(
            uid: uid,
            stage: ResearchStage.postTest,
            label: 'Post-Test',
          ),
        ),
      ],
    );
  }
}

class _AssessmentBanner extends ConsumerWidget {
  const _AssessmentBanner({
    required this.uid,
    required this.stage,
    required this.label,
  });

  final String uid;
  final ResearchStage stage;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(researchStageStatusProvider(uid, stage));
    final (text, tone) = switch (status) {
      AsyncData(:final value) => switch (value) {
        ResearchStageKind.notEnrolled ||
        ResearchStageKind.notEligible => ('Belum tersedia', AppTone.neutral),
        ResearchStageKind.notAuthorized ||
        ResearchStageKind.locked => ('Belum dibuka', AppTone.neutral),
        ResearchStageKind.stageClosed => ('Ditutup', AppTone.neutral),
        ResearchStageKind.notStarted => ('Siap dikerjakan', AppTone.info),
        ResearchStageKind.inProgress => ('Lanjutkan', AppTone.warning),
        ResearchStageKind.completed => ('Selesai', AppTone.success),
        ResearchStageKind.voided => ('Dibatalkan', AppTone.error),
        ResearchStageKind.invalid => ('Hubungi peneliti', AppTone.error),
      },
      AsyncError() => ('Gagal memuat', AppTone.error),
      _ => ('Memuat…', AppTone.neutral),
    };

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          // The container outlives this widget, which may be rebuilt while
          // the test is open (a resize moves the dashboard to a new parent).
          final container = ProviderScope.containerOf(context, listen: false);
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ResearchAssessmentScreen(uid: uid, stage: stage),
            ),
          );
          container.invalidate(
            researchStageStatusProvider(uid, ResearchStage.preTest),
          );
          container.invalidate(
            researchStageStatusProvider(uid, ResearchStage.postTest),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.smd),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(label, style: AppTextStyles.bodyStrong),
              AppBadge(text: text, tone: tone),
            ],
          ),
        ),
      ),
    );
  }
}
