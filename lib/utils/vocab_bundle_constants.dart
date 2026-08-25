/// Timestamp of the last static bundle generation (`DATA_MODEL.md` §11.3).
/// Every `vocabWords` document whose `updatedAt` is newer than this is
/// picked up by the Firestore delta query rather than trusted from the
/// bundle file alone — this is the constant that query filters on.
///
/// **Placeholder value.** CSV import and bundle generation are developer-
/// side tasks (`CLAUDE.md` §7 Milestone 4) that haven't been run yet — no
/// real `assets/vocab/*.json` file exists in this repo. Set to the Unix
/// epoch so that, until a real bundle exists, every `vocabWords` document
/// is correctly treated as "newer than the bundle" and always picked up
/// by the delta query — i.e. the app behaves as if the static bundle were
/// empty and everything comes live from Firestore, which is the correct
/// behavior for a bundle that doesn't exist yet.
///
/// **Update this to the actual generation timestamp** once the dev-side
/// bundle-generation script has produced a real bundle — this is the one
/// line that needs to change; nothing else in the bundle-loading code
/// depends on how this value is produced.
final DateTime kBundleGeneratedAt = DateTime.fromMillisecondsSinceEpoch(0);
