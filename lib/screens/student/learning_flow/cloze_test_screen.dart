import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/learning_session_controller.dart';
import '../../../theme/theme.dart';
import '../../../utils/cloze_blanks.dart';
import '../../../widgets/stepper_header.dart';
import 'cowrite_screen.dart';

/// Fase 2 — Cloze Test (`SPEC.md` §5.2, `DESIGN_REFERENCE.md` §3.5). No
/// AI call — blanks and answer choices come straight from the locked
/// story's markers via `utils/cloze_blanks.dart`.
class ClozeTestScreen extends ConsumerWidget {
  const ClozeTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(learningFlowControllerProvider);
    final controller = ref.read(learningFlowControllerProvider.notifier);
    final segments = buildClozeSegments(state.storyContent ?? '');
    final blanks = blankTargetWords(segments);
    final allAnswered = blanks.every((w) => state.clozeAnswers[w] != null);
    final grading = state.hasSubmittedCloze ? gradeClozeAnswers(segments, state.clozeAnswers) : null;
    final anyWrong = grading != null && grading.values.any((correct) => !correct);

    return Scaffold(
      appBar: AppBar(title: const Text('Cloze Test')),
      body: Column(
        children: [
          const StepperHeader(activeIndex: 1),
          Container(
            width: double.infinity,
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: const Text(
              'Pilih kata yang tepat untuk setiap bagian yang kosong.',
              style: AppTextStyles.body,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ClozeStory(
                    segments: segments,
                    answers: state.clozeAnswers,
                    options: state.wordIds,
                    grading: grading,
                    // Milestone 7 Phase 2 Stage 5: once Submit has been
                    // tapped, answers are locked — `hasSubmittedCloze` is
                    // the single existing source of truth for this (also
                    // what reveals the grading colors and swaps the
                    // button to "Selanjutnya"), so no second submission
                    // flag is introduced here.
                    locked: state.hasSubmittedCloze,
                    onAnswerChanged: controller.setClozeAnswer,
                  ),
                  if (anyWrong) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.error),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Ada jawaban yang salah. Jawaban yang benar ditandai hijau.',
                              style: AppTextStyles.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (state.clozeSubmitError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(state.clozeSubmitError!, style: AppTextStyles.body),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: state.hasSubmittedCloze
                  ? FilledButton(
                      onPressed: () async {
                        await controller.confirmClozeAndAdvance(segments);
                        // `confirmClozeAndAdvance` no longer throws on
                        // failure (Milestone 7 Phase 2 Stage 3) — check
                        // the freshly-updated state to see whether the
                        // write actually succeeded before navigating on;
                        // a failure leaves `clozeSubmitError` set and
                        // `currentPhase` still `clozeTest`, so the
                        // student stays here and can retry.
                        final succeeded =
                            ref.read(learningFlowControllerProvider).clozeSubmitError == null;
                        if (succeeded && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CowriteScreen()),
                          );
                        }
                      },
                      child: const Text('Selanjutnya →'),
                    )
                  : FilledButton(
                      onPressed: allAnswered ? controller.submitCloze : null,
                      child: const Text('Submit'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClozeStory extends StatelessWidget {
  const _ClozeStory({
    required this.segments,
    required this.answers,
    required this.options,
    required this.grading,
    required this.locked,
    required this.onAnswerChanged,
  });

  final List<ClozeSegment> segments;
  final Map<String, String?> answers;
  final List<String> options;
  final Map<String, bool>? grading;

  /// `true` once Submit has been tapped — every dropdown becomes
  /// non-interactive (`onChanged: null`), so an already-graded answer can
  /// never be changed afterward (Milestone 7 Phase 2 Stage 5).
  final bool locked;
  final void Function(String targetWord, String? answer) onAnswerChanged;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: AppTextStyles.body,
        children: [
          for (final segment in segments)
            switch (segment) {
              ClozePlainSegment(:final text) => TextSpan(text: text),
              // Milestone 7 Phase 2 Stage 4: deliberately plain, unstyled
              // text — never highlighted like Fase 1's story view. A
              // repeated target word's surface form must not visually
              // leak the answer to the blank left for its first
              // occurrence. See `ClozeHighlightSegment`'s doc comment
              // (`cloze_blanks.dart`) for why this case should no longer
              // actually be reached in the live app at all.
              ClozeHighlightSegment(:final surfaceForm) => TextSpan(text: surfaceForm),
              ClozeBlankSegment(:final targetWord) => WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _ClozeDropdown(
                    targetWord: targetWord,
                    value: answers[targetWord],
                    options: options,
                    isCorrect: grading?[targetWord],
                    onChanged: locked ? null : (value) => onAnswerChanged(targetWord, value),
                  ),
                ),
            },
        ],
      ),
    );
  }
}

class _ClozeDropdown extends StatelessWidget {
  const _ClozeDropdown({
    required this.targetWord,
    required this.value,
    required this.options,
    required this.isCorrect,
    required this.onChanged,
  });

  final String targetWord;
  final String? value;
  final List<String> options;

  /// `null` before grading is revealed; otherwise whether [value] matches
  /// [targetWord].
  final bool? isCorrect;

  /// `null` once the answer is locked (Milestone 7 Phase 2 Stage 5) —
  /// `DropdownButton` treats a `null` `onChanged` as disabled, which is
  /// the only thing that actually makes it non-interactive.
  final void Function(String?)? onChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (isCorrect) {
      true => AppColors.success,
      false => AppColors.error,
      null => AppColors.disabled,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: isCorrect == null ? 1 : 2),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: const Text('...'),
          isDense: true,
          items: [
            for (final option in options) DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
