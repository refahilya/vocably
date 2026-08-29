import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../providers/placement_test_providers.dart';
import '../../../theme/theme.dart';
import 'placement_test_placeholder_screen.dart';

/// The one-time automatic placement-test offer (`SPEC.md` §3.1,
/// `DESIGN_REFERENCE.md` §5.2) — shown by `_RootRouter` in place of
/// [AppNavShell] exactly once, when a signed-in student's
/// `placementTestPrompted` is still `false`. Both choices below flip that
/// flag to `true` immediately, which is what lets `_RootRouter`'s own
/// rebuild (driven by the live `currentUserProfileProvider` stream) move
/// on to the dashboard on its own — this screen doesn't navigate there
/// itself, only ever forward into the test (for "Mulai Tes") or nowhere
/// (for "Nanti Saja", letting the router's rebuild do the rest).
class PlacementTestOfferScreen extends ConsumerWidget {
  const PlacementTestOfferScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptState = ref.watch(placementTestPromptControllerProvider);
    final isSubmitting = promptState.isLoading;

    Future<void> handleChoice({required bool startNow}) async {
      await ref
          .read(placementTestPromptControllerProvider.notifier)
          .markPrompted(profile.uid);
      if (startNow && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlacementTestPlaceholderScreen()),
        );
      }
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school, size: 56, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Tes Penempatan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Ingin mengerjakan tes penempatan untuk menentukan level '
                'CEFR awalmu? Tes ini opsional, dan kamu selalu bisa '
                'mengambilnya nanti lewat menu Level.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting ? null : () => handleChoice(startNow: true),
                  child: const Text('Mulai Tes'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: isSubmitting ? null : () => handleChoice(startNow: false),
                  child: const Text('Nanti Saja'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
