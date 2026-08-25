import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/vocab_bundle_entry.dart';
import '../services/vocab_bundle_service.dart';
import '../utils/vocab_bundle_constants.dart';

part 'vocab_bundle_providers.g.dart';

@riverpod
VocabBundleService vocabBundleService(Ref ref) => VocabBundleService();

/// Bundle for one CEFR level, merged with anything newer from Firestore
/// (`DATA_MODEL.md` §11.3). A family provider — one cached result per
/// `cefrLevel` string, matching how browse is always scoped to a single
/// level at a time (`SPEC.md` §3.2/§3.3).
///
/// `AsyncValue`'s own loading/error/data states satisfy "handle loading/
/// error/empty states cleanly" without extra plumbing here: a level with
/// no words yet (e.g. C2 today) resolves to `AsyncData(const [])` — an
/// empty list is valid data, not an error — while a genuine failure
/// (Firestore unreachable, etc.) surfaces as `AsyncError` for a later
/// stage's UI to render per `DESIGN_REFERENCE.md` §5.8's empty/error
/// states table.
@riverpod
Future<List<VocabBundleEntry>> vocabLevel(Ref ref, String cefrLevel) {
  return ref
      .watch(vocabBundleServiceProvider)
      .loadLevelWithDelta(
        cefrLevel: cefrLevel,
        bundleGeneratedAt: kBundleGeneratedAt,
      );
}
