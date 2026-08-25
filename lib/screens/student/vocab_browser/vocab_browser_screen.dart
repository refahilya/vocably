import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vocab_bundle_entry.dart';
import '../../../providers/learning_cart_providers.dart';
import '../../../providers/vocab_browser_providers.dart';
import '../../../providers/vocab_bundle_providers.dart';
import '../../../theme/theme.dart';
import '../../../utils/normalize_word.dart';
import '../../../utils/vocab_browse_filter.dart';
import 'learning_cart_screen.dart';
import 'word_detail_screen.dart';

const _cefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

/// Milestone 4 Stage 5 — student vocabulary browse/explore screen
/// (`SPEC.md` §3.3, `DESIGN_REFERENCE.md` §5.7). Reached today only via
/// the temporary entry point on [DashboardPlaceholder] — see the TODO
/// there. This screen owns its own `Scaffold`/`AppBar` since it's a
/// pushed route, not an `AppNavShell` destination body.
///
/// Deliberately simplified relative to `DESIGN_REFERENCE.md` §5.7's full
/// vision for this stage: no per-letter sticky headers in Abjad mode (a
/// flat sorted list instead), no simultaneous multi-group display in
/// Tema/POS mode (a single-select dropdown that narrows the list
/// instead, matching this stage's own explicit filtering-behavior spec),
/// no free-text search, and no mastery-status dot — mastery depends on
/// `learningProgress` (Milestone 7), which doesn't exist yet.
///
/// Milestone 4 Stage 6 adds the "keranjang pelajari" (+) affordance per
/// word and the sticky bottom bar → [LearningCartScreen] for viewing/
/// removing — see [LearningCart] for why that state is session-local
/// rather than persisted anywhere.
class VocabBrowserScreen extends ConsumerWidget {
  const VocabBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(vocabBrowserFilterProvider);
    final levelAsync = ref.watch(vocabLevelProvider(filter.cefrLevel));

    return Scaffold(
      appBar: AppBar(title: const Text('Jelajah Kosakata')),
      bottomNavigationBar: const _CartBar(),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LevelSelector(selected: filter.cefrLevel),
            const SizedBox(height: AppSpacing.md),
            _ModeSelector(selected: filter.mode),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: levelAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _ErrorState(
                  onRetry: () =>
                      ref.invalidate(vocabLevelProvider(filter.cefrLevel)),
                ),
                data: (entries) =>
                    _LevelContent(allEntries: entries, filter: filter),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky bar (`DESIGN_REFERENCE.md` §5.7: "Keranjang pelajari... tampil
/// sebagai bar sticky di bawah layar") that opens [LearningCartScreen] —
/// this stage's stand-in for "view the current 'Pelajari' collection".
/// Always tappable, even when empty (opens to the cart's own empty
/// state) — unlike the *actual* "Belajar Kata Ini dengan Cerita" CTA
/// (which §5.7 says should be disabled when empty), this bar's job is
/// only to open the view, not to start the — not yet built — 3-phase
/// flow, so there's no reason to block it on a non-empty cart.
class _CartBar extends ConsumerWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(learningCartProvider).length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FilledButton.icon(
          icon: const Icon(Icons.shopping_basket_outlined),
          label: Text(
            count == 0
                ? 'Keranjang Pelajari kosong'
                : 'Lihat Keranjang Pelajari ($count kata)',
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LearningCartScreen()),
          ),
        ),
      ),
    );
  }
}

class _LevelSelector extends ConsumerWidget {
  const _LevelSelector({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final level in _cefrLevels)
          ChoiceChip(
            label: Text(level),
            selected: level == selected,
            // DESIGN_REFERENCE.md §1: "Chip/pill aktif/dipilih — Navy
            // solid dengan teks putih" — applied explicitly since M3's
            // ChoiceChip default selected color is the secondary/teal
            // tonal container, not this app's documented chip-active rule.
            selectedColor: AppColors.primary,
            labelStyle: AppTextStyles.badgeLabel.copyWith(
              color: level == selected ? Colors.white : Colors.black87,
              fontWeight: level == selected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
            onSelected: (_) =>
                ref.read(vocabBrowserFilterProvider.notifier).selectLevel(level),
          ),
      ],
    );
  }
}

class _ModeSelector extends ConsumerWidget {
  const _ModeSelector({required this.selected});

