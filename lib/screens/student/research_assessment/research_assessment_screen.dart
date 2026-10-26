import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/research_attempt.dart';
import '../../../models/research_instrument.dart';
import '../../../providers/research_assessment_providers.dart';
import '../../../services/research_assessment_service.dart';
import '../../../theme/theme.dart';
import 'research_instructions.dart';

/// The pretest/posttest itself (`SPEC.md` §3.7, `DESIGN_REFERENCE.md` §5.5):
/// instructions and example (verbatim from the instrument PDF §5), then one
/// item per screen in the attempt's stored order — the word in bold with
/// its word class beside it, the four options in their stored shuffled
/// order, and "Saya tidak tahu kata ini" always last.
///
/// - "Lanjut" stays disabled until an option is chosen, and the next item
///   appears only after the server has confirmed the answer.
/// - There is no way back to an earlier item (answers are write-once).
/// - No score, correctness, explanation or feedback is shown, ever.
/// - No progress counter: the instrument doesn't specify one (pending
///   researcher decision).
/// All state lives in [ResearchAssessmentController].
class ResearchAssessmentScreen extends ConsumerWidget {
  const ResearchAssessmentScreen({
    super.key,
    required this.uid,
    required this.stage,
  });

  final String uid;
  final ResearchStage stage;

