import '../models/vocab_bundle_entry.dart';
import 'normalize_word.dart';

/// The three browse modes `SPEC.md` §3.3 documents — abjad (alphabetical),
/// tema (topic), and POS.
enum VocabBrowseMode { alphabetical, topic, pos }

/// Pure, stateless filtering/sorting for the vocabulary browse screen.
/// Deliberately separate from any widget/provider — per `CLAUDE.md` §4's
/// screen/state/data-layer split, this is the "small provider/state
/// logic → filtering/sorting" piece, kept independently testable with no
/// Riverpod, Firestore, or Flutter UI dependency. None of these functions
/// mutate their input list.

/// Sorted by `normalizeWord(word)` — reuses the Stage 1 function rather
/// than comparing raw strings, so casing never affects order.
List<VocabBundleEntry> sortAlphabetically(List<VocabBundleEntry> entries) {
  final sorted = [...entries];
  sorted.sort(
    (a, b) => normalizeWord(a.word).compareTo(normalizeWord(b.word)),
  );
  return sorted;
}

/// Words whose `topics` contains [topic] exactly.
List<VocabBundleEntry> filterByTopic(
  List<VocabBundleEntry> entries,
  String topic,
) {
  return entries.where((entry) => entry.topics.contains(topic)).toList();
}

/// Words that have a meaning with this `pos` — reuses
/// [VocabBundleEntry.posList] rather than re-deriving it, since that's
/// already the documented derived-from-meanings source of truth
/// (`DATA_MODEL.md` §2).
List<VocabBundleEntry> filterByPos(
  List<VocabBundleEntry> entries,
  String pos,
) {
  return entries.where((entry) => entry.posList.contains(pos)).toList();
}

/// Every distinct topic actually present in [entries], sorted for a
/// deterministic dropdown order. **Never hardcoded** — always derived from
/// whatever is actually loaded for the current level.
List<String> distinctTopics(List<VocabBundleEntry> entries) {
  final topics = <String>{};
  for (final entry in entries) {
    topics.addAll(entry.topics);
  }
  return topics.toList()..sort();
}

/// Every distinct POS value actually present in [entries], sorted for a
/// deterministic dropdown order. **Never hardcoded.**
List<String> distinctPosValues(List<VocabBundleEntry> entries) {
  final posValues = <String>{};
  for (final entry in entries) {
    posValues.addAll(entry.posList);
  }
  return posValues.toList()..sort();
}

/// Applies the currently-selected browse mode to [entries] and returns the
/// result, always alphabetically sorted at the end regardless of mode —
/// this is what the browse screen actually calls. A `null` selection for
/// [selectedTopic]/[selectedPos] (nothing chosen yet) leaves the list
/// unnarrowed for that mode, rather than showing nothing.
List<VocabBundleEntry> applyVocabBrowseFilter(
  List<VocabBundleEntry> entries, {
  required VocabBrowseMode mode,
  String? selectedTopic,
  String? selectedPos,
}) {
  var result = entries;
  switch (mode) {
    case VocabBrowseMode.alphabetical:
      break;
    case VocabBrowseMode.topic:
      if (selectedTopic != null) {
        result = filterByTopic(result, selectedTopic);
      }
    case VocabBrowseMode.pos:
      if (selectedPos != null) {
        result = filterByPos(result, selectedPos);
      }
  }
  return sortAlphabetically(result);
}

/// Page size for browse-result pagination (Milestone 4 finalization —
/// the real Oxford bundle puts ~900 words in a single A1 list, which
/// noticeably lagged rendered all at once).
const int kVocabBrowsePageSize = 50;

/// One page's worth of an **already-filtered-and-sorted** list, plus
/// enough bookkeeping (`pageIndex`, `totalPages`) that the UI never has
/// to re-derive page-count math itself. Pure and generic — no
/// `VocabBundleEntry` dependency — so it composes with
/// [applyVocabBrowseFilter]'s output without knowing anything about it:
/// callers always filter/sort first, then paginate
/// (`paginate(applyVocabBrowseFilter(...), page: ...)`), never the other
/// way around — pagination must never narrow the set a filter still
/// needs to run over.
class VocabBrowsePage<T> {
  const VocabBrowsePage({
    required this.items,
    required this.pageIndex,
    required this.totalPages,
  });

  /// This page's slice — at most [kVocabBrowsePageSize] items.
  final List<T> items;

  /// 0-indexed, already clamped into `[0, totalPages - 1]` (or `0` when
  /// [totalPages] is `0`) — never out of range even if the requested
  /// page came from a stale/larger result set (e.g. a filter just
  /// narrowed the list out from under a page the user was already on).
  final int pageIndex;

  /// `0` only when [items]' source list was empty; otherwise always
  /// `>= 1`, including when everything fits on a single page.
  final int totalPages;
}

/// Slices an already-filtered/sorted [items] list into one page.
/// [page] is the *requested* 0-indexed page — not assumed valid; this
/// clamps it itself, so a caller never needs its own bounds-checking
/// before calling this (`SPEC` requirement: level/mode/filter changes
/// reset to page 0 themselves, but this stays safe even if a stale page
/// number is passed for any other reason).
VocabBrowsePage<T> paginate<T>(
  List<T> items, {
  required int page,
  int pageSize = kVocabBrowsePageSize,
}) {
  if (items.isEmpty) {
    return const VocabBrowsePage(items: [], pageIndex: 0, totalPages: 0);
  }
  final totalPages = (items.length / pageSize).ceil();
  final pageIndex = page.clamp(0, totalPages - 1);
  final start = pageIndex * pageSize;
  final end = (start + pageSize < items.length) ? start + pageSize : items.length;
  return VocabBrowsePage(
    items: items.sublist(start, end),
    pageIndex: pageIndex,
    totalPages: totalPages,
  );
}
