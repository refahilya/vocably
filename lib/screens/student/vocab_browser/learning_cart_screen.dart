import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vocab_bundle_entry.dart';
import '../../../providers/learning_cart_providers.dart';
import '../../../theme/theme.dart';

/// "Keranjang Pelajari" view (`SPEC.md` §3.4) — lists the words currently
/// selected to learn next, with a remove (x) action per word.
///
/// The CTA to actually start the 3-phase flow ("Belajar Kata Ini dengan
/// Cerita", `DESIGN_REFERENCE.md` §5.7) is shown for visual completeness
/// but intentionally **disabled** (`onPressed: null`) — that flow is
/// Milestone 7 (Storyfier core), explicitly out of scope for Milestone 4.
/// Wiring it up is a later stage's job, not a redesign of this screen.
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
            // TODO(Milestone 7): wire this to the real 3-phase Storyfier
            // flow (SPEC.md §5, sourceType "keranjangPelajari") once it
            // exists — this cart's current words become that session's
            // wordIds. Left disabled on purpose for Milestone 4.
            onPressed: null,
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
                if (primary.translationId != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(primary.translationId!, style: AppTextStyles.body),
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
