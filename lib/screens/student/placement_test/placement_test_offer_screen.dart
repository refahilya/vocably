import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../providers/placement_test_providers.dart';
import '../../../theme/theme.dart';
import '../../../widgets/app_brand.dart';
import '../../../widgets/app_layout.dart';
import 'placement_test_screen.dart';

/// The one-time automatic placement-test offer (`SPEC.md` §3.1,
/// `DESIGN_REFERENCE.md` §5.2) — shown by `_RootRouter` in place of
/// [AppNavShell] exactly once, when a signed-in student's
/// `placementTestPrompted` is still `false`. Both choices below flip that
/// flag to `true` immediately, which is what lets `_RootRouter`'s own
/// rebuild (driven by the live `currentUserProfileProvider` stream) move
/// on to the dashboard on its own — this screen doesn't navigate there
/// itself, only ever forward into the test (for "Mulai Tes") or nowhere
/// (for "Nanti Saja", letting the router's rebuild do the rest).
///
/// "Mulai Tes" must push **before** the write. Firestore delivers the local
/// snapshot ahead of the write's future, so by the time an awaited write
/// returns this screen is already gone and the student is on the dashboard.
/// The pushed route sits above the router's home and survives that swap. The
/// test screen itself explains when it is unavailable.
class PlacementTestOfferScreen extends ConsumerWidget {
  const PlacementTestOfferScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptState = ref.watch(placementTestPromptControllerProvider);
    final isSubmitting = promptState.isLoading;

    void handleChoice({required bool startNow}) {
      if (startNow) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlacementTestScreen(uid: profile.uid)),
        );
      }
      ref
          .read(placementTestPromptControllerProvider.notifier)
          .markPrompted(profile.uid);
    }

    return Scaffold(
      appBar: AppBar(title: const AppWordmark()),
      body: Center(
        child: SingleChildScrollView(
          child: AppContent(
            maxWidth: AppContentWidth.message,
            vertical: AppSpacing.lg,
            child: AppSheet(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Tes Penempatan', style: AppTextStyles.pageTitle),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Ingin mengerjakan tes penempatan untuk menentukan level '
                    'CEFR awalmu? Tes ini opsional, dan kamu selalu bisa '
                    'mengambilnya nanti lewat menu Level.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: isSubmitting ? null : () => handleChoice(startNow: true),
                    child: const Text('Mulai Tes'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: isSubmitting ? null : () => handleChoice(startNow: false),
                    child: const Text('Nanti Saja'),
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
