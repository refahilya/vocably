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

/// [ConsumerStatefulWidget] rather than the usual [ConsumerWidget] purely
/// so it can **memoize** filter/sort/distinct-extraction across page
/// changes (Milestone 4 finalization). [VocabBrowserFilterState.page]
/// changes far more often than `mode`/`selectedTopic`/`selectedPos` once
/// pagination exists — clicking "Next" 17 times on a 900-word A1 list
/// shouldn't re-run [applyVocabBrowseFilter]/[distinctTopics]/
/// [distinctPosValues] over all 900 entries 17 times for a result that's
/// identical every time. The cache below is keyed on exactly the inputs
/// that actually affect it (not `page`), invalidated with simple field
/// comparison — no new package, no app-wide state-management change.
class _LevelContent extends ConsumerStatefulWidget {
  const _LevelContent({required this.allEntries, required this.filter});

  final List<VocabBundleEntry> allEntries;
  final VocabBrowserFilterState filter;

  @override
  ConsumerState<_LevelContent> createState() => _LevelContentState();
}

class _LevelContentState extends ConsumerState<_LevelContent> {
  List<VocabBundleEntry>? _allEntriesCacheKey;
  VocabBrowseMode? _modeCacheKey;
  String? _topicCacheKey;
  String? _posCacheKey;
  List<VocabBundleEntry>? _cachedFiltered;
  List<String>? _cachedTopics;
  List<String>? _cachedPosValues;

  List<VocabBundleEntry> _filteredEntries() {
    final filter = widget.filter;
    final cacheValid =
        identical(_allEntriesCacheKey, widget.allEntries) &&
        _modeCacheKey == filter.mode &&
        _topicCacheKey == filter.selectedTopic &&
        _posCacheKey == filter.selectedPos;
    if (cacheValid) return _cachedFiltered!;

    final result = applyVocabBrowseFilter(
      widget.allEntries,
      mode: filter.mode,
      selectedTopic: filter.selectedTopic,
      selectedPos: filter.selectedPos,
    );
    _allEntriesCacheKey = widget.allEntries;
    _modeCacheKey = filter.mode;
    _topicCacheKey = filter.selectedTopic;
    _posCacheKey = filter.selectedPos;
    _cachedFiltered = result;
    return result;
  }

  List<VocabBundleEntry>? _allEntriesForTopicsCache;
  List<VocabBundleEntry>? _allEntriesForPosCache;

  List<String> _distinctTopics() {
    if (!identical(_allEntriesForTopicsCache, widget.allEntries)) {
      _cachedTopics = distinctTopics(widget.allEntries);
      _allEntriesForTopicsCache = widget.allEntries;
    }
    return _cachedTopics!;
  }

  List<String> _distinctPosValues() {
    if (!identical(_allEntriesForPosCache, widget.allEntries)) {
      _cachedPosValues = distinctPosValues(widget.allEntries);
      _allEntriesForPosCache = widget.allEntries;
    }
    return _cachedPosValues!;
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = widget.allEntries;
    final filter = widget.filter;

    // DESIGN_REFERENCE.md §5.8: "Level C2 (atau level mana pun) tidak
    // punya kata" — a level with genuinely zero words, not a filter
    // producing zero results (handled separately below).
    if (allEntries.isEmpty) {
      return const _EmptyState(
        message: 'Belum ada kata di level ini.',
        suggestion: 'Coba pilih level CEFR lain.',
      );
    }

    final filtered = _filteredEntries();
    final paged = paginate(filtered, page: filter.page);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filter.mode == VocabBrowseMode.topic)
          _ValueDropdown(
            label: 'Pilih Topik',
            value: filter.selectedTopic,
            options: _distinctTopics(),
            onChanged: (value) =>
                ref.read(vocabBrowserFilterProvider.notifier).selectTopic(value),
          ),
        if (filter.mode == VocabBrowseMode.pos)
          _ValueDropdown(
            label: 'Pilih POS',
            value: filter.selectedPos,
            options: _distinctPosValues(),
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
                  itemCount: paged.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _VocabWordTile(entry: paged.items[index]),
                ),
        ),
        // Pagination controls (Milestone 4 finalization) — hidden
        // entirely when everything already fits on one page, per the
        // "not unnecessarily prominent" requirement; showing a
        // permanently-disabled "Halaman 1 dari 1" control would just be
        // visual noise for the common case of a small filtered result.
        if (paged.totalPages > 1)
          _PaginationBar(
            pageIndex: paged.pageIndex,
            totalPages: paged.totalPages,
            onPrevious: paged.pageIndex > 0
                ? () => ref
                      .read(vocabBrowserFilterProvider.notifier)
                      .goToPage(paged.pageIndex - 1)
                : null,
            onNext: paged.pageIndex < paged.totalPages - 1
                ? () => ref
                      .read(vocabBrowserFilterProvider.notifier)
                      .goToPage(paged.pageIndex + 1)
                : null,
          ),
      ],
    );
  }
}

/// Previous/Next + "Halaman X dari Y" (Milestone 4 finalization —
/// pagination over the browse result, `kVocabBrowsePageSize` per page).
///
/// Milestone 4 finalization (UI fix): rebuilt with compact icon-only
/// Previous/Next buttons after manual testing at the canonical ~390px
/// mobile width showed a `RenderFlex` horizontal overflow here — the
/// original `OutlinedButton.icon` labels ("Sebelumnya"/"Selanjutnya")
/// plus default Material button padding, next to the page indicator
/// text, didn't fit on one row. Icon-only buttons have a small, fixed
/// intrinsic width, so this fits at any supported viewport width by
/// construction rather than by tuning pixels for one screenshot; the
/// page indicator is additionally wrapped in [Expanded] with
/// `overflow: TextOverflow.ellipsis` so it can never force an overflow
/// either. `Tooltip` keeps Previous/Next understandable (hover/long-press
/// text) and accessible (it also supplies the semantics label) despite
/// having no visible text label. See `PROJECT_STATE.md`.
class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.pageIndex,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageIndex;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          _PageNavButton(
            navKey: const Key('vocabBrowserPreviousPage'),
            icon: Icons.chevron_left,
            tooltip: 'Sebelumnya',
            onPressed: onPrevious,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Halaman ${pageIndex + 1} dari $totalPages',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _PageNavButton(
            navKey: const Key('vocabBrowserNextPage'),
            icon: Icons.chevron_right,
            tooltip: 'Selanjutnya',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// A small, fixed-size icon-only nav button used by [_PaginationBar].
/// Kept as its own widget so its compact, always-fits [ButtonStyle]
/// (no text label, tight padding/tap-target) lives in one place.
class _PageNavButton extends StatelessWidget {
  const _PageNavButton({
    required this.navKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Key navKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        key: navKey,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(40, 40),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Icon(icon, size: 20),
      ),
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
                  if (primary.translation != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(primary.translation!, style: AppTextStyles.body),
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
