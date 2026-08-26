'use strict';

/**
 * Canonical normalization rule — MUST stay byte-for-byte identical to
 * `lib/utils/normalize_word.dart`'s `normalizeWord()` in the Flutter app.
 * This is the same function reimplemented in JS for this Node-side
 * pipeline (Dart and Node can't share source directly), not a
 * reinterpretation — if the Dart rule ever changes, change this too.
 */
function normalizeWord(raw) {
  return raw.trim().toLowerCase();
}

module.exports = { normalizeWord };
