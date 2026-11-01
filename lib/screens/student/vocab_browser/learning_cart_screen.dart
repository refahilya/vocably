import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/learning_session.dart';
import '../../../models/vocab_bundle_entry.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/learning_cart_providers.dart';
import '../../../providers/learning_session_controller.dart';
import '../../../theme/theme.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
import '../learning_flow/story_reading_screen.dart';

/// "Keranjang Pelajari" view (`SPEC.md` §3.4) — lists the words currently
/// selected to learn next, with a remove (x) action per word.
///
/// The CTA starts the 3-phase flow (`sourceType: keranjangPelajari`,
/// `DATA_MODEL.md` §4) — Milestone 7. The cart itself is **not** cleared
/// here; per the project owner's Milestone 7 Decision 4, it's cleared
/// only once the flow's first story generation actually succeeds
/// (`LearningFlowController.generateStory`), so a failed first generate
/// leaves the cart intact for the student to just retry.
class LearningCartScreen extends ConsumerWidget {
  const LearningCartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(learningCartProvider).values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang Pelajari')),
      body: items.isEmpty
          ? const _EmptyCart()
          : AppContent(
              maxWidth: AppContentWidth.list,
              child: AppResponsiveList(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                itemCount: items.length,
                minItemWidth: 340,
                maxColumns: 2,
                gap: AppSpacing.sm,
                itemBuilder: (context, index) {
                  final entry = items[index];
                  return _CartItemTile(
                    entry: entry,
                    onRemove: () =>
                        ref.read(learningCartProvider.notifier).remove(entry.word),
                  );
                },
              ),
            ),
      bottomNavigationBar: AppBottomBar(
        maxWidth: AppContentWidth.message,
        child: FilledButton(
          onPressed: items.isEmpty
              ? null
              : () {
                  ref
                      .read(learningFlowControllerProvider.notifier)
                      .startFlow(
                        // `currentUserProfileProvider` is already
                        // resolved and non-null here — this screen is
                        // only ever reachable while `AppAuthSignedIn`
                        // (`app.dart`), which requires exactly that.
                        studentId: ref.read(currentUserProfileProvider).value!.uid,
                        wordIds: [for (final entry in items) entry.word],
                        sourceType: LearningSessionSourceType.keranjangPelajari,
                      );
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StoryReadingScreen()),
                  );
                },
          child: Text(
            items.isEmpty
                ? 'Belajar Kata Ini dengan Cerita'
                : 'Belajar Kata Ini dengan Cerita (${items.length} kata)',
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.entry, required this.onRemove});

  final VocabBundleEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final primary = entry.primaryMeaning;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.word, style: AppTextStyles.wordRow),
                if (primary.translation != null)
                  Text(primary.translation!, style: AppTextStyles.bodyMuted),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.error),
            tooltip: 'Hapus dari keranjang',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const AppStateMessage(
      icon: Icons.shopping_basket_outlined,
      title: 'Keranjang Pelajari masih kosong.',
      body: 'Pilih kata dari Jelajah Kosakata untuk mulai.',
    );
  }
}
