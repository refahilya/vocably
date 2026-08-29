import 'package:flutter/material.dart';

import '../../../theme/theme.dart';

/// `researchAssessmentResults` scaffold (`SPEC.md` §3.7,
/// `DESIGN_REFERENCE.md` §5.5) — Pre-Test/Post-Test entry point body.
/// **Instrument fully TBD** (`CLAUDE.md` §10) — this shows only the
/// "Segera" placeholder text §5.5 describes, no question types, no
/// scoring. [assessmentType] only changes the title/copy shown, never
/// which collection/logic runs (there's none yet).
class ResearchAssessmentPlaceholderScreen extends StatelessWidget {
  const ResearchAssessmentPlaceholderScreen({super.key, required this.assessmentType});

  /// `"preTest"` or `"postTest"` (`DATA_MODEL.md` §6b's `type` values) —
  /// only used to pick display copy below.
  final String assessmentType;

  @override
  Widget build(BuildContext context) {
    final isPreTest = assessmentType == 'preTest';
    final title = isPreTest ? 'Pre-Test' : 'Post-Test';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 48, color: AppColors.disabled),
              const SizedBox(height: AppSpacing.md),
              Text(
                '$title akan segera hadir',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Instrumen penelitian ini masih disusun dan divalidasi oleh '
                'peneliti.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
