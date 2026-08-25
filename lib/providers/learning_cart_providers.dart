import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/vocab_bundle_entry.dart';
import '../utils/normalize_word.dart';

part 'learning_cart_providers.g.dart';

/// "Keranjang Pelajari" (`SPEC.md` §3.4) — the student's in-progress
/// selection of words to learn next.
///
/// **Session-local, in-memory only — deliberately not persisted.**
/// `DATA_MODEL.md` has no Firestore collection for a cart at all; the
/// only documented destination for its contents is becoming a *new*
/// `learningSessions` document's `wordIds`
/// (`sourceType: "keranjangPelajari"`, §4) once the student presses the
/// CTA to start the 3-phase flow — Milestone 7 (Storyfier core),
/// explicitly out of scope for this stage. Inventing Firestore/local-
/// storage schema for a pre-session selection the docs don't describe
/// would be exactly the kind of unrequested architecture this stage was
/// told to avoid, so this stays plain Riverpod state.
///
/// Keyed by `normalizeWord(word)` (Stage 1's function) rather than the
/// raw word string, so duplicate prevention is normalization-sensitive
/// per this stage's instructions.
///
/// `keepAlive: true` — unlike `VocabBrowserFilter` (screen-local, fine to
/// reset when the browse screen is left), the cart needs to behave like
/// the shopping-cart metaphor `SPEC.md` §3.3/§3.4 explicitly uses: it
/// must survive navigating between levels/screens during a session, not
/// empty itself the moment the browse screen is popped.
@Riverpod(keepAlive: true)
class LearningCart extends _$LearningCart {
  @override
  Map<String, VocabBundleEntry> build() => {};

  bool contains(String word) => state.containsKey(normalizeWord(word));

  /// Adds [entry] if not already present (by normalized word). A no-op,
  /// not an error, if it's already in the cart — "prevent duplicates"
  /// means silently keeping the existing one, not rejecting the call.
  void add(VocabBundleEntry entry) {
    final key = normalizeWord(entry.word);
    if (state.containsKey(key)) return;
    state = {...state, key: entry};
  }

  /// Removes the word matching [word] (normalized). A no-op if it isn't
  /// in the cart.
  void remove(String word) {
    final key = normalizeWord(word);
    if (!state.containsKey(key)) return;
    state = {...state}..remove(key);
  }

  /// Adds [entry] if absent, removes it if present — what the browse
  /// screen's per-word toggle button calls.
  void toggle(VocabBundleEntry entry) {
    if (contains(entry.word)) {
      remove(entry.word);
    } else {
      add(entry);
    }
  }

  void clear() => state = {};
}
