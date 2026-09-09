import 'package:flutter/material.dart';

import '../../../models/learning_session.dart';
import '../../../theme/theme.dart';
import '../../../utils/session_date_format.dart';
import '../../../utils/story_markers.dart';

/// Read-only story replay for one `learningSessions` document
/// (`SPEC.md` §3.6: "Membuka satu sesi menampilkan cerita yang dipakai...
/// cerita tersimpan lengkap, jadi bisa dibaca ulang tanpa memanggil AI
/// lagi"). Parses `storyContent`'s stored `[[kata|bentuk]]` markers via
/// `utils/story_markers.dart` — the same shared parser Milestone 7 will
/// use for the live Fase 1 view — to highlight target words exactly like
/// the original reading phase did, with no AI call.
///
/// Deliberately **not** tap-to-dictionary here (unlike the live Fase 1
/// view) — this is a static historical replay, and wiring dictionary
/// lookups into it isn't something `SPEC.md` §3.6 asks for; highlighting
/// alone already satisfies "dengan highlight kata target".
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.session});

  final LearningSession session;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _showTranslation = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final segments = parseStoryMarkers(session.storyContent);
    final translation = session.storyTranslation;

    return Scaffold(
      appBar: AppBar(title: Text(session.storyTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              formatSessionTimestamp(session.startedAt),
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            RichText(
              text: TextSpan(
                style: AppTextStyles.body,
                children: [
                  for (final segment in segments)
                    switch (segment) {
                      PlainStorySegment(:final text) => TextSpan(text: text),
                      MarkedStorySegment(:final surfaceForm) => TextSpan(
                        text: surfaceForm,
                        style: const TextStyle(
                          backgroundColor: AppColors.storyHighlightBackground,
                          color: AppColors.storyHighlightText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    },
                ],
              ),
            ),
            if (translation != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () =>
                    setState(() => _showTranslation = !_showTranslation),
                child: Text(
                  _showTranslation ? 'Sembunyikan Terjemahan' : 'Terjemahan',
                ),
              ),
              if (_showTranslation) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  stripTranslationMarkers(translation),
                  style: AppTextStyles.body,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
