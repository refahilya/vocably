import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/learning_session.dart';
import '../../../providers/learning_session_controller.dart';
import '../../../theme/theme.dart';
import '../../../utils/cowrite_suggestion.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
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
  final _inputFocusNode = FocusNode();
  final _chatScrollController = ScrollController();
  int _lastTranscriptLength = 0;

  @override
  void dispose() {
    _chatScrollController.dispose();
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// Keeps the newest turn in view as the conversation grows.
  void _followTranscript(int length) {
    if (length == _lastTranscriptLength) return;
    _lastTranscriptLength = length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      _chatScrollController.jumpTo(
        _chatScrollController.position.maxScrollExtent,
      );
    });
  }

  void _activateComposerInput() {
    if (!mounted) return;
    final state = ref.read(learningFlowControllerProvider);
    if (state.allWordsUsed || state.isSendingTurn) return;
    if (!_inputFocusNode.canRequestFocus) return;
    if (!_textController.selection.isValid) {
      _textController.selection = TextSelection.collapsed(
        offset: _textController.text.length,
      );
    }
    final editableTextState = _inputFocusNode.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (editableTextState != null) {
      editableTextState.requestKeyboard();
    } else if (!_inputFocusNode.hasFocus) {
      _inputFocusNode.requestFocus();
    }
  }

  void _scheduleComposerInputActivation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activateComposerInput();
    });
  }

  Future<void> _handleSend(LearningFlowController controller) async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    final sendFuture = controller.sendTurn(text);
    final currentState = ref.read(learningFlowControllerProvider);
    if (!currentState.isSendingTurn) {
      if (!currentState.allWordsUsed) {
        final endOffset = _textController.text.length;
        _textController.value = _textController.value.copyWith(
          selection: TextSelection.collapsed(offset: endOffset),
          composing: TextRange.empty,
        );
        _activateComposerInput();
        _scheduleComposerInputActivation();
      }
      await sendFuture;
      return;
    }

    _textController.value = const TextEditingValue(
      selection: TextSelection.collapsed(offset: 0),
    );
    await sendFuture;
    if (!mounted) return;
    final afterState = ref.read(learningFlowControllerProvider);
    if (!afterState.allWordsUsed && !afterState.isSendingTurn) {
      _scheduleComposerInputActivation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learningFlowControllerProvider);
    final controller = ref.read(learningFlowControllerProvider.notifier);
    _followTranscript(state.cowriteTranscript.length);

    final header = <Widget>[
      const StepperHeader(activeIndex: 2),
      ColoredBox(
        color: AppColors.surface,
        child: AppContent(
          maxWidth: AppContentWidth.chat,
          vertical: AppSpacing.smd,
          child: Align(
            alignment: Alignment.centerLeft,
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
        ),
      ),
      const Divider(),
    ];
    // A short window keeps its height for the conversation and the composer:
    // the header scrolls away with the chat instead of staying pinned.
    final short = isShortWindow(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tulis Bersama AI')),
      body: Column(
        children: [
          if (!short) ...header,
          Expanded(
            child: ListView(
              controller: _chatScrollController,
              padding: EdgeInsets.only(
                top: short ? 0 : AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              children: [
                if (short) ...header,
                for (final turn in state.cowriteTranscript)
                  AppContent(
                    maxWidth: AppContentWidth.chat,
                    child: _ChatBubble(turn: turn),
                  ),
              ],
            ),
          ),
          state.turnError != null
              ? AppContent(
                  maxWidth: AppContentWidth.chat,
                  vertical: AppSpacing.xs,
                  child: AppNotice(text: state.turnError!, tone: AppTone.error),
                )
              : const SizedBox.shrink(),
          AppBottomBar(
            key: const ValueKey('cowrite-bottom-area'),
            maxWidth: AppContentWidth.chat,
            child: state.allWordsUsed
                ? _FinishedBanner(
                    isCompleting: state.isCompletingCowrite,
                    onFinish: () => _finish(context, controller),
                  )
                : _ComposeBar(
                    textController: _textController,
                    focusNode: _inputFocusNode,
                    suggestion: state.pendingSuggestion == null
                        ? null
                        : formatWritingSuggestion(state.pendingSuggestion!),
                    isSending: state.isSendingTurn,
                    isRequestingSuggestion: state.isRequestingSuggestion,
                    onRequestSuggestion: controller.requestSuggestion,
                    onSend: () => _handleSend(controller),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _finish(
    BuildContext context,
    LearningFlowController controller,
  ) async {
    await controller.completeCowrite();
    // `completeCowrite` no longer throws on failure (Milestone 7 Phase 2
    // Stage 3) — check the freshly-updated state to see whether the write
    // actually completed before navigating away; a failure leaves
    // `turnError` set and `currentPhase` still `coWrite`, so the student
    // stays here and can retry by tapping "✓ Selesai" again.
    final succeeded =
        ref.read(learningFlowControllerProvider).currentPhase ==
        LearningSessionPhase.selesai;
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: used ? AppColors.primary : AppColors.surface,
        border: Border.all(
          color: used ? AppColors.primary : AppColors.lineStrong,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (used) ...[
            const Icon(Icons.check, size: 14, color: AppColors.marker),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              word,
              style: AppTextStyles.badgeLabel.copyWith(
                fontSize: 13,
                color: used ? Colors.white : AppColors.ink,
              ),
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
    final avatar = CircleAvatar(
      radius: 13,
      backgroundColor: isStudent ? AppColors.primary : AppColors.accentStrong,
      child: Icon(
        isStudent ? Icons.person : Icons.smart_toy,
        size: 15,
        color: Colors.white,
      ),
    );
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: isStudent ? AppColors.primaryTint : AppColors.surface,
          border: isStudent ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Text(turn.text, style: AppTextStyles.body),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: isStudent
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isStudent
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: isStudent
                ? [
                    const SizedBox(width: AppSpacing.xl),
                    bubble,
                    const SizedBox(width: AppSpacing.sm),
                    avatar,
                  ]
                : [
                    avatar,
                    const SizedBox(width: AppSpacing.sm),
                    bubble,
                    const SizedBox(width: AppSpacing.xl),
                  ],
          ),
          if (turn.feedback != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xl,
                right: 34,
                top: AppSpacing.xs,
              ),
              child: _FeedbackNote(
                feedback: turn.feedback!,
                kind: turn.feedbackKind,
              ),
            ),
        ],
      ),
    );
  }
}

/// Feedback under a student bubble (CW-02). Icon, color, and a semantic
/// label all follow the turn's [CowriteFeedbackKind], so the meaning never
/// relies on color alone. A missing kind (e.g. a transcript loaded without
/// one) falls back to the neutral style, never to "positive".
class _FeedbackNote extends StatelessWidget {
  const _FeedbackNote({required this.feedback, required this.kind});

  final String feedback;
  final CowriteFeedbackKind? kind;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      Color color,
      Color background,
      String label,
    ) = switch (kind) {
      CowriteFeedbackKind.positive => (
        Icons.check_circle,
        AppColors.success,
        AppColors.successBackground,
        'Sudah tepat',
      ),
      CowriteFeedbackKind.needsImprovement => (
        Icons.lightbulb,
        AppColors.warning,
        AppColors.warningBackground,
        'Perlu perbaikan',
      ),
      CowriteFeedbackKind.reminder || null => (
        Icons.chat_bubble_outline,
        AppColors.info,
        AppColors.infoBackground,
        'Pengingat',
      ),
    };

    return Container(
      key: ValueKey('cowrite-feedback-${kind?.name ?? 'neutral'}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: color, semanticLabel: label),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(feedback, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  const _ComposeBar({
    required this.textController,
    required this.focusNode,
    required this.suggestion,
    required this.isSending,
    required this.isRequestingSuggestion,
    required this.onRequestSuggestion,
    required this.onSend,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
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
        suggestion != null
            ? Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.smd,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.markerSoft,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Text('💡 $suggestion', style: AppTextStyles.body),
              )
            : const SizedBox.shrink(),
        TextFieldTapRegion(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  focusNode: focusNode,
                  enabled: !isSending,
                  autofillHints: null,
                  decoration: const InputDecoration(
                    hintText: 'Tulis kalimatmu...',
                  ),
                  minLines: 1,
                  maxLines: 3,
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                tooltip: 'Kirim',
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: isSending || isRequestingSuggestion ? null : onSend,
                icon: isSending
                    ? const AppButtonSpinner(size: 16)
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: isRequestingSuggestion || isSending
                ? null
                : onRequestSuggestion,
            icon: const Icon(Icons.lightbulb_outline, size: 16),
            label: const Text('Saran menulis'),
          ),
        ),
      ],
    );
  }
}

class _FinishedBanner extends StatelessWidget {
  const _FinishedBanner({required this.isCompleting, required this.onFinish});

  final bool isCompleting;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.smd),
          decoration: BoxDecoration(
            color: AppColors.successBackground,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: const Text(
            '🎉 Selamat! Semua kata target sudah digunakan!',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          onPressed: isCompleting ? null : onFinish,
          child: const Text('✓ Selesai'),
        ),
      ],
    );
  }
}
