import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vocab_word.dart';
import 'firebase_service.dart';

/// Thin wrapper around guru writes to `vocabWords` (`DATA_MODEL.md` §2,
/// `SPEC.md` §4.1 "Tambah Kosakata") — the only Flutter-side writer of
/// this collection (the dev CSV-import pipeline writes separately, via
/// Admin SDK, in `tools/vocab_import/`). Read access (browse, kamus
/// detail) stays on the bundle/`VocabBundleService` side, per
/// `DATA_MODEL.md` §11 — this service is create/update only.
class VocabWordService {
  VocabWordService([FirebaseService? firebaseService])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;

  CollectionReference<Map<String, dynamic>> get _vocabWords =>
      _firebaseService.firestore.collection('vocabWords');

  /// Looks up an existing word by its already-`normalizeWord()`-ed form.
  /// Used for the "duplicate check on blur" step of Tambah Kosakata
  /// (`SPEC.md` §4.1) — `null` means the word doesn't exist yet, i.e. a
  /// brand-new word can be created.
  Future<VocabWord?> findByWord(String normalizedWord) async {
    final snapshot = await _vocabWords.doc(normalizedWord).get();
    final data = snapshot.data();
    if (data == null) return null;
    return VocabWord.fromFirestore(data);
  }

  /// Creates a brand-new `vocabWords` document for [word] (already
  /// `normalizeWord()`-ed) with the given [meanings]/[cefrLevel]/[topics],
  /// authored by [teacherId]. Rejected by `firestore.rules` if a document
  /// with this `docId` already exists (evaluated as an `update`, not a
  /// `create`) — callers should [findByWord] first and route to
  /// [appendMeaning] instead in that case, per `SPEC.md` §4.1's "kata ini
  /// sudah ada" flow.
  ///
  /// Builds the write map directly rather than reusing
  /// `VocabWord.toMap()` — that method emits a concrete `Timestamp` for
  /// `createdAt`/`updatedAt` (fine for the dev import pipeline's
  /// Admin-SDK writes, which bypass rules entirely), but
  /// `firestore.rules` requires `updatedAt == request.time`, which only
  /// an actual `FieldValue.serverTimestamp()` sentinel satisfies from a
  /// client write (the same pattern `AppUser.newStudentData()` already
  /// uses for `users.createdAt`).
  Future<void> createWord({
    required String word,
    required List<VocabMeaning> meanings,
    required String cefrLevel,
    required List<String> topics,
    required String teacherId,
  }) {
    return _vocabWords.doc(word).set({
      'word': word,
      'meanings': [for (final meaning in meanings) meaning.toMap()],
      'posList': [for (final meaning in meanings) meaning.pos],
      'cefrLevel': cefrLevel,
      'topics': topics,
      'source': 'guru',
      'addedByTeacherId': teacherId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Appends [newMeaning] to an existing word's `meanings` array
  /// (`SPEC.md` §4.1's "tambah makna baru ke kata ini" flow), recomputing
  /// `posList` and `updatedAt` in the same write. Runs as a Firestore
  /// transaction — not a plain read-then-write — so two teachers editing
  /// the same word around the same time can't silently clobber each
  /// other's appended meaning.
  Future<void> appendMeaning({
    required String normalizedWord,
    required VocabMeaning newMeaning,
  }) {
    final docRef = _vocabWords.doc(normalizedWord);
    return _firebaseService.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      if (data == null) {
        throw StateError(
          'appendMeaning called for "$normalizedWord", which does not exist. '
          'Callers must findByWord() first and use createWord() instead for '
          'a genuinely new word.',
        );
      }

      final existing = VocabWord.fromFirestore(data);
      final updatedMeanings = [...existing.meanings, newMeaning];

      transaction.update(docRef, {
        'meanings': [for (final meaning in updatedMeanings) meaning.toMap()],
        'posList': [for (final meaning in updatedMeanings) meaning.pos],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