  final VocabBrowseMode selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<VocabBrowseMode>(
      // Same navy-active rule as _LevelSelector, applied here too per
      // DESIGN_REFERENCE.md §5.7 ("style konsisten dengan stepper §3.1").
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
      ),
      segments: const [
        ButtonSegment(
          value: VocabBrowseMode.alphabetical,
          label: Text('Abjad'),
        ),
        ButtonSegment(value: VocabBrowseMode.topic, label: Text('Tema')),
        ButtonSegment(value: VocabBrowseMode.pos, label: Text('POS')),
      ],
      selected: {selected},
      onSelectionChanged: (newSelection) {
        ref
            .read(vocabBrowserFilterProvider.notifier)
            .selectMode(newSelection.first);
      },
    );
  }
}

class _LevelContent extends ConsumerWidget {
  const _LevelContent({required this.allEntries, required this.filter});

  final List<VocabBundleEntry> allEntries;
  final VocabBrowserFilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // DESIGN_REFERENCE.md §5.8: "Level C2 (atau level mana pun) tidak
    // punya kata" — a level with genuinely zero words, not a filter
    // producing zero results (handled separately below).
    if (allEntries.isEmpty) {
      return const _EmptyState(
        message: 'Belum ada kata di level ini.',
        suggestion: 'Coba pilih level CEFR lain.',
      );
    }

    final filtered = applyVocabBrowseFilter(
      allEntries,
      mode: filter.mode,
      selectedTopic: filter.selectedTopic,
      selectedPos: filter.selectedPos,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filter.mode == VocabBrowseMode.topic)
          _ValueDropdown(
            label: 'Pilih Topik',
            value: filter.selectedTopic,
            options: distinctTopics(allEntries),
            onChanged: (value) =>
                ref.read(vocabBrowserFilterProvider.notifier).selectTopic(value),
          ),
        if (filter.mode == VocabBrowseMode.pos)
          _ValueDropdown(
            label: 'Pilih POS',
            value: filter.selectedPos,
            options: distinctPosValues(allEntries),
            onChanged: (value) =>
                ref.read(vocabBrowserFilterProvider.notifier).selectPos(value),
          ),
        if (filter.mode != VocabBrowseMode.alphabetical)
          const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState(
                  message: 'Tidak ada kata yang cocok dengan filter ini.',
                  suggestion: 'Coba pilih topik atau POS lain.',
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _VocabWordTile(entry: filtered[index]),
                ),
        ),
      ],
    );
  }
}

class _ValueDropdown extends StatelessWidget {
  const _ValueDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // `value` can legitimately be a selection from a *previous* level's
    // options that no longer exists in `options` after switching levels —
    // DropdownButtonFormField requires its current value to be among its
    // items (or null), so guard against that rather than let it assert.
    final safeValue = options.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
    );
  }
}

class _VocabWordTile extends ConsumerWidget {
  const _VocabWordTile({required this.entry});

  final VocabBundleEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = entry.primaryMeaning;
    // Watching the whole cart map (not just calling .contains()) so this
    // tile rebuilds when cart membership changes for *this* word —
    // normalizeWord() is the same canonical key the cart itself uses.
    final inCart = ref
        .watch(learningCartProvider)
        .containsKey(normalizeWord(entry.word));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            // Tap-to-open Kamus Detail (`SPEC.md` §3.5) is scoped to just
            // this word-info area, deliberately kept as a sibling of the
            // trailing cart IconButton below rather than an ancestor
            // wrapping it — avoids relying on Flutter's nested-gesture-
            // arena tap disambiguation to keep "open detail" and "toggle
            // cart" from both firing on one tap.
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WordDetailScreen(entry: entry),
                ),
              ),
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
                  if (entry.posList.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final pos in entry.posList) _Badge(text: pos),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Badge(text: entry.cefrLevel, emphasized: true),
          const SizedBox(width: AppSpacing.xs),
          // DESIGN_REFERENCE.md §3.2/§4: direct tap on a (+) icon adds to
          // the cart (long-press, the old Android pattern, isn't used for
          // web); a small green check (§1's documented "chip aktif ...
          // centang hijau kecil") marks a word already selected. Tapping
          // again removes it — SPEC.md §3.4's "tambah kata / kurangi kata".
          IconButton(
            icon: Icon(
              inCart ? Icons.check_circle : Icons.add_circle_outline,
            ),
            color: inCart ? AppColors.success : AppColors.primary,
            tooltip: inCart
                ? 'Hapus dari Keranjang Pelajari'
                : 'Tambah ke Keranjang Pelajari',
            onPressed: () =>
                ref.read(learningCartProvider.notifier).toggle(entry),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.emphasized = false});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.primary : AppColors.disabledBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: AppTextStyles.badgeLabel.copyWith(
          color: emphasized ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.suggestion});

  final String message;
  final String suggestion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book, size: 48, color: AppColors.disabled),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              suggestion,
              style: AppTextStyles.body.copyWith(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Gagal memuat kosakata.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