  String get _title =>
      stage == ResearchStage.preTest ? 'Pre-Test' : 'Post-Test';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = researchAssessmentControllerProvider(uid, stage);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final busy = switch (state) {
      ResearchAssessmentReady(:final starting) => starting,
      ResearchAssessmentInProgress(:final saving) => saving,
      ResearchAssessmentCompleting(:final error) => error == null,
      _ => false,
    };

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: switch (state) {
                ResearchAssessmentLoading() => const _Busy(
                  label: 'Memuat tes…',
                ),
                ResearchAssessmentLoadFailed() => _Message(
                  icon: Icons.wifi_off,
                  title: 'Gagal memuat tes',
                  body: 'Periksa koneksi internet, lalu coba lagi.',
                  actionLabel: 'Coba lagi',
                  onAction: controller.reload,
                ),
                ResearchAssessmentUnavailable(:final kind) => _unavailable(
                  kind,
                ),
                ResearchAssessmentInvalid() => const _Message(
                  icon: Icons.error_outline,
                  title: 'Tes tidak dapat dilanjutkan',
                  body: 'Data tes tidak sesuai. Hubungi peneliti.',
                ),
                ResearchAssessmentReady(:final starting, :final error) => _Intro(
                  buttonLabel: 'Mulai',
                  busy: starting,
                  errorText: switch (error) {
                    ResearchActionError.network =>
                      'Tes belum dapat dimulai. Periksa koneksi internet, lalu coba lagi.',
                    ResearchActionError.refused =>
                      'Tes belum dapat dimulai. Hubungi peneliti.',
                    null => null,
                  },
                  onPressed: controller.start,
                ),
                ResearchAssessmentInProgress(showIntro: true) => _Intro(
                  buttonLabel: 'Lanjutkan',
                  busy: false,
                  onPressed: controller.continueFromIntro,
                ),
                final ResearchAssessmentInProgress s => _ItemView(
                  state: s,
                  onSelect: controller.select,
                  onSubmit: controller.submit,
                ),
                ResearchAssessmentCompleting(error: null) => const _Busy(
                  label: 'Menyimpan…',
                ),
                ResearchAssessmentCompleting(:final error) => _Message(
                  icon: Icons.cloud_off,
                  title: 'Penyelesaian tes belum tersimpan',
                  body: error == ResearchActionError.refused
                      ? 'Tes belum dapat diselesaikan. Hubungi peneliti.'
                      : 'Periksa koneksi internet, lalu coba lagi.',
                  actionLabel: 'Coba lagi',
                  onAction: controller.retryCompletion,
                ),
                ResearchAssessmentCompleted() => _Message(
                  icon: Icons.check_circle_outline,
                  title: '$_title selesai',
                  body: 'Terima kasih. Semua jawabanmu sudah tersimpan.',
                  actionLabel: 'Kembali',
                  onAction: () => Navigator.of(context).maybePop(),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _unavailable(ResearchStageKind kind) => switch (kind) {
    ResearchStageKind.notEnrolled => const _Message(
      icon: Icons.person_off_outlined,
      title: 'Belum terdaftar',
      body:
          'Akun ini belum terdaftar sebagai peserta penelitian. Tes ini hanya '
          'untuk siswa yang didaftarkan oleh peneliti.',
    ),
    ResearchStageKind.locked => const _Message(
      icon: Icons.lock_outline,
      title: 'Belum dibuka',
      body:
          'Post-Test dapat dikerjakan setelah Pre-Test selesai dan dibuka oleh '
          'peneliti.',
    ),
    ResearchStageKind.voided => const _Message(
      icon: Icons.block,
      title: 'Tes dibatalkan',
      body:
          'Percobaan tes ini dibatalkan oleh peneliti. Tunggu arahan dari '
          'peneliti.',
    ),
    _ => _Message(
      icon: Icons.lock_outline,
      title: 'Belum dibuka',
      body: '$_title belum dibuka. Tunggu arahan dari peneliti.',
    ),
  };
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.body),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Instructions + example item, verbatim from the instrument (§5).
class _Intro extends StatelessWidget {
  const _Intro({
    required this.buttonLabel,
    required this.busy,
    required this.onPressed,
    this.errorText,
  });

  final String buttonLabel;
  final bool busy;
  final VoidCallback onPressed;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoBackground,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kResearchInstructionsTitle,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  kResearchInstructionsParagraph1,
                  style: AppTextStyles.body,
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  kResearchInstructionsParagraph2,
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(kResearchExampleHeading, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          const _WordHeading(
            word: kResearchExampleWord,
            posLabel: kResearchExamplePosLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < kResearchExampleOptions.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md, bottom: 2),
              child: Text(
                '${kResearchOptionLetters[i]}) ${kResearchExampleOptions[i]}',
                style: AppTextStyles.body,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          const Text(kResearchExampleExplanation, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.lg),
          if (errorText != null) ...[
            _ErrorBanner(text: errorText!),
            const SizedBox(height: AppSpacing.md),
          ],
          FilledButton(
            onPressed: busy ? null : onPressed,
            child: busy ? const _ButtonSpinner() : Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _WordHeading extends StatelessWidget {
  const _WordHeading({required this.word, required this.posLabel});

  final String word;
  final String posLabel;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: word,
            style: AppTextStyles.wordTitle.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: ' ($posLabel)', style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _ItemView extends StatelessWidget {
  const _ItemView({
    required this.state,
    required this.onSelect,
    required this.onSubmit,
  });

  final ResearchAssessmentInProgress state;
  final void Function(String optionId) onSelect;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final item = state.currentItem;
    final options = item.displayOptions;
    final canSubmit = state.selectedOptionId != null && !state.saving;
    return SingleChildScrollView(
      key: ValueKey('research-item-${item.itemId}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WordHeading(word: item.word, posLabel: item.posLabel),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            container: true,
            label: 'Pilihan jawaban',
            child: Column(
              children: [
                for (var i = 0; i < options.length; i++)
                  _OptionTile(
                    key: ValueKey('research-option-${options[i].id}'),
                    letter: kResearchOptionLetters[i],
                    option: options[i],
                    selected: state.selectedOptionId == options[i].id,
                    enabled: !state.saving && !state.selectionLocked,
                    onTap: () => onSelect(options[i].id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.error != null) ...[
            const _ErrorBanner(
              text:
                  'Jawaban belum tersimpan. Periksa koneksi internet, lalu '
                  'tekan tombol lagi.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          FilledButton(
            onPressed: canSubmit ? onSubmit : null,
            child: state.saving
                ? const _ButtonSpinner()
                : Text(state.isLastItem ? 'Kirim' : 'Lanjut'),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.letter,
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String letter;
  final ResearchOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        enabled: enabled,
        child: Material(
          color: selected ? AppColors.infoBackground : AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.disabled,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? AppColors.primary : AppColors.disabled,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$letter) ${option.text}',
                      style: AppTextStyles.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
