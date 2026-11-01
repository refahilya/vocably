import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_feedback.dart';

/// Building blocks shared by the test screens (Pre-Test/Post-Test and the
/// Placement Test): a centred status message, a busy indicator, an error
/// banner, a button spinner and a single-choice option tile.
///
/// Every option looks the same until chosen, including "Saya tidak tahu", so
/// the presentation never nudges a student toward an answer.

class AssessmentBusy extends StatelessWidget {
  const AssessmentBusy({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => AppLoading(label: label);
}

class AssessmentMessage extends StatelessWidget {
  const AssessmentMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional extra content under the body (e.g. the last result).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return AppStateMessage(
      icon: icon,
      title: title,
      body: body,
      footer: footer,
      action: actionLabel == null
          ? null
          : FilledButton(onPressed: onAction, child: Text(actionLabel!)),
    );
  }
}

class AssessmentErrorBanner extends StatelessWidget {
  const AssessmentErrorBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppNotice(text: text, tone: AppTone.error);
  }
}

class AssessmentButtonSpinner extends StatelessWidget {
  const AssessmentButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => const AppButtonSpinner();
}

/// One answer choice of a single-choice item (radio semantics).
class AssessmentOptionTile extends StatelessWidget {
  const AssessmentOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
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
          color: selected ? AppColors.primaryTint : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.lineStrong,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.smd,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? AppColors.primary : AppColors.inkMuted,
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(child: Text(label, style: AppTextStyles.body)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
