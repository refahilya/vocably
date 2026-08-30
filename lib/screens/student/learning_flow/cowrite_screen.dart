import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/learning_session.dart';
import '../../../providers/learning_session_controller.dart';
import '../../../theme/theme.dart';
import '../../../widgets/stepper_header.dart';

/// Fase 3 — Co-write dengan AI (`SPEC.md` §5.3, `DESIGN_REFERENCE.md`
/// §3.6). Chat-style turn-taking against `POST /cowrite-turn`; stops
/// automatically once every target word has been used correctly at
/// least once (`LearningFlowState.allWordsUsed`).
class CowriteScreen extends ConsumerStatefulWidget {
  const CowriteScreen({super.key});

  @override
  ConsumerState<CowriteScreen> createState() => _CowriteScreenState();
}

class _CowriteScreenState extends ConsumerState<CowriteScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learningFlowControllerProvider);
    final controller = ref.read(learningFlowControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Tulis Bersama AI')),
      body: Column(
        children: [
          const StepperHeader(activeIndex: 2),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final wordId in state.wordIds)
                  _TargetWordPill(
                    word: wordId,
                    used: state.allWordsUsedCorrectly.contains(wordId),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                for (final turn in state.cowriteTranscript) _ChatBubble(turn: turn),
              ],
            ),
          ),
          if (state.turnError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                state.turnError!,
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: state.allWordsUsed
                  ? _FinishedBanner(onFinish: () => _finish(context, controller))
                  : _ComposeBar(
                      textController: _textController,
                      suggestion: state.pendingSuggestion,
                      isSending: state.isSendingTurn,
                      isRequestingSuggestion: state.isRequestingSuggestion,
                      onRequestSuggestion: controller.requestSuggestion,
                      onSend: () {
                        final text = _textController.text;
                        if (text.trim().isEmpty) return;
                        controller.sendTurn(text);
                        _textController.clear();
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finish(BuildContext context, LearningFlowController controller) async {
    await controller.completeCowrite();
    // `completeCowrite` no longer throws on failure (Milestone 7 Phase 2
    // Stage 3) — check the freshly-updated state to see whether the write
    // actually completed before navigating away; a failure leaves
    // `turnError` set and `currentPhase` still `coWrite`, so the student
    // stays here and can retry by tapping "✓ Selesai" again.
    final succeeded =
        ref.read(learningFlowControllerProvider).currentPhase == LearningSessionPhase.selesai;
    if (succeeded && context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

class _TargetWordPill extends StatelessWidget {
  const _TargetWordPill({required this.word, required this.used});

  final String word;
  final bool used;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: used ? AppColors.primary : Colors.transparent,
        border: Border.all(color: used ? AppColors.primary : AppColors.disabled),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (used) ...[
            const Icon(Icons.check, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            word,
            style: TextStyle(
              color: used ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.turn});

  final CowriteTurn turn;

  @override
  Widget build(BuildContext context) {
    final isStudent = turn.sender == CowriteSender.siswa;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isStudent ? AppColors.primary : AppColors.accent,
                child: Icon(
                  isStudent ? Icons.person : Icons.smart_toy,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isStudent ? AppColors.background : AppColors.surfaceAlt,
                    border: isStudent ? Border.all(color: AppColors.disabled) : null,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Text(turn.text, style: AppTextStyles.body),
                ),
              ),
            ],
          ),
          if (turn.feedback != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: AppSpacing.xs),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warningBackground,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠️'),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(turn.feedback!, style: AppTextStyles.body)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  const _ComposeBar({
    required this.textController,
    required this.suggestion,
    required this.isSending,
    required this.isRequestingSuggestion,
    required this.onRequestSuggestion,
    required this.onSend,
  });

  final TextEditingController textController;
  final String? suggestion;
  final bool isSending;
  final bool isRequestingSuggestion;
  final VoidCallback onRequestSuggestion;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suggestion != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Text('💡 $suggestion', style: AppTextStyles.body),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: textController,
                enabled: !isSending,
                decoration: const InputDecoration(hintText: 'Tulis kalimatmu...'),
                minLines: 1,
                maxLines: 3,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: isRequestingSuggestion ? null : onRequestSuggestion,
            icon: const Icon(Icons.lightbulb_outline, size: 16),
            label: const Text('Saran menulis'),
          ),
        ),
      ],
    );
  }
}

class _FinishedBanner extends StatelessWidget {
  const _FinishedBanner({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.successBackground,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: const Text(
            '🎉 Selamat! Semua kata target sudah digunakan!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          onPressed: onFinish,
          child: const Text('✓ Selesai'),
        ),
      ],
    );
  }
}
