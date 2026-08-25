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
