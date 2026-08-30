import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/learning_session.dart';
import '../../../models/vocab_bundle_entry.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/learning_cart_providers.dart';
import '../../../providers/learning_session_controller.dart';
import '../../../theme/theme.dart';
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
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final entry = items[index];
                return _CartItemTile(
                  entry: entry,
                  onRemove: () =>
                      ref.read(learningCartProvider.notifier).remove(entry.word),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.word,
                  style: AppTextStyles.wordTitle.copyWith(fontSize: 18),
                ),
                if (primary.translation != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(primary.translation!, style: AppTextStyles.body),
                ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              size: 48,
              color: AppColors.disabled,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Keranjang Pelajari masih kosong.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pilih kata dari Jelajah Kosakata untuk mulai.',
              style: AppTextStyles.body.copyWith(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
