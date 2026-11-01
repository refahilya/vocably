import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Building blocks shared by the test screens (Pre-Test/Post-Test and the
/// Placement Test): a centred status message, a busy indicator, an error
/// banner, a button spinner and a single-choice option tile.

class AssessmentBusy extends StatelessWidget {
  const AssessmentBusy({super.key, required this.label});

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
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.md),
            footer!,
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class AssessmentErrorBanner extends StatelessWidget {
  const AssessmentErrorBanner({super.key, required this.text});

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

class AssessmentButtonSpinner extends StatelessWidget {
  const AssessmentButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
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
                  Expanded(child: Text(label, style: AppTextStyles.body)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
