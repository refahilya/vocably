import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vocab_bundle_entry.dart';
import '../../../providers/learning_cart_providers.dart';
import '../../../providers/vocab_browser_providers.dart';
import '../../../providers/vocab_bundle_providers.dart';
import '../../../theme/theme.dart';
import '../../../utils/normalize_word.dart';
import '../../../utils/vocab_browse_filter.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
import '../../../widgets/cefr_level_selector.dart';
import 'learning_cart_screen.dart';
import 'word_detail_screen.dart';

/// Milestone 4 Stage 5 — student vocabulary browse/explore screen
/// (`SPEC.md` §3.3, `DESIGN_REFERENCE.md` §5.7). Reached from the level
/// ladder on the dashboard, which passes the tapped level as [initialLevel].
/// This screen owns its own `Scaffold`/`AppBar` since it's a pushed route,
/// not an `AppNavShell` destination body.
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
///
/// On phones the filters stack above the list; from
/// [AppBreakpoints.medium] they move to a side panel and the words flow into
/// columns, so a desktop isn't reading a phone-width list.
class VocabBrowserScreen extends ConsumerStatefulWidget {
  const VocabBrowserScreen({
    super.key,
    this.initialLevel = VocabBrowserFilterState.defaultLevel,
  });

  final String initialLevel;

  @override
  ConsumerState<VocabBrowserScreen> createState() => _VocabBrowserScreenState();
}

class _VocabBrowserScreenState extends ConsumerState<VocabBrowserScreen> {
  // Held here because a route can rebuild: this opening keeps one filter.
  late final _visit = VocabBrowserVisit(widget.initialLevel);

  @override
  Widget build(BuildContext context) {
    final filterProvider = vocabBrowserFilterProvider(_visit);
    final filter = ref.watch(filterProvider);
    final levelAsync = ref.watch(vocabLevelProvider(filter.cefrLevel));
    final width = MediaQuery.sizeOf(context).width;
    // Side panel on wide windows, and on phones held sideways, where stacked
    // filters would leave no height for the list.
    final useSidePanel =
        width >= AppBreakpoints.medium ||
        (width >= 480 && isShortWindow(context));

    final filters = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LevelSelector(
          filterProvider: filterProvider,
          selected: filter.cefrLevel,
        ),
        const SizedBox(height: AppSpacing.md),
        _ModeSelector(filterProvider: filterProvider, selected: filter.mode),
      ],
    );
    final results = levelAsync.when(
      loading: () => const AppLoading(),
      error: (error, stackTrace) => _ErrorState(
        onRetry: () => ref.invalidate(vocabLevelProvider(filter.cefrLevel)),
      ),
      data: (entries) => _LevelContent(
        filterProvider: filterProvider,
        allEntries: entries,
        filter: filter,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Jelajah Kosakata')),
      bottomNavigationBar: const _CartBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppContentWidth.page + 240,
          ),
          child: Padding(
            padding: EdgeInsets.all(appGutter(context)),
            child: useSidePanel
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: width >= AppBreakpoints.medium ? 280 : 232,
                        child: SingleChildScrollView(child: filters),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: results),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      filters,
                      const SizedBox(height: AppSpacing.md),
                      Expanded(child: results),
                    ],
                  ),
          ),
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

    return AppBottomBar(
      maxWidth: AppContentWidth.message,
      child: FilledButton.icon(
        icon: const Icon(Icons.shopping_basket_outlined),
        label: Text(
          count == 0
              ? 'Keranjang Pelajari kosong'
              : 'Lihat Keranjang Pelajari ($count kata)',
        ),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LearningCartScreen())),
      ),
    );
  }
}

class _LevelSelector extends ConsumerWidget {
  const _LevelSelector({required this.filterProvider, required this.selected});

  final VocabBrowserFilterProvider filterProvider;
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CefrLevelSelector(
      selected: selected,
      onSelected: ref.read(filterProvider.notifier).selectLevel,
    );
  }
}

class _ModeSelector extends ConsumerWidget {
  const _ModeSelector({required this.filterProvider, required this.selected});

  final VocabBrowserFilterProvider filterProvider;
  final VocabBrowseMode selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<VocabBrowseMode>(
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
        ref.read(filterProvider.notifier).selectMode(newSelection.first);
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
  const _LevelContent({
    required this.filterProvider,
    required this.allEntries,
    required this.filter,
  });

  final VocabBrowserFilterProvider filterProvider;
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
    final filterNotifier = ref.read(widget.filterProvider.notifier);

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
            onChanged: filterNotifier.selectTopic,
          ),
        if (filter.mode == VocabBrowseMode.pos)
          _ValueDropdown(
            label: 'Pilih POS',
            value: filter.selectedPos,
            options: _distinctPosValues(),
            onChanged: filterNotifier.selectPos,
          ),
        if (filter.mode != VocabBrowseMode.alphabetical)
          const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState(
                  message: 'Tidak ada kata yang cocok dengan filter ini.',
                  suggestion: 'Coba pilih topik atau POS lain.',
                )
              : AppResponsiveList(
                  itemCount: paged.items.length,
                  minItemWidth: 340,
                  gap: AppSpacing.sm,
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
                ? () => filterNotifier.goToPage(paged.pageIndex - 1)
                : null,
            onNext: paged.pageIndex < paged.totalPages - 1
                ? () => filterNotifier.goToPage(paged.pageIndex + 1)
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
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(option, overflow: TextOverflow.ellipsis),
          ),
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

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
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
                borderRadius: BorderRadius.circular(AppRadius.small),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WordDetailScreen(entry: entry),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.word, style: AppTextStyles.wordRow),
                      if (primary.translation != null)
                        Text(
                          primary.translation!,
                          style: AppTextStyles.bodyMuted,
                        ),
                      if (entry.posList.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final pos in entry.posList)
                              AppBadge(text: pos),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.smd),
              child: AppBadge.solid(text: entry.cefrLevel),
            ),
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
    return AppStateMessage(
      icon: Icons.menu_book,
      title: message,
      body: suggestion,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(message: 'Gagal memuat kosakata.', onRetry: onRetry);
  }
}
