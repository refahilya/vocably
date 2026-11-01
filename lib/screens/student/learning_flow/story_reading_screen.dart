import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/learning_session.dart';
import '../../../providers/learning_session_controller.dart';
import '../../../providers/word_lookup_providers.dart';
import '../../../theme/theme.dart';
import '../../../utils/story_markers.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
import '../../../widgets/stepper_header.dart';
import '../vocab_browser/word_detail_screen.dart';
import 'cloze_test_screen.dart';

/// Fase 1 — Baca Cerita (`SPEC.md` §5.1, `DESIGN_REFERENCE.md` §3.4).
/// Reached from any of the three entry points, **after** the caller has
/// already called `LearningFlowController.startFlow` — this screen only
/// ever reads/drives the already-started flow, it never initializes one
/// itself.
///
/// The story is the point of the page: a white sheet at a comfortable line
/// length. The title field and generate button sit above it on phones and in
/// a side panel on wide windows, so a reader keeps the page to themselves.
class StoryReadingScreen extends ConsumerStatefulWidget {
  const StoryReadingScreen({super.key});

  @override
  ConsumerState<StoryReadingScreen> createState() => _StoryReadingScreenState();
}

class _StoryReadingScreenState extends ConsumerState<StoryReadingScreen> {
  final _titleController = TextEditingController();
  bool _showTranslation = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learningFlowControllerProvider);
    final controller = ref.read(learningFlowControllerProvider.notifier);
    // Milestone 7 Phase 2 Stage 7: true once the session has durably moved
    // past Fase 1 (`firestore.rules`' one-way phase lock only allows story
    // edits while `currentPhase == membaca`) — the only way to see this
    // screen in that state is pressing the system/AppBar Back button from
    // Cloze Test, since this flow has no other route back to Reading.
    // Generate/Generate Ulang must not attempt to write a now-locked story.
    final isStoryLocked = state.currentPhase != LearningSessionPhase.membaca;

    final composer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          enabled: !state.isGenerating,
          decoration: const InputDecoration(
            labelText: 'Judul / konteks cerita',
            hintText: 'mis. liburan',
            prefixIcon: Icon(Icons.edit_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: state.isGenerating || isStoryLocked
              ? null
              : () {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) return;
                  controller.generateStory(prompt: title);
                },
          child: state.isGenerating
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButtonSpinner(size: 16),
                    SizedBox(width: AppSpacing.sm),
                    Flexible(child: Text('Menghasilkan cerita...')),
                  ],
                )
              : Text(state.storyContent == null ? 'Generate' : 'Generate Ulang'),
        ),
        if (isStoryLocked) ...[
          const SizedBox(height: AppSpacing.sm),
          const AppNotice(
            text: 'Cerita sudah dikunci dan tidak dapat diubah lagi.',
            tone: AppTone.neutral,
          ),
        ],
        if (state.generateError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppNotice(
            text: state.generateError!,
            tone: AppTone.error,
            action: TextButton(
              onPressed: () {
                final title = _titleController.text.trim();
                if (title.isEmpty) return;
                controller.generateStory(prompt: title);
              },
              child: const Text('Coba lagi'),
            ),
          ),
        ],
      ],
    );

    final page = state.storyContent == null
        ? const AppSheet(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: AppStateMessage(
              icon: Icons.auto_stories_outlined,
              title: 'Cerita akan muncul di sini',
              body: 'Tulis judul atau konteks, lalu tekan Generate.',
            ),
          )
        : AppSheet(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(state.storyTitle ?? '', style: AppTextStyles.storyTitle),
                const SizedBox(height: AppSpacing.smd),
                _HighlightedStory(
                  markedText: state.storyContent!,
                  onTapWord: (targetWord) =>
                      _openDictionary(context, targetWord),
                ),
                if (state.storyTranslation != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () => setState(
                        () => _showTranslation = !_showTranslation,
                      ),
                      child: Text(
                        _showTranslation
                            ? 'Sembunyikan Terjemahan'
                            : 'Terjemahan',
                      ),
                    ),
                  ),
                  if (_showTranslation) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      stripTranslationMarkers(state.storyTranslation!),
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ],
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Baca Cerita')),
      body: Column(
        children: [
          const StepperHeader(activeIndex: 0),
          Expanded(
            child: AppScrollPage(
              maxWidth: AppContentWidth.reading + 344,
              child: AppTwoPane(
                primary: page,
                side: composer,
                sideFirst: true,
                breakpoint: AppBreakpoints.medium,
              ),
            ),
          ),
          if (state.advanceToClozeError != null)
            AppContent(
              maxWidth: AppContentWidth.reading,
              vertical: AppSpacing.sm,
              child: AppNotice(
                text: state.advanceToClozeError!,
                tone: AppTone.error,
              ),
            ),
          AppBottomBar(
            maxWidth: AppContentWidth.reading + 344,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width < AppBreakpoints.compact
                    ? double.infinity
                    : 240,
                child: FilledButton(
                  onPressed: state.storyContent == null
                      ? null
                      : () async {
                          await controller.advanceToClozeTest();
                          // `advanceToClozeTest` no longer throws on failure
                          // (Milestone 7 Phase 2 Stage 6) — check the
                          // freshly-updated state to see whether the write
                          // actually succeeded before navigating on; a
                          // failure leaves `advanceToClozeError` set and
                          // `currentPhase` still `membaca`, so the student
                          // stays here and can retry.
                          final succeeded =
                              ref
                                  .read(learningFlowControllerProvider)
                                  .advanceToClozeError ==
                              null;
                          if (succeeded && context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ClozeTestScreen(),
                              ),
                            );
                          }
                        },
                  child: const Text('Selanjutnya →'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDictionary(BuildContext context, String targetWord) async {
    final entry = await ref.read(
      resolveWordAcrossLevelsProvider(targetWord).future,
    );
    if (entry != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          // Milestone 7 Phase 2 Stage 7: this word is already one of the
          // active session's target words, not a cart candidate.
          builder: (_) => WordDetailScreen(entry: entry, hideCartAction: true),
        ),
      );
    }
  }
}

/// Renders a marked story with target words highlighted
/// (`DESIGN_REFERENCE.md` §3.4) — tapping a highlighted word opens the
/// dictionary for its base [MarkedStorySegment.targetWord], while the
/// text shown is always [MarkedStorySegment.surfaceForm] (`CLAUDE.md`
/// §4: highlight the used form, look up the base form).
class _HighlightedStory extends StatelessWidget {
  const _HighlightedStory({required this.markedText, required this.onTapWord});

  final String markedText;
  final void Function(String targetWord) onTapWord;

  @override
  Widget build(BuildContext context) {
    final segments = parseStoryMarkers(markedText);

    return Text.rich(
      TextSpan(
        style: AppTextStyles.story,
        children: [
          for (final segment in segments)
            switch (segment) {
              PlainStorySegment(:final text) => TextSpan(text: text),
              MarkedStorySegment(:final targetWord, :final surfaceForm) =>
                TextSpan(
                  text: surfaceForm,
                  style: AppTextStyles.storyHighlight,
                  mouseCursor: SystemMouseCursors.click,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => onTapWord(targetWord),
                ),
            },
        ],
      ),
    );
  }
}
