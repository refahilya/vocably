import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ai_worker_providers.dart';

part 'lazy_translation_providers.g.dart';

/// Lazy translation display for Word Detail (`DATA_MODEL.md` §2 point 4,
/// `DESIGN_REFERENCE.md` §5.8) — when a meaning's `translation` is
/// `null`, the student client calls `/translate` and shows the result
/// **on-screen only**; it is never written back to Firestore (that
/// distinction lives entirely on the calling side, not in
/// `AiWorkerService` itself — see its doc comment).
///
/// `@riverpod` (not `.family` manually) already caches per `(word, pos)`
/// argument pair for the lifetime of the provider container — i.e. for
/// the rest of the app session — which is exactly the "cache di memori
/// selama sesi aplikasi berjalan" behavior `DATA_MODEL.md` §2 asks for,
/// with no extra caching code needed.
@riverpod
Future<String> lazyTranslation(Ref ref, String word, String pos) {
  return ref.watch(aiWorkerServiceProvider).translate(word: word, pos: pos);
}
