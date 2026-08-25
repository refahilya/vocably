/// Canonical normalization for every place a `vocabWords` docId needs to
/// be computed — CSV import (dev-side), the bundle generator (dev-side),
/// guru's "Tambah Kosakata" (Milestone 5), and any lookup that needs to
/// match a word string to its `wordId`. Using this exact function
/// everywhere is what keeps `docId = normalizeWord(word)` consistent
/// across all of them (`DATA_MODEL.md` §2, `CLAUDE.md` §8 "Bank kosakata").
///
/// `normalizeWord(raw) = raw.trim().toLowerCase()` — nothing more. Internal
/// whitespace in multi-word phrases (e.g. `"wake up"`) is preserved
/// exactly as-is; only leading/trailing whitespace is removed. Documented
/// as intentionally this minimal — no punctuation stripping, no Unicode
/// normalization, no internal-whitespace collapsing.
String normalizeWord(String raw) => raw.trim().toLowerCase();
