import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/vocab_browse_filter.dart';

part 'vocab_browser_providers.g.dart';

/// UI selection state for the vocabulary browse screen: which CEFR level
/// is showing, which of the three browse modes is active, and — for
/// topic/POS mode — which value is currently selected. Purely local UI
/// state for one screen, following the same `@riverpod class` pattern
/// already used by `LoginController`/`SignUpController`, per `CLAUDE.md`
/// §4's "one Riverpod ecosystem" rule (no raw `setState` for this).
class VocabBrowserFilterState {
  const VocabBrowserFilterState({
    this.cefrLevel = 'A1',
    this.mode = VocabBrowseMode.alphabetical,
    this.selectedTopic,
    this.selectedPos,
    this.page = 0,
  });

  final String cefrLevel;
  final VocabBrowseMode mode;
  final String? selectedTopic;
  final String? selectedPos;

  /// 0-indexed current page (Milestone 4 finalization — pagination over
  /// the already-filtered/sorted result, see [paginate]). Every method
  /// below that changes level/mode/topic/pos resets this to `0`, since a
  /// page number chosen for one result set has no guaranteed meaning for
  /// a different one.
  final int page;

  VocabBrowserFilterState copyWith({
    String? cefrLevel,
    VocabBrowseMode? mode,
    // Explicit sentinel-vs-omitted handling: passing an explicit `null`
    // must be able to *clear* selectedTopic/selectedPos (e.g. switching
    // level or mode resets the selection), which a plain `?? current`
    // pattern can't distinguish from "not passed". `clearTopic`/`clearPos`
    // make that clearing explicit at call sites instead.
    String? selectedTopic,
    bool clearTopic = false,
    String? selectedPos,
    bool clearPos = false,
    int? page,
  }) {
    return VocabBrowserFilterState(
      cefrLevel: cefrLevel ?? this.cefrLevel,
      mode: mode ?? this.mode,
      selectedTopic: clearTopic ? null : (selectedTopic ?? this.selectedTopic),
      selectedPos: clearPos ? null : (selectedPos ?? this.selectedPos),
      page: page ?? this.page,
    );
  }
}

@riverpod
class VocabBrowserFilter extends _$VocabBrowserFilter {
  @override
  VocabBrowserFilterState build() => const VocabBrowserFilterState();

  /// Switching level resets any topic/POS selection — a value chosen for
  /// one level's data has no guaranteed meaning for another's — and, per
  /// the pagination requirement, resets back to page 0.
  void selectLevel(String cefrLevel) {
    state = state.copyWith(
      cefrLevel: cefrLevel,
      clearTopic: true,
      clearPos: true,
      page: 0,
    );
  }

  void selectMode(VocabBrowseMode mode) {
    state = state.copyWith(mode: mode, page: 0);
  }

  void selectTopic(String? topic) {
    state = state.copyWith(
      selectedTopic: topic,
      clearTopic: topic == null,
      page: 0,
    );
  }

  void selectPos(String? pos) {
    state = state.copyWith(selectedPos: pos, clearPos: pos == null, page: 0);
  }

  /// Jumps to [page] (0-indexed) directly — bounds-checking against the
  /// actual result set's page count is [paginate]'s job (called from the
  /// screen), not this notifier's; it just stores whatever was asked.
  void goToPage(int page) {
    state = state.copyWith(page: page);
  }
}
