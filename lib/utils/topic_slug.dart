/// Deterministic `docId` for the `topics` master-list collection
/// (`DATA_MODEL.md` §2b) — no normalization rule is documented for topic
/// names the way `normalizeWord()` is for `vocabWords`, so this picks a
/// simple slug so repeated writes of the same topic name are idempotent
/// (matching, not just similar to, the same rule already used by the
/// dev-side import pipeline).
///
/// **Must stay byte-for-byte identical to
/// `tools/vocab_import/lib/seedDecision.js`'s `topicSlug()`** — that
/// script seeded the initial `topics` collection from the Oxford CSVs'
/// `topics` column, and this function is what guru's "Tambah Kosakata"
/// (Milestone 5) uses when creating a new topic from the client. If the
/// two ever diverge, the same topic name typed by a teacher could
/// collide with — or fail to collide with — a docId the importer would
/// have chosen, defeating the "one canonical doc per topic name"
/// guarantee `DATA_MODEL.md` §2b relies on.
String topicSlug(String name) {
  final trimmedLower = name.trim().toLowerCase();
  final withUnderscores = trimmedLower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return withUnderscores.replaceAll(RegExp(r'^_+|_+$'), '');
}
