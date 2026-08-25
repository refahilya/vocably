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
  });

  final String cefrLevel;
  final VocabBrowseMode mode;
  final String? selectedTopic;
  final String? selectedPos;

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
  }) {
    return VocabBrowserFilterState(
      cefrLevel: cefrLevel ?? this.cefrLevel,
      mode: mode ?? this.mode,
      selectedTopic: clearTopic ? null : (selectedTopic ?? this.selectedTopic),
      selectedPos: clearPos ? null : (selectedPos ?? this.selectedPos),
    );
  }
}

@riverpod
class VocabBrowserFilter extends _$VocabBrowserFilter {
  @override
  VocabBrowserFilterState build() => const VocabBrowserFilterState();

  /// Switching level resets any topic/POS selection — a value chosen for
  /// one level's data has no guaranteed meaning for another's.
  void selectLevel(String cefrLevel) {
    state = state.copyWith(
      cefrLevel: cefrLevel,
      clearTopic: true,
      clearPos: true,
    );
  }

  void selectMode(VocabBrowseMode mode) {
    state = state.copyWith(mode: mode);
  }

  void selectTopic(String? topic) {
    state = state.copyWith(selectedTopic: topic, clearTopic: topic == null);
  }

  void selectPos(String? pos) {
    state = state.copyWith(selectedPos: pos, clearPos: pos == null);
  }
}
